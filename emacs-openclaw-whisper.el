;;; emacs-openclaw-whisper.el --- Speech-to-text integration via whisper.el -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0

;;; Commentary:
;; Optional speech-to-text integration for OpenClaw chat buffer.
;; Requires whisper.el to be installed and configured separately.
;; This module provides keybindings and helper functions to transcribe
;; speech and insert it into the chat input.

;;; Code:

(require 'emacs-openclaw-config)

;; ============================================================================
;; Internal State
;; ============================================================================

(defvar emacs-openclaw--whisper-recording nil
  "Track whether we are currently recording speech.")

;; ============================================================================
;; Helper Functions
;; ============================================================================

(defun emacs-openclaw--whisper-available-p ()
  "Check if whisper.el is available and loaded."
  (and (featurep 'whisper)
       (fboundp 'whisper-run)))

(defun emacs-openclaw--insert-transcribed-text (text)
  "Insert transcribed TEXT into the chat input area.
Assumes we're in the OpenClaw chat buffer."
  (let ((buffer (current-buffer)))
    (unless (string-empty-p (string-trim text))
      (goto-char (point-max))
      ;; Skip the trailing newline and position cursor at end of text input
      (let ((inhibit-read-only t))
        (insert text)))))

;; ============================================================================
;; Speech-to-Text Command
;; ============================================================================

(defun emacs-openclaw-transcribe-speech ()
  "Transcribe speech using whisper.el and insert result into chat input.

This function requires:
1. whisper.el to be installed
2. The Whisper CLI (from OpenAI) to be available on PATH
3. ffmpeg to be installed for audio processing

See whisper.el documentation for setup instructions."
  (interactive)
  (unless emacs-openclaw-allow-speech-to-text
    (error "Speech-to-text is not enabled. Set `emacs-openclaw-allow-speech-to-text' to t"))
  
  (unless (emacs-openclaw--whisper-available-p)
    (error "whisper.el is not installed. Please install it and configure as per its documentation"))
  
  (message "Starting speech recording... (Press C-c C-c to stop)")
  (setq emacs-openclaw--whisper-recording t)
  
  (whisper-run
   (lambda (transcript)
     (setq emacs-openclaw--whisper-recording nil)
     (if transcript
         (progn
           (emacs-openclaw--insert-transcribed-text transcript)
           (message "Transcribed: %s" (substring transcript 0 (min 100 (length transcript)))))
       (message "Speech transcription failed or was cancelled")))))

(defun emacs-openclaw-stop-transcribing ()
  "Stop the current speech transcription.
This is typically called via the keybinding, not directly."
  (interactive)
  (when emacs-openclaw--whisper-recording
    (setq emacs-openclaw--whisper-recording nil)
    (message "Speech recording stopped")))

;; ============================================================================
;; Mode Integration
;; ============================================================================

(defun emacs-openclaw--setup-whisper-keybindings (keymap)
  "Add whisper keybindings to the given KEYMAP if enabled."
  (when (and emacs-openclaw-allow-speech-to-text
             emacs-openclaw-whisper-keybinding
             (emacs-openclaw--whisper-available-p))
    (define-key keymap (kbd emacs-openclaw-whisper-keybinding) 'emacs-openclaw-transcribe-speech)))

;; ============================================================================
;; Auto-bind on module load
;; ============================================================================

;; Immediately set up keybindings if the feature is enabled and whisper is available
(when (and emacs-openclaw-allow-speech-to-text
           emacs-openclaw-whisper-keybinding
           (emacs-openclaw--whisper-available-p))
  (require 'emacs-openclaw-mode nil t)
  (emacs-openclaw--setup-whisper-keybindings emacs-openclaw-mode-map)
  (message "emacs-openclaw: Speech-to-text keybinding [%s] registered" emacs-openclaw-whisper-keybinding))

(provide 'emacs-openclaw-whisper)
;;; emacs-openclaw-whisper.el ends here
