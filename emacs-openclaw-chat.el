;;; emacs-openclaw-chat.el --- Chat buffer and messaging -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0

;;; Commentary:
;; Chat buffer management, message logging, and user interaction.

;;; Code:

(require 'emacs-openclaw-config)
(require 'emacs-openclaw-websocket)
(require 'emacs-openclaw-server)

;; ============================================================================
;; Customization Variables
;; ============================================================================

(defcustom emacs-openclaw-buffer-name "*OpenClaw-Chat*"
  "Name of the OpenClaw chat buffer."
  :type 'string
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
;; Message Logging
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

;; ============================================================================
;; Chat Request Handling
;; ============================================================================

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
     (let ((ok (alist-get 'ok response)))
       (if ok
           (progn
             ;; Separator is added by handle-agent-event when state="end"
             nil)
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
  ;; Ensure mode is loaded
  (unless (fboundp 'emacs-openclaw-mode)
    (error "emacs-openclaw-mode not defined. Mode module failed to load. Loaded features: %s" 
           (delq nil (mapcar (lambda (f) (if (string-match "emacs-openclaw" (symbol-name f)) f)) features))))
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
          (insert (concat "\n" emacs-openclaw-instructions "\n\n")))))
    (pop-to-buffer buf)))

;;;###autoload
(defun emacs-openclaw-send-region-or-buffer ()
  "Send region (or whole buffer if no region) to OpenClaw."
  (interactive)
  (let ((text (if (use-region-p)
                  (buffer-substring-no-properties (region-beginning) (region-end))
                (buffer-string))))
    (emacs-openclaw--send-request text)))

(provide 'emacs-openclaw-chat)
;;; emacs-openclaw-chat.el ends here
