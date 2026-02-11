;;; emacs-openclaw-chat.el --- Chat buffer and messaging -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0

;;; Commentary:
;; Chat buffer management, message logging, and user interaction.

;;; Code:

(require 'emacs-openclaw-config)
(require 'emacs-openclaw-websocket)
(require 'emacs-openclaw-server)

;; Load mode module
(require 'emacs-openclaw-mode)

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

;; Track active requests to know if agent events were received
(defvar emacs-openclaw--active-requests (make-hash-table :test 'equal)
  "Hash table of active request IDs to track if agent events were received.")

;; ============================================================================
;; Message Logging
;; ============================================================================

(defun emacs-openclaw--log (msg &optional face)
  "Log MSG to the OpenClaw buffer with optional FACE."
  (when-let ((buf (get-buffer emacs-openclaw-buffer-name)))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (save-excursion
            (goto-char (point-max))
            (insert (if face (propertize msg 'face face) msg)))
          (let ((window (get-buffer-window)))
            (when window (set-window-point window (point-max)))))))))

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
  (emacs-openclaw--log "\n" nil)  ; Start response on new line
  
  (emacs-openclaw--websocket-send-chat 
   prompt
   (lambda (response)
     (let ((ok (alist-get 'ok response))
           (msg-id (alist-get 'id response)))
       (if ok
           (progn
             ;; Only extract from res if no agent events were received
             ;; (agent events already streamed and displayed the response)
             (unless (gethash msg-id emacs-openclaw--active-requests)
               (let* ((payload (alist-get 'payload response))
                      (result (alist-get 'result payload))
                      (payloads (alist-get 'payloads result))
                      (first-payload (when (listp payloads) (car payloads)))
                      (response-text (when first-payload (alist-get 'text first-payload))))
                 (when response-text
                   (emacs-openclaw--log response-text nil)
                   (emacs-openclaw--log "\n" nil)
                   (emacs-openclaw--log (concat emacs-openclaw-message-separator "\n") 'shadow)
                   (emacs-openclaw--log "\n" nil))))
             ;; Clean up tracking
             (remhash msg-id emacs-openclaw--active-requests))
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
