;;; emacs-openclaw-mode.el --- Minor mode definition -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0

;;; Commentary:
;; Defines the emacs-openclaw-mode minor mode and keybindings.

;;; Code:

;; Forward declare functions from chat module
(declare-function emacs-openclaw-send-line "emacs-openclaw-chat")

;; ============================================================================
;; Minor Mode Definition
;; ============================================================================

(define-minor-mode emacs-openclaw-mode
  "Minor mode for chatting with OpenClaw."
  :lighter " Claw"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "RET") #'emacs-openclaw-send-line)
            map))

(provide 'emacs-openclaw-mode)
;;; emacs-openclaw-mode.el ends here
