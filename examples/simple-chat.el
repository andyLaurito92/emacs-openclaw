;;; emacs-openclaw-example.el --- Basic usage examples -*- lexical-binding: t; -*-

;; This file demonstrates how to use the OpenClaw integration from Emacs.
;; Copy these patterns into your own config or start building features on top.

;;; Commentary:

;; The OpenClaw integration provides:
;; 1. `andy/openclaw-chat` — Opens interactive chat buffer
;; 2. `andy/openclaw-do-request` — Send a request directly
;; 3. Custom minor mode `andy/openclaw-mode` — Enables RET to send

;;; Code:

;; Example 1: Basic chat (simple query)
(defun example/ask-openclaw ()
  "Example: Ask a simple question."
  (interactive)
  (andy/openclaw-do-request "What is functional programming?"))

;; Example 2: Send current buffer to OpenClaw for review
(defun example/review-buffer ()
  "Example: Get OpenClaw's feedback on current buffer."
  (interactive)
  (let ((code (buffer-string)))
    (andy/openclaw-do-request 
     (format "Review this code for improvements:\n\n%s" code))))

;; Example 3: Contextual help for current word
(defun example/explain-word ()
  "Example: Ask OpenClaw to explain the word at point."
  (interactive)
  (let ((word (thing-at-point 'word)))
    (when word
      (andy/openclaw-do-request 
       (format "Explain the concept: %s" word)))))

;; Example 4: Open chat and keep conversation
(defun example/start-session ()
  "Example: Start an interactive OpenClaw session."
  (interactive)
  ;; Opens the buffer and enters the minor mode
  ;; Now you can type multiple messages and press RET each time
  (andy/openclaw-chat))

;;; How to use:

;; 1. Make sure the FastAPI server is running:
;;    cd server && python server.py

;; 2. Load this file:
;;    M-x load-file RET emacs-openclaw-example.el

;; 3. Call any example:
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
