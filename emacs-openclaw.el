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
(require 'cl-lib)
(require 'json)

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
  "OpenClaw authentication token."
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
;; Keymap Definition
;; ============================================================================

(defvar emacs-openclaw-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'emacs-openclaw-send-line)
    map)
  "Keymap for emacs-openclaw-mode.")

;; ============================================================================
;; Helper Functions
;; ============================================================================

(defun emacs-openclaw--log (msg &optional face)
  "Log MSG to the OpenClaw buffer with optional FACE."
  (let ((buf (get-buffer-create emacs-openclaw-buffer-name)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (save-excursion
          (goto-char (point-max))
          (insert (if face (propertize msg 'face face) msg)))
        ;; Auto-scroll if the buffer is visible
        (let ((window (get-buffer-window buf)))
          (when window (set-window-point window (point-max))))))))

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
                       (choice (and choices (aref choices 0)))
                       (message (and choice (alist-get 'message choice)))
                       (content (and message (alist-get 'content message))))
                  (if content
                      (emacs-openclaw--log (format "OpenClaw: %s\n" content) 'font-lock-keyword-face)
                    (emacs-openclaw--log "[Error]: Unexpected API response structure." 'error)))))
    :error (cl-function 
            (lambda (&key error-thrown &allow-other-keys)
              (emacs-openclaw--log (format "[Error]: %s\n" (or error-thrown "Unknown error")) 'error)))))

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

;;;###autoload
(define-minor-mode emacs-openclaw-mode
  "Minor mode for chatting with OpenClaw.
When enabled, RET sends the current line to OpenClaw."
  :lighter " Claw"
  :keymap emacs-openclaw-mode-map)

(provide 'emacs-openclaw)

;;; emacs-openclaw.el ends here
