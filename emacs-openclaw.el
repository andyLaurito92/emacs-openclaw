;;; emacs-openclaw.el --- OpenClaw chat integration for Emacs -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (request "0.3.0") (websocket "1.13"))
;; Keywords: tools, openclaw, chat, ai
;; URL: https://github.com/andyLaurito92/emacs-openclaw

;;; Commentary:

;; emacs-openclaw provides an interactive chat interface for OpenClaw
;; directly within Emacs. It automatically detects configuration from
;; ~/.openclaw/openclaw.json (gateway token and port).

;;; Code:

(require 'request)
(require 'json)
(require 'cl-lib)
(require 'websocket)

;; ============================================================================
;; Configuration Loading
;; ============================================================================

(defun emacs-openclaw--load-config ()
  "Load OpenClaw configuration from ~/.openclaw/openclaw.json.
Returns a plist with :token and :port, or nil if file not found."
  (let ((config-file (expand-file-name "~/.openclaw/openclaw.json")))
    (when (file-exists-p config-file)
      (condition-case nil
          (let* ((json-object-type 'plist)
                 (json-array-type 'list)
                 (config (json-read-file config-file))
                 (gateway (plist-get config :gateway))
                 (auth (plist-get gateway :auth))
                 (token (plist-get auth :token))
                 (port (plist-get gateway :port)))
            (when (and token port)
              (list :token token :port port)))
        (error nil)))))

;; ============================================================================
;; Customization Variables
;; ============================================================================

(defgroup emacs-openclaw nil
  "OpenClaw chat integration for Emacs."
  :group 'tools
  :prefix "emacs-openclaw-")

(defcustom emacs-openclaw-buffer-name "*OpenClaw-Chat*"
  "Name of the OpenClaw chat buffer."
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-token nil
  "OpenClaw authentication token.
If nil, will attempt to load from ~/.openclaw/openclaw.json.
You can also set this explicitly to override auto-detection."
  :type '(choice (const :tag "Auto-detect from ~/.openclaw/openclaw.json" nil)
                 (string :tag "Explicit token"))
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-port nil
  "OpenClaw gateway port.
If nil, will attempt to load from ~/.openclaw/openclaw.json.
Default fallback is 18789."
  :type '(choice (const :tag "Auto-detect from ~/.openclaw/openclaw.json" nil)
                 (integer :tag "Explicit port"))
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-session-key "emacs-session"
  "Session key for OpenClaw requests."
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-use-websocket t
  "Whether to use WebSocket for communication with OpenClaw.
If t, attempts WebSocket connection with automatic HTTP fallback on failure.
If nil, uses HTTP requests directly."
  :type 'boolean
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-model "openclaw:main"
  "The OpenClaw model to use for chat completions."
  :type 'string
  :group 'emacs-openclaw)

;; ============================================================================
;; Internal Variables
;; ============================================================================

(defvar emacs-openclaw--mode-map nil
  "Keymap for emacs-openclaw-mode.")

(defvar emacs-openclaw--token-cache nil
  "Cached token (loaded from config file).")

(defvar emacs-openclaw--port-cache nil
  "Cached port (loaded from config file).")

(defvar emacs-openclaw--websocket nil
  "Active WebSocket connection to OpenClaw gateway, or nil if not connected.")

(defvar emacs-openclaw--response-accumulator ""
  "String accumulator for WebSocket response chunks.")

(defvar emacs-openclaw--response-in-progress nil
  "Flag indicating whether a response is currently being received.")

(defconst emacs-openclaw--api-endpoint "/v1/chat/completions"
  "API endpoint path for chat completions.")

(defconst emacs-openclaw--finish-reason-stop "stop"
  "Finish reason value indicating stream completion.")

;; ============================================================================
;; Configuration Helpers
;; ============================================================================

(defun emacs-openclaw--ensure-config ()
  "Ensure token and port are available, loading from config if needed.
Returns a plist with :token and :port."
  ;; Load config once and cache it
  (unless emacs-openclaw--token-cache
    (let ((config (emacs-openclaw--load-config)))
      (if config
          (setq emacs-openclaw--token-cache (plist-get config :token)
                emacs-openclaw--port-cache (plist-get config :port))
        (setq emacs-openclaw--token-cache :not-found))))
  
  ;; Use explicit settings if provided, otherwise use cached values
  (let ((token (or emacs-openclaw-token 
                   (when (and emacs-openclaw--token-cache 
                              (not (eq emacs-openclaw--token-cache :not-found)))
                     emacs-openclaw--token-cache)))
        (port (or emacs-openclaw-port 
                  (when (and emacs-openclaw--port-cache 
                             (not (eq emacs-openclaw--port-cache :not-found)))
                    emacs-openclaw--port-cache)
                  18789)))  ; Fallback default
    
    (unless token
      (error "OpenClaw token not found. Please set emacs-openclaw-token or ensure ~/.openclaw/openclaw.json exists"))
    
    (list :token token :port port)))

(defun emacs-openclaw--get-base-url ()
  "Get the OpenClaw gateway base URL."
  (let ((config (emacs-openclaw--ensure-config)))
    (format "http://127.0.0.1:%d" (plist-get config :port))))

(defun emacs-openclaw--get-websocket-url ()
  "Get the OpenClaw gateway WebSocket URL."
  (let ((config (emacs-openclaw--ensure-config)))
    (format "ws://127.0.0.1:%d" (plist-get config :port))))

(defun emacs-openclaw--get-token ()
  "Get the OpenClaw authentication token."
  (let ((config (emacs-openclaw--ensure-config)))
    (plist-get config :token)))

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

(defun emacs-openclaw--build-message-payload (prompt stream)
  "Build message payload for PROMPT with STREAM flag."
  (json-encode `((model . ,emacs-openclaw-model)
                 (messages . [((role . "user") (content . ,prompt))])
                 (stream . ,stream))))

;; ============================================================================
;; WebSocket Functions
;; ============================================================================

(defun emacs-openclaw--websocket-on-message (websocket frame)
  "Handle incoming WebSocket FRAME from WEBSOCKET."
  (let* ((payload (websocket-frame-payload frame))
         (json-object-type 'alist)
         (json-array-type 'list)
         (data (condition-case err
                   (json-read-from-string payload)
                 (error
                  (emacs-openclaw--log (format "[WebSocket Parse Error]: %s\n" err) 'error)
                  nil))))
    (when data
      (let* ((choices (alist-get 'choices data))
             (choice (and choices (car choices)))
             (delta (and choice (alist-get 'delta choice)))
             (content (and delta (alist-get 'content delta)))
             (finish-reason (and choice (alist-get 'finish_reason choice))))
        (cond
         ;; Accumulate streaming content
         ((and content (stringp content))
          (setq emacs-openclaw--response-accumulator
                (concat emacs-openclaw--response-accumulator content))
          (emacs-openclaw--log content 'font-lock-keyword-face))
         ;; Handle stream completion
         ((and finish-reason (string= finish-reason emacs-openclaw--finish-reason-stop))
          (emacs-openclaw--log "\n")
          (setq emacs-openclaw--response-in-progress nil)))))))

(defun emacs-openclaw--websocket-on-close (websocket)
  "Handle WebSocket WEBSOCKET closure."
  (message "OpenClaw WebSocket connection closed")
  (setq emacs-openclaw--websocket nil)
  (setq emacs-openclaw--response-in-progress nil))

(defun emacs-openclaw--websocket-on-error (websocket type err)
  "Handle WebSocket WEBSOCKET error of TYPE with details ERR."
  (emacs-openclaw--log (format "[WebSocket Error]: %s - %s\n" type err) 'error)
  (message "OpenClaw WebSocket error: %s" err))

(defun emacs-openclaw--ensure-websocket ()
  "Ensure a WebSocket connection is established and return it."
  (unless (and emacs-openclaw--websocket
               (websocket-openp emacs-openclaw--websocket))
    (let* ((url (concat (emacs-openclaw--get-websocket-url) emacs-openclaw--api-endpoint))
           (token (emacs-openclaw--get-token))
           ;; Session key is sent in headers during WebSocket handshake.
           ;; Since WebSocket connections are stateful and long-lived, the session
           ;; is maintained throughout the connection's lifetime without needing
           ;; to resend the session key with each message.
           (headers `(("Authorization" . ,(format "Bearer %s" token))
                      ("x-openclaw-session-key" . ,emacs-openclaw-session-key))))
      (condition-case err
          (setq emacs-openclaw--websocket
                (websocket-open
                 url
                 :custom-header-alist headers
                 :on-message #'emacs-openclaw--websocket-on-message
                 :on-close #'emacs-openclaw--websocket-on-close
                 :on-error #'emacs-openclaw--websocket-on-error))
        (error
         (emacs-openclaw--log (format "[WebSocket Connection Error]: %s\n" err) 'error)
         (message "Failed to connect via WebSocket, falling back to HTTP")
         nil))))
  emacs-openclaw--websocket)

(defun emacs-openclaw--send-via-websocket (prompt)
  "Send PROMPT via WebSocket to OpenClaw."
  (if emacs-openclaw--response-in-progress
      (progn
        (emacs-openclaw--log "[Warning: Previous response still in progress - request blocked]\n" 'warning)
        (message "Previous response still in progress, please wait..."))
    ;; Clear accumulator before starting new request
    (setq emacs-openclaw--response-accumulator "")
    (let ((ws (emacs-openclaw--ensure-websocket)))
      (if ws
          (let ((payload (emacs-openclaw--build-message-payload prompt t)))
            (condition-case err
                (progn
                  (websocket-send-text ws payload)
                  ;; Only set flag if send succeeds
                  (setq emacs-openclaw--response-in-progress t))
              (error
               (emacs-openclaw--log (format "[WebSocket Send Error]: %s\n" err) 'error)
               (message "Failed to send via WebSocket, trying HTTP fallback...")
               (emacs-openclaw--send-via-http prompt))))
        ;; Fallback to HTTP if WebSocket connection fails
        (emacs-openclaw--send-via-http prompt)))))

;; ============================================================================
;; HTTP Functions
;; ============================================================================

(defun emacs-openclaw--send-via-http (prompt)
  "Send PROMPT via HTTP to OpenClaw (fallback method)."
  (let ((token (emacs-openclaw--get-token))
        (base-url (emacs-openclaw--get-base-url)))
    (request
      (concat base-url emacs-openclaw--api-endpoint)
      :type "POST"
      :headers `(("Authorization" . ,(format "Bearer %s" token))
                 ("Content-Type" . "application/json")
                 ("x-openclaw-session-key" . ,emacs-openclaw-session-key))
      :data (emacs-openclaw--build-message-payload prompt :json-false)
      :parser 'json-read
      :success (cl-function 
                (lambda (&key data &allow-other-keys)
                  (let* ((choices (alist-get 'choices data))
                         (choice (aref choices 0))
                         (message (alist-get 'message choice))
                         (content (alist-get 'content message)))
                    (emacs-openclaw--log (format "OpenClaw: %s\n" content) 'font-lock-keyword-face))))
      :error (cl-function 
              (lambda (&key error-thrown &allow-other-keys)
                (emacs-openclaw--log (format "[Error]: %s\n" error-thrown) 'error))))))

(defun emacs-openclaw--send-request (prompt)
  "Send PROMPT to OpenClaw using WebSocket or HTTP based on configuration."
  (emacs-openclaw--log (format "\nYou: %s\n" prompt) 'font-lock-comment-face)
  (if emacs-openclaw-use-websocket
      (emacs-openclaw--send-via-websocket prompt)
    (emacs-openclaw--send-via-http prompt)))

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
  (let ((buf (get-buffer-create emacs-openclaw-buffer-name)))
    (with-current-buffer buf
      (unless (derived-mode-p 'emacs-openclaw-mode)
        (emacs-openclaw-mode 1)
        (visual-line-mode 1)))
    (pop-to-buffer buf)))

;;;###autoload
(defun emacs-openclaw-send-region-or-buffer ()
  "Send region (or whole buffer if no region) to OpenClaw."
  (interactive)
  (let ((text (if (use-region-p)
                  (buffer-substring-no-properties (region-beginning) (region-end))
                (buffer-string))))
    (emacs-openclaw--send-request text)))

(defun emacs-openclaw-disconnect ()
  "Disconnect the WebSocket connection to OpenClaw."
  (interactive)
  (when emacs-openclaw--websocket
    (websocket-close emacs-openclaw--websocket)
    (setq emacs-openclaw--websocket nil)
    (setq emacs-openclaw--response-in-progress nil)
    (message "Disconnected from OpenClaw")))

;; ============================================================================
;; Minor Mode Definition
;; ============================================================================

(define-minor-mode emacs-openclaw-mode
  "Minor mode for chatting with OpenClaw.

When enabled, RET sends the current line to OpenClaw."
  :lighter " Claw"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "RET") #'emacs-openclaw-send-line)
            map))

;; ============================================================================
;; Module Export
;; ============================================================================

(provide 'emacs-openclaw)

;;; emacs-openclaw.el ends here
