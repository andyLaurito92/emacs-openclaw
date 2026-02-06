;;; demo-faces.el --- Demonstration of improved chat UX -*- lexical-binding: t; -*-

;; This file demonstrates the improved visual distinction between user input
;; and OpenClaw responses in the chat buffer.

;;; Commentary:

;; The emacs-openclaw package now uses custom faces to clearly distinguish
;; between user messages and AI responses:
;;
;; - User input: Green, bold text with "You:" prefix
;; - OpenClaw responses: Cyan, normal weight with "OpenClaw:" prefix
;; - Visual separators: Gray lines between messages
;;
;; This addresses the issue where both user input and responses appeared
;; in similar pink colors, making them confusing to distinguish.

;;; Code:

(require 'emacs-openclaw)

(defun demo-faces/show-example ()
  "Create a demo buffer showing the improved chat appearance."
  (interactive)
  (let ((buf (get-buffer-create "*OpenClaw-Demo*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
      (insert "  OpenClaw Chat - Improved UX Demo\n")
      (insert "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")
      
      ;; Example 1: User input
      (insert (propertize "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" 'face 'shadow))
      (insert (propertize "You: " 'face 'emacs-openclaw-user-face))
      (insert "What is Emacs?\n")
      (insert (propertize "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n" 'face 'shadow))
      
      ;; Example 1: OpenClaw response
      (insert (propertize "OpenClaw: " 'face 'emacs-openclaw-response-face))
      (insert "Emacs is a powerful, extensible text editor that has been\n")
      (insert "around since 1976. It's known for its flexibility and the\n")
      (insert "ability to customize almost every aspect of its behavior.\n\n")
      
      ;; Example 2: User input
      (insert (propertize "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" 'face 'shadow))
      (insert (propertize "You: " 'face 'emacs-openclaw-user-face))
      (insert "How do I learn Emacs Lisp?\n")
      (insert (propertize "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n" 'face 'shadow))
      
      ;; Example 2: OpenClaw response
      (insert (propertize "OpenClaw: " 'face 'emacs-openclaw-response-face))
      (insert "Start with the built-in Emacs Lisp tutorial (C-h i m Elisp).\n")
      (insert "Practice by writing small functions and gradually build up\n")
      (insert "your understanding through real projects.\n\n")
      
      (insert "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
      (insert "Notice how user input (green, bold) is clearly distinct\n")
      (insert "from OpenClaw responses (cyan, normal weight).\n")
      (insert "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
      
      (goto-char (point-min))
      (view-mode 1))
    (pop-to-buffer buf)))

(provide 'demo-faces)
;;; demo-faces.el ends here
