;;; emacs-openclaw.el --- OpenClaw chat integration for Emacs -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (request "0.3.0"))
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

;; ============================================================================
;; Internal Variables
;; ============================================================================

(defvar emacs-openclaw--mode-map nil
  "Keymap for emacs-openclaw-mode.")

(defvar emacs-openclaw--token-cache nil
  "Cached token (loaded from config file).")

(defvar emacs-openclaw--port-cache nil
  "Cached port (loaded from config file).")

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

(defun emacs-openclaw--send-request (prompt)
  "Send PROMPT to OpenClaw and log the response."
  (emacs-openclaw--log (format "\nYou: %s\n" prompt) 'font-lock-comment-face)
  (let ((token (emacs-openclaw--get-token))
        (base-url (emacs-openclaw--get-base-url)))
    (request
      (concat base-url "/v1/chat/completions")
      :type "POST"
      :headers `(("Authorization" . ,(format "Bearer %s" token))
                 ("Content-Type" . "application/json")
                 ("x-openclaw-session-key" . ,emacs-openclaw-session-key))
      :data (json-encode `((model . "openclaw:main")
                           (messages . [((role . "user") (content . ,prompt))])
                           (stream . :json-false)))
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

;; Evil mode integration
(with-eval-after-load 'evil
  (evil-define-key 'insert emacs-openclaw-mode-map (kbd "RET") #'emacs-openclaw-send-line)
  (evil-define-key 'normal emacs-openclaw-mode-map (kbd "RET") #'emacs-openclaw-send-line))

;; ============================================================================
;; Keybindings
;; ============================================================================

(global-set-key (kbd "C-c C-w s") #'emacs-openclaw-chat)
(global-set-key (kbd "C-c C-w r") #'emacs-openclaw-send-region-or-buffer)

;; ============================================================================
;; Module Export
;; ============================================================================

(provide 'emacs-openclaw)

;;; emacs-openclaw.el ends here
