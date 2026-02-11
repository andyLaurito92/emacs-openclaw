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
  :keymap emacs-openclaw-mode-map
  (when emacs-openclaw-mode
    ;; Setup whisper integration if enabled
    (emacs-openclaw--setup-whisper)))

;; ============================================================================
;; Whisper Setup (Conditional Loading)
;; ============================================================================

(defun emacs-openclaw--setup-whisper ()
  "Conditionally load and setup whisper.el integration if enabled."
  (require 'emacs-openclaw-config)
  (when (and (boundp 'emacs-openclaw-allow-speech-to-text)
             emacs-openclaw-allow-speech-to-text)
    (condition-case err
        (progn
          (require 'emacs-openclaw-whisper)
          (emacs-openclaw--setup-whisper-keybindings emacs-openclaw-mode-map))
      (error
       (message "emacs-openclaw: Failed to load whisper integration: %s" err)))))

(provide 'emacs-openclaw-mode)
;;; emacs-openclaw-mode.el ends here
