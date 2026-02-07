;;; emacs-openclaw.el --- OpenClaw chat integration for Emacs -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.1
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
  "OpenClaw authentication token."
  :type '(choice (const :tag "Auto-detect from ~/.openclaw/openclaw.json" nil)
                 (string :tag "Explicit token"))
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-port nil
  "OpenClaw gateway port."
  :type '(choice (const :tag "Auto-detect from ~/.openclaw/openclaw.json" nil)
                 (integer :tag "Explicit port"))
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-websocket-timeout 10
  "Timeout in seconds for establishing WebSocket connection."
  :type 'integer
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-message-separator "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  "Visual separator between messages."
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-welcome-message "Welcome to OpenClaw Chat!"
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-instructions "Type your message below and press RET to send."
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-server-port 3333
  "Port for the OpenClaw server."
  :type 'integer
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-auto-start-server t
  "Whether to automatically start the OpenClaw server."
  :type 'boolean
  :group 'emacs-openclaw)
;; ============================================================================
;; Internal Variables
;; ============================================================================

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
;; Configuration & Faces
;; ============================================================================

(defface emacs-openclaw-user-face '((t :foreground "green" :weight bold)) "User face." :group 'emacs-openclaw)
(defface emacs-openclaw-response-face '((t :foreground "cyan" :weight normal)) "Response face." :group 'emacs-openclaw)

(defun emacs-openclaw--config-file () (expand-file-name "tools-config.json" emacs-openclaw-data-dir))

(defun emacs-openclaw--save-tools-config (tools-info)
  (unless (file-directory-p emacs-openclaw-data-dir) (make-directory emacs-openclaw-data-dir t))
  (with-temp-file (emacs-openclaw--config-file) (insert (json-encode tools-info))))

