;;; emacs-openclaw-example.el --- Basic usage examples -*- lexical-binding: t; -*-

;; This file demonstrates how to use emacs-openclaw from Emacs.
;; Copy these patterns into your own config or start building features on top.

;;; Commentary:

;; The emacs-openclaw package provides:
;; 1. `emacs-openclaw-chat` — Opens interactive chat buffer
;; 2. `emacs-openclaw-send-region-or-buffer` — Send a request directly
;; 3. `emacs-openclaw-send-line` — Send current line in chat mode
;; 4. Custom minor mode `emacs-openclaw-mode` — Enables RET to send

;;; Code:

;; Example 1: Basic chat (simple query)
(defun example/ask-openclaw ()
  "Example: Ask a simple question."
  (interactive)
  (emacs-openclaw-send-region-or-buffer)
  (emacs-openclaw-chat))

;; Example 2: Send current buffer to OpenClaw for review
(defun example/review-buffer ()
  "Example: Get OpenClaw's feedback on current buffer."
  (interactive)
  (let ((code (buffer-string)))
    (message "Sending buffer to OpenClaw for review...")
    (with-temp-buffer
      (insert (format "Review this code for improvements:\n\n%s" code))
      (emacs-openclaw-send-region-or-buffer))))

;; Example 3: Contextual help for current word
(defun example/explain-word ()
  "Example: Ask OpenClaw to explain the word at point."
  (interactive)
  (let ((word (thing-at-point 'word)))
    (when word
      (message "Asking OpenClaw about: %s" word)
      (with-temp-buffer
        (insert (format "Explain the concept: %s" word))
        (emacs-openclaw-send-region-or-buffer)))))

;; Example 4: Open chat and start conversation
(defun example/start-session ()
  "Example: Start an interactive OpenClaw session."
  (interactive)
  ;; Opens the buffer and enters the minor mode
  ;; Now you can type multiple messages and press RET each time
  (emacs-openclaw-chat))

;;; How to use:

;; 1. Make sure emacs-openclaw is loaded:
;;    M-x load-file RET emacs-openclaw.el

;; 2. Make sure the FastAPI server is running:
;;    cd ~/repos/emacs-openclaw && ./start-server.sh

;; 3. Configure your token (in your init.el):
;;    (setq emacs-openclaw-token "your-openclaw-token")

;; 4. Call any example:
;;    M-x example/ask-openclaw RET
;;    M-x example/review-buffer RET
;;    M-x example/start-session RET

;; You can also bind them to keys in your init.el:
;; (global-set-key (kbd "C-c c a") #'example/ask-openclaw)
;; (global-set-key (kbd "C-c c r") #'example/review-buffer)
;; (global-set-key (kbd "C-c c e") #'example/explain-word)
;; (global-set-key (kbd "C-c c s") #'example/start-session)

(provide 'emacs-openclaw-example)
;;; emacs-openclaw-example.el ends here
