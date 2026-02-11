;;; emacs-openclaw-whisper-direct.el --- Direct Whisper CLI integration -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.2

(require 'json)
(require 'subr-x)
(require 'emacs-openclaw-config)

;; ============================================================================
;; Configuration
;; ============================================================================

(defgroup emacs-openclaw nil
  "OpenClaw Whisper integration."
  :group 'external)

(defcustom emacs-openclaw-whisper-binary "/opt/homebrew/bin/whisper"
  "Path to the OpenAI Whisper CLI binary."
  :type 'file
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-whisper-model "base"
  "Whisper model to use."
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-whisper-language nil
  "Language code for Whisper (e.g., 'en'). nil = auto-detect."
  :type '(choice (const nil) string)
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-audio-device ":2"
  "The ffmpeg audio device index."
  :type 'string
  :group 'emacs-openclaw)

;; ============================================================================
;; Helpers
;; ============================================================================

(defun emacs-openclaw--whisper-binary-exists-p ()
  (and (file-exists-p emacs-openclaw-whisper-binary)
       (file-executable-p emacs-openclaw-whisper-binary)))

(defun emacs-openclaw--whisper-temp-file ()
  (make-temp-file "openclaw-whisper-" nil ".wav"))

(defun emacs-openclaw--whisper-record-start (wav-file)
  "Start recording audio. Uses -nostats to keep pipe clean."
  (let* ((recorder-cmd 
          (format "ffmpeg -hide_banner -nostats -f avfoundation -i '%s' -c:a pcm_s16le -ar 16000 -ac 1 %s -y"
                  emacs-openclaw-audio-device
                  (shell-quote-argument wav-file))))
    (let ((proc (start-process-shell-command "emacs-openclaw-record" nil recorder-cmd)))
      (set-process-query-on-exit-flag proc nil)
      proc)))

(defun emacs-openclaw--whisper-stop-recording (proc)
  "Stop recording with a slightly longer grace period for FFmpeg."
  (when (and proc (process-live-p proc))
    (process-send-string proc "q\n")
    ;; Wait up to 2 seconds for ffmpeg to flush the WAV header
    (let ((timeout 0))
      (while (and (process-live-p proc) (< timeout 20))
        (accept-process-output proc 0.1)
        (setq timeout (1+ timeout))))
    (when (process-live-p proc)
      (interrupt-process proc)
      (accept-process-output proc 0.5))
    (when (process-live-p proc)
      (delete-process proc))))

(defun emacs-openclaw--whisper-transcribe-file (wav-file)
  "Transcribe WAV-FILE and handle various JSON structures."
  (let* ((out-dir (file-name-directory wav-file))
         (json-file (concat (file-name-sans-extension wav-file) ".json"))
         (cmd-args (list "--model" emacs-openclaw-whisper-model
                         "--output_format" "json"
                         "--output_dir" out-dir
                         wav-file)))
    
    (when emacs-openclaw-whisper-language
      (setq cmd-args (append (list "--language" emacs-openclaw-whisper-language) cmd-args)))
    
    (message "⏳ Whisper is transcribing...")
    (with-temp-buffer
      (let ((exit-code (apply #'call-process emacs-openclaw-whisper-binary nil t nil cmd-args)))
        (if (or (not (zerop exit-code)) (not (file-exists-p json-file)))
            (progn
              (message "[DEBUG] Whisper Failed. Stderr: %s" (buffer-string))
              nil)
          (let* ((json-object-type 'plist)
                 (json-data (json-read-file json-file))
                 (text (plist-get json-data :text)))
            ;; Fallback: If :text is empty, concatenate segments
            (unless (and text (> (length (string-trim text)) 0))
              (let ((segments (plist-get json-data :segments)))
                (setq text (mapconcat (lambda (s) (plist-get s :text)) segments " "))))
            
            (when (file-exists-p json-file) (delete-file json-file))
            (when text (string-trim text))))))))

;; ============================================================================
;; Main Command
;; ============================================================================

(defun emacs-openclaw-transcribe-speech ()
  "Record and transcribe speech at point."
  (interactive)
  (unless (emacs-openclaw--whisper-binary-exists-p)
    (error "Whisper binary not found"))

  (let* ((wav-file (emacs-openclaw--whisper-temp-file))
         (buffer (current-buffer))
         (point-mkr (point-marker))
         (proc (emacs-openclaw--whisper-record-start wav-file)))

    (unwind-protect
        (when (y-or-n-p "🎙️ Recording... Stop and transcribe?")
          (emacs-openclaw--whisper-stop-recording proc)
          
          (if (not (and (file-exists-p wav-file) 
                        (> (file-attribute-size (file-attributes wav-file)) 1000)))
              (message "❌ Recording failed: Audio file too small.")
            
            (let ((transcript (emacs-openclaw--whisper-transcribe-file wav-file)))
              (if (and transcript (> (length transcript) 0))
                  (with-current-buffer buffer
                    (save-excursion
                      (goto-char point-mkr)
                      (insert transcript " "))
                    (message "✅ Done."))
                (message "❌ Transcription returned no text.")))))
      
      (when (process-live-p proc) (emacs-openclaw--whisper-stop-recording proc))
      (when (file-exists-p wav-file) (delete-file wav-file))
      (set-marker point-mkr nil))))

(provide 'emacs-openclaw-whisper-direct)
