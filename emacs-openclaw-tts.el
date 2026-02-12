;;; emacs-openclaw-tts.el --- Text-to-speech integration for emacs-openclaw

;; Copyright (C) 2026 Andres Laurito
;; Author: Andres Laurito <andres@example.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: openclaw tts speech

;;; Commentary:

;; Provides text-to-speech (TTS) functionality for emacs-openclaw responses.
;; Uses the system `say` command on macOS for natural audio output.

;;; Code:

(defgroup emacs-openclaw-tts nil
  "Text-to-speech settings for emacs-openclaw."
  :group 'emacs-openclaw
  :prefix "emacs-openclaw-tts-")

(defcustom emacs-openclaw-tts-enabled nil
  "Enable audio playback of responses."
  :type 'boolean
  :group 'emacs-openclaw-tts)

(defcustom emacs-openclaw-tts-voice "Samantha"
  "Voice to use for text-to-speech on macOS.
Run `say -v '?' to see available voices."
  :type 'string
  :group 'emacs-openclaw-tts)

(defcustom emacs-openclaw-tts-rate 150
  "Speech rate in words per minute (default 150)."
  :type 'integer
  :group 'emacs-openclaw-tts)

(defcustom emacs-openclaw-tts-command "say"
  "Command to use for text-to-speech.
Defaults to 'say' (macOS). Set to 'espeak' for Linux."
  :type 'string
  :group 'emacs-openclaw-tts)

(defun emacs-openclaw-tts-speak (text)
  "Speak TEXT using system TTS.
Uses `say` on macOS or `espeak` on Linux."
  (when (and text (not (string-empty-p text)))
    (let* ((cmd emacs-openclaw-tts-command)
           (is-say (string= cmd "say"))
           (args (if is-say
                     (list "-v" emacs-openclaw-tts-voice
                           "-r" (number-to-string emacs-openclaw-tts-rate)
                           text)
                   (list "-v" emacs-openclaw-tts-voice
                         "-s" (number-to-string emacs-openclaw-tts-rate)
                         text))))
      (apply #'call-process cmd nil 0 nil args))))

(defun emacs-openclaw-tts-speak-response (response)
  "Speak RESPONSE if TTS is enabled.
Called after inserting a full response in the chat buffer."
  (when emacs-openclaw-tts-enabled
    (emacs-openclaw-tts-speak response)))

(defun emacs-openclaw-tts-toggle ()
  "Toggle text-to-speech on/off."
  (interactive)
  (setq emacs-openclaw-tts-enabled (not emacs-openclaw-tts-enabled))
  (message "OpenClaw TTS %s"
           (if emacs-openclaw-tts-enabled "enabled" "disabled")))

(defun emacs-openclaw-tts-list-voices ()
  "List available voices on macOS."
  (interactive)
  (when (string= emacs-openclaw-tts-command "say")
    (shell-command "say -v ?")))

(provide 'emacs-openclaw-tts)
;;; emacs-openclaw-tts.el ends here
