;;; emacs-openclaw.el --- OpenClaw chat integration for Emacs -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (request "0.3.0") (websocket "1.13"))
;; Keywords: tools, openclaw, chat, ai
;; URL: https://github.com/andyLaurito92/emacs-openclaw

;;; Commentary:

;; emacs-openclaw provides an interactive chat interface for OpenClaw
;; directly within Emacs. It uses WebSocket protocol for real-time
;; streaming chat responses. Configuration is automatically detected from
;; ~/.openclaw/openclaw.json (gateway token and port).

;;; Code:

(require 'request)
(require 'json)
(require 'cl-lib)
(require 'websocket)

;; ============================================================================
;; Customization Variables
;; ============================================================================

(defgroup emacs-openclaw nil
  "OpenClaw chat integration for Emacs."
  :group 'tools
  :prefix "emacs-openclaw-")

(defcustom emacs-openclaw-data-dir (locate-user-emacs-file "emacs-openclaw/")
  "Directory for storing emacs-openclaw persistent data and secrets."
  :type 'directory
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-client-secret-path (expand-file-name "client_secret.json" emacs-openclaw-data-dir)
  "Path to the Google API client_secret.json file."
  :type 'file
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-buffer-name "*OpenClaw-Chat*"
  "Name of the OpenClaw chat buffer."
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-token nil
  "OpenClaw authentication token.
If nil, will attempt to load from ~/.openclaw/openclaw.json."
  :type '(choice (const :tag "Auto-detect from ~/.openclaw/openclaw.json" nil)
                 (string :tag "Explicit token"))
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-port nil
  "OpenClaw gateway port.
If nil, will attempt to load from ~/.openclaw/openclaw.json."
  :type '(choice (const :tag "Auto-detect from ~/.openclaw/openclaw.json" nil)
                 (integer :tag "Explicit port"))
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-session-key "emacs-session"
  "Session key for OpenClaw requests."
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-server-port 3333
  "Port for the OpenClaw Gmail/Calendar tools server."
  :type 'integer
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-auto-start-server t
  "Whether to automatically start the Gmail/Calendar tools server if not running."
  :type 'boolean
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-message-separator "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  "Visual separator between messages in the chat buffer."
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-welcome-message "Welcome to OpenClaw Chat!"
  "Welcome message displayed when opening the chat buffer for the first time."
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-instructions "Type your message below and press RET to send."
  "Instructions displayed in the chat buffer when first opened."
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-websocket-timeout 10
  "Timeout in seconds for establishing WebSocket connection to OpenClaw gateway."
  :type 'integer
  :group 'emacs-openclaw)

;; ============================================================================
;; Internal Variables
;; ============================================================================

(defvar emacs-openclaw--mode-map nil)
(defvar emacs-openclaw--token-cache nil)
(defvar emacs-openclaw--port-cache nil)
(defvar emacs-openclaw--server-process nil)
(defvar emacs-openclaw--server-buffer "*OpenClaw-Server*")
(defvar emacs-openclaw--websocket nil
  "The websocket connection to OpenClaw gateway.")
(defvar emacs-openclaw--websocket-connected nil
  "Whether the websocket is currently connected.")
(defvar emacs-openclaw--request-id-counter 0
  "Counter for generating unique request IDs.")
(defvar emacs-openclaw--pending-requests (make-hash-table :test 'equal)
  "Hash table mapping request IDs to response handlers.")
(defvar emacs-openclaw--current-message-buffer ""
  "Buffer for accumulating streaming message content.")

;; ============================================================================
;; Configuration Loading
;; ============================================================================

(defun emacs-openclaw--config-file ()
  "Get the path to the OpenClaw tools config file in the data directory."
  (expand-file-name "tools-config.json" emacs-openclaw-data-dir))

(defun emacs-openclaw--save-tools-config (tools-info)
  "Save TOOLS-INFO to persistent config file."
  (unless (file-directory-p emacs-openclaw-data-dir)
    (make-directory emacs-openclaw-data-dir t))
  (let ((config-file (emacs-openclaw--config-file)))
    (with-temp-file config-file
      (insert (json-encode tools-info)))
    (message "Saved tools configuration to %s" config-file)))

(defun emacs-openclaw--load-tools-config ()
  "Load tools configuration from persistent storage."
  (let ((config-file (emacs-openclaw--config-file)))
    (when (file-exists-p config-file)
      (condition-case err
          (let ((json-object-type 'plist)
                (json-array-type 'list))
            (json-read-file config-file))
        (error
         (message "emacs-openclaw: Failed to load tools config: %s" err)
         nil)))))

(defun emacs-openclaw--load-config ()
  "Load OpenClaw configuration from ~/.openclaw/openclaw.json."
  (let ((config-file (expand-file-name "~/.openclaw/openclaw.json")))
    (when (file-exists-p config-file)
      (condition-case err
          (let* ((json-object-type 'plist)
                 (json-array-type 'list)
                 (config (json-read-file config-file))
                 (gateway (plist-get config :gateway))
                 (auth (plist-get gateway :auth))
                 (token (plist-get auth :token))
                 (port (plist-get gateway :port)))
            (when (and token port)
              (list :token token :port port)))
        (error 
         (message "emacs-openclaw: Failed to load config from %s: %s" config-file err)
         nil)))))

;; ============================================================================
;; Custom Faces
;; ============================================================================

(defface emacs-openclaw-user-face
  '((t :foreground "green" :weight bold))
  "Face for user input in OpenClaw chat."
  :group 'emacs-openclaw)

(defface emacs-openclaw-response-face
  '((t :foreground "cyan" :weight normal))
  "Face for OpenClaw responses in chat."
  :group 'emacs-openclaw)

;; ============================================================================
;; Configuration Helpers
;; ============================================================================

(defun emacs-openclaw--ensure-config ()
  "Ensure token and port are available."
  (unless emacs-openclaw--token-cache
    (let ((config (emacs-openclaw--load-config)))
      (if config
          (progn
            (setq emacs-openclaw--token-cache (plist-get config :token)
                  emacs-openclaw--port-cache (plist-get config :port))
            (message "emacs-openclaw: Loaded config from ~/.openclaw/openclaw.json"))
        (setq emacs-openclaw--token-cache :not-found))))
  
  (let ((token (or emacs-openclaw-token 
                   (when (and emacs-openclaw--token-cache 
                              (not (eq emacs-openclaw--token-cache :not-found)))
                     emacs-openclaw--token-cache)))
        (port (or emacs-openclaw-port 
                  (when (and emacs-openclaw--port-cache 
                             (not (eq emacs-openclaw--port-cache :not-found)))
                    emacs-openclaw--port-cache)
                  18789)))
    
    (unless token
      (error "OpenClaw token not found. Please set emacs-openclaw-token"))
    
    (list :token token :port port)))

(defun emacs-openclaw--get-base-url ()
  (let ((config (emacs-openclaw--ensure-config)))
    (format "http://127.0.0.1:%d" (plist-get config :port))))

(defun emacs-openclaw--get-token ()
  (plist-get (emacs-openclaw--ensure-config) :token))

;; ============================================================================
;; WebSocket Connection Management
;; ============================================================================

(defun emacs-openclaw--generate-request-id ()
  "Generate a unique request ID."
  (setq emacs-openclaw--request-id-counter (1+ emacs-openclaw--request-id-counter))
  (format "emacs-req-%d" emacs-openclaw--request-id-counter))

(defun emacs-openclaw--websocket-on-open (ws)
  "Handle websocket connection open event."
  (message "emacs-openclaw: WebSocket connection opened, sending handshake...")
  (let* ((config (emacs-openclaw--ensure-config))
         (token (plist-get config :token))
         (connect-msg (json-encode
                       `((type . "req")
                         (id . ,(emacs-openclaw--generate-request-id))
                         (method . "connect")
                         (params . ((minProtocol . 3)
                                   (maxProtocol . 3)
                                   (client . ((id . "cli")
                                             (displayName . "Emacs OpenClaw")
                                             (version . "0.1.0")
                                             (platform . "emacs")
                                             (mode . "cli")))
                                   (role . "operator")
                                   (scopes . ["operator.read" "operator.write"])
                                   (caps . [])
                                   (commands . [])
                                   (permissions . [])
                                   (auth . ((token . ,token)))
                                   (locale . "en-US")
                                   (userAgent . "emacs-openclaw/0.1.0")))))))
    (websocket-send-text ws connect-msg)))

(defun emacs-openclaw--websocket-on-message (ws frame)
  "Handle incoming websocket messages."
  (ignore-errors
    ;; Wrap everything in ignore-errors to prevent ANY error from propagating
    ;; and crashing the websocket connection
    
    (let ((msg-text (websocket-frame-text frame)))
      ;; Check if we even have text
      (when msg-text
        ;; Check if it's empty or whitespace
        (unless (string-empty-p (string-trim msg-text))
          ;; Log the frame we're processing
          (let ((preview (substring msg-text 0 (min 80 (length msg-text)))))
            (message "emacs-openclaw: Processing frame (%d bytes): %s..." (length msg-text) preview))
          
          ;; Try to parse JSON
          (let ((msg nil)
                (parse-err nil))
            (condition-case err
                (let ((json-object-type 'alist)
                      (json-array-type 'list))
                  (setq msg (json-read-from-string msg-text)))
              (error
               (setq parse-err err)))
            
            (if parse-err
                ;; Failed to parse JSON
                (message "emacs-openclaw: Failed to parse JSON: %s. Text: %s" 
                         parse-err
                         (substring msg-text 0 (min 100 (length msg-text))))
              
              ;; Successfully parsed JSON - now process it
              (let ((msg-type (alist-get 'type msg))
                    (msg-id (alist-get 'id msg)))
                
                (message "emacs-openclaw: Parsed message type=%s id=%s" msg-type msg-id)
                
                (cond
                 ;; Response to our connect request
                 ((and (string= msg-type "res") msg-id)
                  (message "emacs-openclaw: Got response to request %s" msg-id)
                  (let ((ok (alist-get 'ok msg)))
                    (if ok
                        (progn
                          (setq emacs-openclaw--websocket-connected t)
                          (message "emacs-openclaw: WebSocket connected and authenticated"))
                      (let ((error-msg (alist-get 'error msg)))
                        (message "emacs-openclaw: Connection error: %s" error-msg))))
                  ;; Call any pending handler for this request ID
                  (let ((handler (gethash msg-id emacs-openclaw--pending-requests)))
                    (when handler
                      (message "emacs-openclaw: Calling handler for %s" msg-id)
                      (funcall handler msg)
                      (remhash msg-id emacs-openclaw--pending-requests))))
                 
                 ;; Streaming event (chat.delta)
                 ((string= msg-type "event")
                  (let ((event-type (alist-get 'event msg)))
                    (message "emacs-openclaw: Got event: %s" event-type)
                    (when (string= event-type "chat.delta")
                      (emacs-openclaw--handle-chat-delta msg))))
                 
                 ;; Other message types
                 (t
                  (message "emacs-openclaw: Unknown message type: %s" msg-type))))))
        
        ;; If msg-text is nil or empty, just silently skip
        )))))

(defun emacs-openclaw--handle-chat-delta (msg)
  "Handle a chat.delta streaming event."
  (let* ((payload (alist-get 'payload msg))
         (delta (alist-get 'delta payload)))
    (when delta
      ;; Handle different delta structures
      (let* ((choices (alist-get 'choices delta))
             (choice (when choices (car choices)))
             (choice-delta (when choice (alist-get 'delta choice)))
             (content (when choice-delta (alist-get 'content choice-delta))))
        (when content
          (setq emacs-openclaw--current-message-buffer 
                (concat emacs-openclaw--current-message-buffer content))
          (emacs-openclaw--log content nil))))))

(defun emacs-openclaw--websocket-on-close (ws)
  "Handle websocket connection close event."
  (setq emacs-openclaw--websocket-connected nil)
  (setq emacs-openclaw--websocket nil)
  (message "emacs-openclaw: WebSocket connection closed"))

(defun emacs-openclaw--websocket-on-error (ws type err)
  "Handle websocket errors."
  (message "emacs-openclaw: WebSocket error: %s - %s" type err))

(defun emacs-openclaw--ensure-websocket ()
  "Ensure websocket connection is established."
  (unless (and emacs-openclaw--websocket emacs-openclaw--websocket-connected)
    (emacs-openclaw--connect-websocket)
    ;; Wait for connection to complete (with timeout)
    (let ((retries (floor (/ emacs-openclaw-websocket-timeout 0.2))))  ; Convert timeout to retry count
      (while (and (> retries 0) 
                  (not emacs-openclaw--websocket-connected))
        (accept-process-output nil 0.2)
        (setq retries (1- retries)))
      (unless emacs-openclaw--websocket-connected
        (error "Failed to establish websocket connection to OpenClaw gateway")))))

(defun emacs-openclaw--connect-websocket ()
  "Connect to OpenClaw gateway via websocket."
  (when (and emacs-openclaw--websocket 
             (websocket-openp emacs-openclaw--websocket))
    (websocket-close emacs-openclaw--websocket))
  
  (let* ((config (emacs-openclaw--ensure-config))
         (port (plist-get config :port))
         (url (format "ws://127.0.0.1:%d" port)))
    
    (message "emacs-openclaw: Connecting to %s..." url)
    (setq emacs-openclaw--websocket-connected nil)
    (setq emacs-openclaw--websocket
          (websocket-open
           url
           :on-open #'emacs-openclaw--websocket-on-open
           :on-message #'emacs-openclaw--websocket-on-message
           :on-close #'emacs-openclaw--websocket-on-close
           :on-error #'emacs-openclaw--websocket-on-error))))

;;;###autoload
(defun emacs-openclaw-disconnect ()
  "Disconnect from OpenClaw gateway."
  (interactive)
  (when (and emacs-openclaw--websocket 
             (websocket-openp emacs-openclaw--websocket))
    (websocket-close emacs-openclaw--websocket)
    (setq emacs-openclaw--websocket nil)
    (setq emacs-openclaw--websocket-connected nil)
    (message "emacs-openclaw: Disconnected from gateway")))

(defun emacs-openclaw--websocket-send-chat (prompt callback)
  "Send a chat completion request via websocket."
  (emacs-openclaw--ensure-websocket)
  
  (let* ((req-id (emacs-openclaw--generate-request-id))
         (msg (json-encode
               `((type . "req")
                 (id . ,req-id)
                 (method . "chat.completions")
                 (params . ((messages . (((role . "user") (content . ,prompt))))
                           (model . "openclaw:main")
                           (stream . t)))))))
    
    ;; Store callback for this request
    (puthash req-id callback emacs-openclaw--pending-requests)
    
    ;; Reset message buffer for new message
    (setq emacs-openclaw--current-message-buffer "")
    
    ;; Send the request
    (websocket-send-text emacs-openclaw--websocket msg)))


;; ============================================================================
;; Server Management
;; ============================================================================

(defun emacs-openclaw--find-server-dir ()
  "Find the directory containing the OpenClaw server."
  (let* ((library-path (locate-library "emacs-openclaw"))
         (library-dir (when library-path (file-name-directory library-path))))
    (or
     (let ((candidate (and library-dir (expand-file-name "server" library-dir))))
       (when (and candidate (file-directory-p candidate)) candidate))
     (when (and library-dir (string-match-p "/straight/build/" library-dir))
       (let* ((repo-dir (replace-regexp-in-string "/straight/build/" "/straight/repos/" library-dir))
              (candidate (expand-file-name "server" repo-dir)))
         (when (and candidate (file-directory-p candidate)) candidate)))
     (let* ((current-file (or load-file-name buffer-file-name))
            (dev-dir (when current-file (expand-file-name "server" (file-name-directory current-file)))))
       (when (and dev-dir (file-directory-p dev-dir)) dev-dir)))))

(defun emacs-openclaw--server-running-p ()
  "Check if the Gmail/Calendar tools server is running."
  (condition-case nil
      (with-current-buffer (url-retrieve-synchronously 
                            (format "http://127.0.0.1:%d/health" emacs-openclaw-server-port)
                            t nil 1)
        (goto-char (point-min))
        (prog1 (search-forward "\"status\"" nil t)
          (kill-buffer)))
    (error nil)))

;;;###autoload
(defun emacs-openclaw--start-server ()
  "Start the Gmail/Calendar tools server."
  (interactive)
  (if (emacs-openclaw--server-running-p)
      (message "OpenClaw server already running on port %d" emacs-openclaw-server-port)
    (let ((server-dir (emacs-openclaw--find-server-dir)))
      
      (unless (file-directory-p emacs-openclaw-data-dir)
        (make-directory emacs-openclaw-data-dir t))

      (unless server-dir
        (error "Cannot find server directory. Please ensure emacs-openclaw is installed correctly"))
      
      (unless (executable-find "python3")
        (error "python3 not found. Please install Python 3"))
      
      ;; 3. Validate Secrets in the specific data directory
      (unless (file-exists-p emacs-openclaw-client-secret-path)
        (error "client_secret.json not found! Please place it in: %s" emacs-openclaw-client-secret-path))
      
      (let ((default-directory server-dir)
            ;; Pass the secret path via env var so the python server knows where to look
            (process-environment (cons (format "OPENCLAW_CLIENT_SECRET=%s" emacs-openclaw-client-secret-path)
                                       process-environment)))
        (setq emacs-openclaw--server-process
              (start-process
               "openclaw-server"
               (get-buffer-create emacs-openclaw--server-buffer)
               "python3" "-m" "uvicorn" "server:app"
               "--host" "127.0.0.1"
               "--port" (number-to-string emacs-openclaw-server-port)))
        
        (message "Starting OpenClaw server on port %d..." emacs-openclaw-server-port)
        
        (let ((max-attempts 15) (attempt 0) (delay 0.8))
          (while (and (< attempt max-attempts)
                      (not (emacs-openclaw--server-running-p)))
            (setq attempt (1+ attempt))
            (sit-for delay)
            (setq delay (min 2.0 (* delay 1.2))))
          
          (if (emacs-openclaw--server-running-p)
              (message "OpenClaw server started successfully")
            (message "Server taking longer than expected. Check %s" emacs-openclaw--server-buffer)))))))

;;;###autoload
(defun emacs-openclaw--stop-server ()
  "Stop the Gmail/Calendar tools server."
  (interactive)
  (when (and emacs-openclaw--server-process (process-live-p emacs-openclaw--server-process))
    (kill-process emacs-openclaw--server-process)
    (setq emacs-openclaw--server-process nil)
    (message "OpenClaw server stopped")))

(defun emacs-openclaw--ensure-server-running ()
  "Ensure the server is running, starting it if necessary."
  (when (and emacs-openclaw-auto-start-server (not (emacs-openclaw--server-running-p)))
    (emacs-openclaw--start-server)))

;;;###autoload
(defun emacs-openclaw-show-server-buffer ()
  "Show the server output buffer."
  (interactive)
  (if (get-buffer emacs-openclaw--server-buffer)
      (pop-to-buffer emacs-openclaw--server-buffer)
    (message "Server buffer not found.")))

;;;###autoload
(defun emacs-openclaw-get-available-tools ()
  "Get list of available tools from the server."
  (interactive)
  (if (emacs-openclaw--server-running-p)
      (request
        (format "http://127.0.0.1:%d/tools" emacs-openclaw-server-port)
        :type "GET"
        :parser 'json-read
        :success (cl-function
                  (lambda (&key data &allow-other-keys)
                    (let ((tools (alist-get 'tools data)))
                      (emacs-openclaw--save-tools-config 
                       (list :server-port emacs-openclaw-server-port
                             :tools (append tools nil)
                             :last-updated (format-time-string "%Y-%m-%d %H:%M:%S")))
                      (message "Available OpenClaw tools: %d found" (length tools))
                      (with-current-buffer (get-buffer-create "*OpenClaw-Tools*")
                        (erase-buffer)
                        (insert "Available OpenClaw Gmail/Calendar Tools:\n\n")
                        (dolist (tool tools)
                          (insert (format "• %s (%s %s)\n  %s\n\n"
                                        (alist-get 'name tool)
                                        (alist-get 'method tool)
                                        (alist-get 'endpoint tool)
                                        (alist-get 'description tool))))
                        (goto-char (point-min))
                        (pop-to-buffer (current-buffer))))))
        :error (cl-function
                (lambda (&key error-thrown &allow-other-keys)
                  (message "Failed to get tools: %s" error-thrown))))
    (message "Server is not running.")))

;; ============================================================================
;; Helper Functions
;; ============================================================================

(defun emacs-openclaw--log (msg &optional face)
  "Log MSG to the OpenClaw buffer with optional FACE."
  (with-current-buffer (get-buffer-create emacs-openclaw-buffer-name)
    (let ((inhibit-read-only t))
      (save-excursion
        (goto-char (point-max))
        (insert (if face (propertize msg 'face face) msg)))
      (let ((window (get-buffer-window)))
        (when window (set-window-point window (point-max)))))))

(defun emacs-openclaw--send-request (prompt)
  "Send PROMPT to OpenClaw via websocket and log the response."
  (emacs-openclaw--log "\n" nil)
  (emacs-openclaw--log (concat emacs-openclaw-message-separator "\n") 'shadow)
  (emacs-openclaw--log "You: " 'emacs-openclaw-user-face)
  (emacs-openclaw--log (format "%s\n" prompt) nil)
  (emacs-openclaw--log (concat emacs-openclaw-message-separator "\n") 'shadow)
  (emacs-openclaw--log "\n" nil)
  (emacs-openclaw--log "OpenClaw: " 'emacs-openclaw-response-face)
  
  (emacs-openclaw--websocket-send-chat 
   prompt
   (lambda (response)
     ;; This callback is called when the final response arrives
     ;; The streaming content has already been displayed via chat.delta events
     (let ((ok (alist-get 'ok response)))
       (if ok
           (progn
             ;; Add final separator after streaming completes
             (emacs-openclaw--log "\n" nil)
             (emacs-openclaw--log (concat emacs-openclaw-message-separator "\n") 'shadow))
         ;; Handle error
         (let ((error-data (alist-get 'error response)))
           (emacs-openclaw--log (format "\n[Error]: %s\n" error-data) 'error)
           (emacs-openclaw--log (concat emacs-openclaw-message-separator "\n") 'shadow)))))))

;; ============================================================================
;; Interactive Commands
;; ============================================================================

(defun emacs-openclaw-send-line ()
  "Send the current line to OpenClaw and clear it."
  (interactive)
  (let* ((beg (line-beginning-position))
         (end (line-end-position))
         (text (buffer-substring-no-properties beg end)))
    (when (not (string-empty-p (string-trim text)))
      (delete-region beg end)
      (emacs-openclaw--send-request text))))

;;;###autoload
(defun emacs-openclaw-chat ()
  "Open the OpenClaw chat buffer and enable the minor mode."
  (interactive)
  (emacs-openclaw--ensure-server-running)
  (let ((buf (get-buffer-create emacs-openclaw-buffer-name)))
    (with-current-buffer buf
      (unless (derived-mode-p 'emacs-openclaw-mode)
        (emacs-openclaw-mode 1)
        (visual-line-mode 1))
      (when (= (buffer-size) 0)
        (let ((inhibit-read-only t))
          (insert (propertize (concat emacs-openclaw-welcome-message "\n")
                              'face '(:foreground "yellow" :weight bold)))
          (insert (propertize (concat emacs-openclaw-message-separator "\n")
                              'face 'shadow))
          (insert (concat "\n" emacs-openclaw-instructions "\n\n"))
          (insert (propertize "You: " 'face 'emacs-openclaw-user-face)))))
    (pop-to-buffer buf)))

;;;###autoload
(defun emacs-openclaw-send-region-or-buffer ()
  "Send region (or whole buffer if no region) to OpenClaw."
  (interactive)
  (let ((text (if (use-region-p)
                  (buffer-substring-no-properties (region-beginning) (region-end))
                (buffer-string))))
    (emacs-openclaw--send-request text)))

;; ============================================================================
;; Minor Mode Definition
;; ============================================================================

(define-minor-mode emacs-openclaw-mode
  "Minor mode for chatting with OpenClaw."
  :lighter " Claw"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "RET") #'emacs-openclaw-send-line)
            map))

(provide 'emacs-openclaw)
;;; emacs-openclaw.el ends here
