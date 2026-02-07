;;; emacs-openclaw-mode.el --- Minor mode definition -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0

;;; Commentary:
;; Defines the emacs-openclaw-mode minor mode and keybindings.

;;; Code:

;; ============================================================================
;; Keymap Definition
;; ============================================================================

(defvar emacs-openclaw-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Use symbol reference instead of #' to avoid requiring chat at load time
    (define-key map (kbd "RET") 'emacs-openclaw-send-line)
    map)
  "Keymap for `emacs-openclaw-mode'.")

;; ============================================================================
;; Minor Mode Definition
;; ============================================================================

(define-minor-mode emacs-openclaw-mode
  "Minor mode for chatting with OpenClaw."
  :lighter " Claw"
  :keymap emacs-openclaw-mode-map)

(provide 'emacs-openclaw-mode)
;;; emacs-openclaw-mode.el ends here