(defun emacs-openclaw--load-config ()
  (let ((config-file (expand-file-name "~/.openclaw/openclaw.json")))
    (when (file-exists-p config-file)
      (condition-case nil
          (let* ((json-object-type 'plist) (config (json-read-file config-file))
                 (gateway (plist-get config :gateway)) (auth (plist-get gateway :auth)))
            (list :token (plist-get auth :token) :port (plist-get gateway :port)))
        (error nil)))))

(defun emacs-openclaw--ensure-config ()
  (unless emacs-openclaw--token-cache
    (let ((config (emacs-openclaw--load-config)))
      (if config
          (setq emacs-openclaw--token-cache (plist-get config :token)
                emacs-openclaw--port-cache (plist-get config :port))
        (setq emacs-openclaw--token-cache :not-found))))
  (let ((token (or emacs-openclaw-token (unless (eq emacs-openclaw--token-cache :not-found) emacs-openclaw--token-cache)))
        (port (or emacs-openclaw-port (if (integerp emacs-openclaw--port-cache) emacs-openclaw--port-cache 18789))))
    (unless token (error "OpenClaw token not found"))
    (list :token token :port port)))

;; ============================================================================
;; WebSocket Connection Management
;; ============================================================================

(defun emacs-openclaw--generate-request-id ()
  "Generate a unique request ID."
  (setq emacs-openclaw--request-id-counter (1+ emacs-openclaw--request-id-counter))
  (format "emacs-req-%d" emacs-openclaw--request-id-counter))

(defun emacs-openclaw--websocket-on-open (ws)
  "Handle websocket connection open event."
  (message "emacs-openclaw: Connection opened, handshaking...")
  (let* ((config (emacs-openclaw--ensure-config))
         (token (plist-get config :token))
         (connect-msg (json-encode
                       `((type . "req")
                         (id . ,(emacs-openclaw--generate-request-id))
                         (method . "connect")
                         (params . ((minProtocol . 3)
                                   (maxProtocol . 3)
                                   (client . ((id . "emacs-openclaw")
                                             (version . "0.1.1")
                                             (platform . "emacs")
                                             (mode . "operator")))
                                   (role . "operator")
                                   (scopes . ("operator.read" "operator.write"))
                                   (caps . ())
                                   (commands . ())
                                   (permissions . ())
                                   (auth . ((token . ,token)))
                                   (locale . "en-US")
                                   (userAgent . "emacs-openclaw/0.1.1")))))))
    (websocket-send-text ws connect-msg)))

(defun emacs-openclaw--websocket-on-message (_ws frame)
  "Handle incoming websocket messages with safety guards."
  (let ((msg-text (websocket-frame-text frame)))
    ;; Log raw message for debugging if needed
    ;; (message "emacs-openclaw DEBUG: Received: %s" msg-text)
    
    (if (and msg-text (string-match-p "^[ \t\n\r]*[\\[{]" msg-text))
        (condition-case err
            (let* ((json-object-type 'alist)
                   (json-array-type 'list)
                   (msg (json-read-from-string msg-text))
                   (msg-type (alist-get 'type msg))
                   (msg-id (alist-get 'id msg)))
              (cond
               ((and (string= msg-type "res") msg-id)
                (if (alist-get 'ok msg)
                    (progn
                      (setq emacs-openclaw--websocket-connected t)
                      (message "emacs-openclaw: Authenticated successfully"))
                  (message "emacs-openclaw: Auth error: %s" (alist-get 'error msg)))
                (let ((handler (gethash msg-id emacs-openclaw--pending-requests)))
                  (when handler (funcall handler msg) (remhash msg-id emacs-openclaw--pending-requests))))
               
               ((string= msg-type "event")
                (when (string= (alist-get 'event msg) "chat.delta")
                  (emacs-openclaw--handle-chat-delta msg)))))
          (error (message "emacs-openclaw: JSON Parse Error: %S (Data: %s)" err msg-text)))
      ;; If not JSON, just log it as a string
      (unless (string-empty-p (string-trim (or msg-text "")))
        (message "emacs-openclaw: Non-JSON message received: %s" msg-text)))))

(defun emacs-openclaw--handle-chat-delta (msg)
  "Handle a chat.delta streaming event."
  (let* ((payload (alist-get 'payload msg))
         (delta (alist-get 'delta payload))
         (choices (alist-get 'choices delta))
         (content (alist-get 'content (alist-get 'delta (car choices)))))
    (when content
      (setq emacs-openclaw--current-message-buffer (concat emacs-openclaw--current-message-buffer content))
      (emacs-openclaw--log content nil))))

(defun emacs-openclaw--websocket-on-close (_ws)
  "Handle websocket connection close event."
  (setq emacs-openclaw--websocket-connected nil emacs-openclaw--websocket nil)
  (message "emacs-openclaw: Connection closed"))

(defun emacs-openclaw--websocket-on-error (_ws type err)
  "Handle websocket errors."
  (message "emacs-openclaw: WebSocket error [%s]: %s" type err))

(defun emacs-openclaw--ensure-websocket ()
  "Ensure websocket connection is established."
  (unless (and emacs-openclaw--websocket emacs-openclaw--websocket-connected)
    (emacs-openclaw--connect-websocket)
    (let ((retries (floor (/ emacs-openclaw-websocket-timeout 0.2))))
      (while (and (> retries 0) (not emacs-openclaw--websocket-connected))
        (accept-process-output nil 0.2)
        (setq retries (1- retries)))
      (unless emacs-openclaw--websocket-connected
        (error "Failed to establish websocket connection")))))

(defun emacs-openclaw--connect-websocket ()
  "Connect to OpenClaw gateway via websocket."
  (when (and emacs-openclaw--websocket (websocket-openp emacs-openclaw--websocket))
    (websocket-close emacs-openclaw--websocket))
  (let* ((config (emacs-openclaw--ensure-config))
         (url (format "ws://127.0.0.1:%d" (plist-get config :port))))
    (message "emacs-openclaw: Connecting to %s..." url)
    (setq emacs-openclaw--websocket-connected nil)
    (setq emacs-openclaw--websocket
          (websocket-open url
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

;; ============================================================================
;; Messaging Logic
;; ============================================================================

(defun emacs-openclaw--websocket-send-chat (prompt callback)
  "Send a chat completion request via websocket."
  (emacs-openclaw--ensure-websocket)
  (let* ((req-id (emacs-openclaw--generate-request-id))
         (msg (json-encode `((type . "req") (id . ,req-id) (method . "chat.completions")
                             (params . ((messages . (((role . "user") (content . ,prompt))))
                                        (model . "openclaw:main") (stream . t)))))))
    (puthash req-id callback emacs-openclaw--pending-requests)
    (setq emacs-openclaw--current-message-buffer "")
    (websocket-send-text emacs-openclaw--websocket msg)))

(defun emacs-openclaw--log (msg &optional face)
  "Log MSG to the OpenClaw chat buffer, optionally with FACE."
  (with-current-buffer (get-buffer-create emacs-openclaw-buffer-name)
    (let ((inhibit-read-only t))
      (save-excursion (goto-char (point-max)) (insert (if face (propertize msg 'face face) msg)))
      (let ((window (get-buffer-window))) (when window (set-window-point window (point-max)))))))

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
;; Server Management & Interface
;; ============================================================================

(defun emacs-openclaw--server-running-p ()
  (condition-case nil
      (with-current-buffer (url-retrieve-synchronously (format "http://127.0.0.1:%d/health" emacs-openclaw-server-port) t nil 1)
        (goto-char (point-min)) (prog1 (search-forward "\"status\"" nil t) (kill-buffer)))
    (error nil)))

(defun emacs-openclaw--ensure-server-running ()
  (when (and emacs-openclaw-auto-start-server (not (emacs-openclaw--server-running-p)))
    (emacs-openclaw-chat))) ; simplified call

(defun emacs-openclaw-send-line ()
  (interactive)
  (let* ((beg (line-beginning-position)) (end (line-end-position))
         (text (buffer-substring-no-properties beg end)))
    (when (not (string-empty-p (string-trim text))) (delete-region beg end) (emacs-openclaw--send-request text))))

(define-minor-mode emacs-openclaw-mode "Minor mode for OpenClaw." :lighter " Claw"
  :keymap (let ((map (make-sparse-keymap))) (define-key map (kbd "RET") #'emacs-openclaw-send-line) map))

;;;###autoload
(defun emacs-openclaw-chat ()
  "Open the OpenClaw chat buffer."
  (interactive)
  (let ((buf (get-buffer-create emacs-openclaw-buffer-name)))
    (with-current-buffer buf
      (unless (derived-mode-p 'emacs-openclaw-mode) (emacs-openclaw-mode 1) (visual-line-mode 1))
      (when (= (buffer-size) 0)
        (let ((inhibit-read-only t))
          (insert (propertize (concat emacs-openclaw-welcome-message "\n") 'face '(:foreground "yellow" :weight bold)))
          (insert (concat "\n" emacs-openclaw-instructions "\n\nYou: ")))) )
    (pop-to-buffer buf)))

(provide 'emacs-openclaw)
;;; emacs-openclaw.el ends here
