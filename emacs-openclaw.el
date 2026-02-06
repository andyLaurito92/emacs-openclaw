;;; emacs-openclaw.el --- OpenClaw chat integration for Emacs -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (request "0.3.0"))
;; Keywords: tools, openclaw, chat, ai
;; URL: https://github.com/andyLaurito92/emacs-openclaw

;;; Commentary:

;; emacs-openclaw provides an interactive chat interface for OpenClaw
;; directly within Emacs. It communicates with a local FastAPI server
;; that handles OAuth-authenticated access to Gmail and Google Calendar.

;;; Code:

(require 'request)

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

(defcustom emacs-openclaw-token ""
  "OpenClaw authentication token.
You can get this from your OpenClaw gateway."
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-base-url "http://127.0.0.1:18789"
  "Base URL of the OpenClaw gateway."
  :type 'string
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
  (request
    (concat emacs-openclaw-base-url "/v1/chat/completions")
    :type "POST"
    :headers `(("Authorization" . ,(format "Bearer %s" emacs-openclaw-token))
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
              (emacs-openclaw--log (format "[Error]: %s\n" error-thrown) 'error)))))

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

(defun emacs-openclaw-chat ()
  "Open the OpenClaw chat buffer and enable the minor mode."
  (interactive)
  (let ((buf (get-buffer-create emacs-openclaw-buffer-name)))
    (with-current-buffer buf
      (unless (derived-mode-p 'emacs-openclaw-mode)
        (emacs-openclaw-mode 1)
        (visual-line-mode 1)))
    (pop-to-buffer buf)))

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
