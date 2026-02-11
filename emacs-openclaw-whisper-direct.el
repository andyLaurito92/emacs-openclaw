;;; emacs-openclaw-whisper-direct.el --- Direct Whisper CLI integration -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0

;;; Commentary:
;; Direct integration with OpenAI Whisper CLI (no whisper.el dependency).
;; Records audio via sox/ffmpeg and transcribes using the Whisper binary directly.

;;; Code:

(require 'emacs-openclaw-config)

;; ============================================================================
;; Configuration
;; ============================================================================

(defcustom emacs-openclaw-whisper-binary "/opt/homebrew/bin/whisper"
  "Path to the OpenAI Whisper CLI binary."
  :type 'file
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-whisper-model "base"
  "Whisper model to use (tiny, base, small, medium, large)."
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-whisper-language nil
  "Language code for Whisper (e.g., 'en', 'es'). nil = auto-detect."
  :type '(choice (const nil) string)
  :group 'emacs-openclaw)

;; ============================================================================
;; State Variables
;; ============================================================================

(defvar emacs-openclaw--whisper-recording-process nil
  "The sox/ffmpeg process recording audio.")

(defvar emacs-openclaw--whisper-recording-file nil
  "Temporary WAV file for recording.")

(defvar emacs-openclaw--whisper-recording-buffer nil
  "Buffer where transcription output will be inserted.")

(defvar emacs-openclaw--whisper-recording-point nil
  "Point position to insert transcribed text.")

;; ============================================================================
;; Helpers
;; ============================================================================

(defun emacs-openclaw--whisper-binary-exists-p ()
  "Check if the Whisper binary exists and is executable."
  (and (file-executable-p emacs-openclaw-whisper-binary)
       (file-exists-p emacs-openclaw-whisper-binary)))

(defun emacs-openclaw--whisper-temp-file ()
  "Generate a temporary WAV file path."
  (expand-file-name (format "openclaw-whisper-%d.wav" (random)) 
                    temporary-file-directory))

(defun emacs-openclaw--whisper-record-start (wav-file)
  "Start recording audio to WAV-FILE using ffmpeg/sox.
Returns the process or nil if recording failed."
  (condition-case err
      (let* ((recorder-cmd (if (executable-find "ffmpeg")
                               (format "ffmpeg -f avfoundation -i ':default' -acodec pcm_s16le -ar 16000 %s"
                                       (shell-quote-argument wav-file))
                             (format "sox -d -r 16000 -c 1 -b 16 %s --no-show-progress"
                                     (shell-quote-argument wav-file))))
             (proc (start-process "emacs-openclaw-record" nil "/bin/sh" "-c" recorder-cmd)))
        (message "🎙️ Recording started... (Press C-g to stop)")
        proc)
    (error
     (message "Failed to start recording: %s" (error-message-string err))
     nil)))

(defun emacs-openclaw--whisper-stop-recording ()
  "Stop the current recording process."
  (when emacs-openclaw--whisper-recording-process
    (interrupt-process emacs-openclaw--whisper-recording-process)
    (setq emacs-openclaw--whisper-recording-process nil))
  (sit-for 0.2))  ; Give ffmpeg/sox time to finalize the file

(defun emacs-openclaw--whisper-transcribe-file (wav-file)
  "Transcribe WAV-FILE using Whisper CLI.
Returns the transcribed text or nil on failure."
  (condition-case err
      (let* ((cmd-args (list emacs-openclaw-whisper-binary
                             "--model" emacs-openclaw-whisper-model
                             "--output_format" "json"
                             "--quiet"))
             (cmd-args (if emacs-openclaw-whisper-language
                           (append cmd-args (list "--language" emacs-openclaw-whisper-language))
                         cmd-args))
             (cmd-args (append cmd-args (list wav-file)))
             (output (with-temp-buffer
                       (apply #'call-process (car cmd-args) nil t nil (cdr cmd-args))
                       (buffer-string))))
        (when (and output (not (string-empty-p output)))
          (let ((json-object-type 'plist)
                (json-array-type 'list)
                (json-data (json-read-from-string output)))
            (when (listp json-data)
              (string-trim (or (plist-get json-data :text) ""))))))
    (error
     (message "Transcription failed: %s" (error-message-string err))
     nil)))

;; ============================================================================
;; Main Command
;; ============================================================================

(defun emacs-openclaw-transcribe-speech ()
  "Record audio and transcribe using Whisper CLI.

Records audio until you press C-g, then transcribes the recording
and inserts the text at point."
  (interactive)
  
  (unless (emacs-openclaw--whisper-binary-exists-p)
    (error "Whisper binary not found at %s" emacs-openclaw-whisper-binary))
  
  ;; Generate temp file
  (setq emacs-openclaw--whisper-recording-file (emacs-openclaw--whisper-temp-file))
  (setq emacs-openclaw--whisper-recording-buffer (current-buffer))
  (setq emacs-openclaw--whisper-recording-point (point-marker))
  
  ;; Start recording
  (setq emacs-openclaw--whisper-recording-process 
        (emacs-openclaw--whisper-record-start emacs-openclaw--whisper-recording-file))
  
  (if (not emacs-openclaw--whisper-recording-process)
      (message "Failed to start recording")
    
    ;; Wait for user to stop recording (C-g)
    (condition-case nil
        (progn
          (while t (sit-for 1)))
      (quit 
       ;; Stop recording
       (emacs-openclaw--whisper-stop-recording)
       
       ;; Transcribe
       (message "⏳ Transcribing audio...")
       (let* ((transcript (emacs-openclaw--whisper-transcribe-file 
                           emacs-openclaw--whisper-recording-file))
              (was-valid (and emacs-openclaw--whisper-recording-buffer
                             (buffer-live-p emacs-openclaw--whisper-recording-buffer))))
         
         (if transcript
             (when was-valid
               (with-current-buffer emacs-openclaw--whisper-recording-buffer
                 (goto-char emacs-openclaw--whisper-recording-point)
                 (insert transcript " ")))
           (message "❌ Transcription failed or returned empty"))
         
         ;; Clean up
         (when (file-exists-p emacs-openclaw--whisper-recording-file)
           (delete-file emacs-openclaw--whisper-recording-file))
         (setq emacs-openclaw--whisper-recording-file nil
               emacs-openclaw--whisper-recording-buffer nil
               emacs-openclaw--whisper-recording-point nil
               emacs-openclaw--whisper-recording-process nil))))))

;; ============================================================================
;; Mode Integration
;; ============================================================================

(defun emacs-openclaw--setup-whisper-keybindings-direct (keymap)
  "Add whisper keybindings to KEYMAP."
  (when emacs-openclaw-whisper-keybinding
    (define-key keymap 
      (kbd emacs-openclaw-whisper-keybinding) 
      'emacs-openclaw-transcribe-speech)
    (message "emacs-openclaw: Speech-to-text bound to %s" 
             emacs-openclaw-whisper-keybinding)))

;; Alias for compatibility with emacs-openclaw-mode.el
(defalias 'emacs-openclaw--setup-whisper-keybindings 
          'emacs-openclaw--setup-whisper-keybindings-direct)

;; Auto-setup when loaded
(when (and emacs-openclaw-allow-speech-to-text
           emacs-openclaw-whisper-keybinding)
  (require 'emacs-openclaw-mode nil t)
  (when (boundp 'emacs-openclaw-mode-map)
    (emacs-openclaw--setup-whisper-keybindings-direct emacs-openclaw-mode-map)))

(provide 'emacs-openclaw-whisper-direct)
;;; emacs-openclaw-whisper-direct.el ends here
