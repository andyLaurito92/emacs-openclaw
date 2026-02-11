;;; emacs-openclaw-whisper-direct.el --- Direct Whisper CLI integration -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.1

;;; Commentary:
;; Direct integration with OpenAI Whisper CLI (no whisper.el dependency).
;; Records audio via sox/ffmpeg and transcribes using the Whisper binary directly.

;;; Code:

(require 'json)
(require 'subr-x) ; For string-trim
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
  "Whisper model to use (tiny, base, small, medium, large)."
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-whisper-language nil
  "Language code for Whisper (e.g., 'en', 'es'). nil = auto-detect."
  :type '(choice (const nil) string)
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-audio-device ":2"
  "The ffmpeg audio device. On macOS, run: ffmpeg -f avfoundation -list_devices true -i \"\" 2>&1 | grep audio"
  :type 'string
  :group 'emacs-openclaw)

;; ============================================================================
;; State Variables
;; ============================================================================

(defvar emacs-openclaw--whisper-recording-process nil)
(defvar emacs-openclaw--whisper-recording-file nil)
(defvar emacs-openclaw--whisper-recording-buffer nil)
(defvar emacs-openclaw--whisper-recording-point nil)

;; ============================================================================
;; Helpers
;; ============================================================================

(defun emacs-openclaw--list-audio-devices ()
  "List available audio devices on macOS using ffmpeg."
  (interactive)
  (with-temp-buffer
    (call-process "ffmpeg" nil t nil "-f" "avfoundation" "-list_devices" "true" "-i" "")
    (message (buffer-string))))

(defun emacs-openclaw--whisper-binary-exists-p ()
  "Check if the Whisper binary exists and is executable."
  (and (file-exists-p emacs-openclaw-whisper-binary)
       (file-executable-p emacs-openclaw-whisper-binary)))

(defun emacs-openclaw--whisper-temp-file ()
  "Generate a temporary WAV file path."
  (make-temp-file "openclaw-whisper-" nil ".wav"))

(defun emacs-openclaw--whisper-record-start (wav-file)
  "Start recording audio to WAV-FILE using ffmpeg or sox."
  (let* ((has-ffmpeg (executable-find "ffmpeg"))
         (recorder-cmd 
          (if has-ffmpeg
              (format "ffmpeg -f avfoundation -i '%s' -c:a pcm_s16le -ar 16000 -ac 1 %s -y"
                      emacs-openclaw-audio-device
                      (shell-quote-argument wav-file))
            (format "sox -d -r 16000 -c 1 -b 16 %s --no-show-progress"
                    (shell-quote-argument wav-file)))))
    (let ((proc (start-process-shell-command "emacs-openclaw-record" nil recorder-cmd)))
      (set-process-query-on-exit-flag proc nil)
      proc)))

(defun emacs-openclaw--whisper-stop-recording (proc)
  "Stop the recording process safely by sending 'q' to ffmpeg."
  (when (and proc (process-live-p proc))
    ;; Send 'q' + newline to ffmpeg to gracefully stop and finalize the file
    (process-send-string proc "q\n")
    (accept-process-output proc 2 nil t)
    (when (process-live-p proc)
      (interrupt-process proc)
      (accept-process-output proc 1 nil t))
    (when (process-live-p proc)
      (delete-process proc))))

(defun emacs-openclaw--whisper-transcribe-file (wav-file)
  "Transcribe WAV-FILE using Whisper CLI."
  (let* ((out-dir (file-name-directory wav-file))
         (json-output-file (concat (file-name-sans-extension wav-file) ".json"))
         (cmd-args (list "--model" emacs-openclaw-whisper-model
                         "--output_format" "json"
                         "--output_dir" out-dir)))
    
    (when emacs-openclaw-whisper-language
      (setq cmd-args (append cmd-args (list "--language" emacs-openclaw-whisper-language))))
    
    (setq cmd-args (append cmd-args (list wav-file)))
    
    (message "⏳ Whisper is processing...")
    (with-temp-buffer
      (let ((exit-code (apply #'call-process emacs-openclaw-whisper-binary nil t nil cmd-args)))
        (if (not (zerop exit-code))
            (progn (message "Whisper Error (Exit %d): %s" exit-code (buffer-string)) nil)
          (if (not (file-exists-p json-output-file))
              (progn (message "Whisper failed to create JSON output.") nil)
            (with-temp-buffer
              (insert-file-contents json-output-file)
              (let* ((json-data (json-read-from-string (buffer-string)))
                     (text (plist-get json-data :text)))
                (delete-file json-output-file)
                (when text (string-trim text))))))))))

;; ============================================================================
;; Main Command
;; ============================================================================

;;;###autoload
(defun emacs-openclaw-transcribe-speech ()
  "Record audio and transcribe using Whisper CLI."
  (interactive)
  (unless (emacs-openclaw--whisper-binary-exists-p)
    (error "Whisper binary not found at %s" emacs-openclaw-whisper-binary))

  (let* ((wav-file (emacs-openclaw--whisper-temp-file))
         (buffer (current-buffer))
         (point-mkr (point-marker))
         (proc (emacs-openclaw--whisper-record-start wav-file)))

    (if (not (process-live-p proc))
        (message "❌ Failed to start recording process")
      
      ;; UI Block: Wait for user input to stop
      (unwind-protect
          (when (y-or-n-p "🎙️ Recording... Click 'y' or 'n' to stop and transcribe.")
            (emacs-openclaw--whisper-stop-recording proc)
            
            (if (or (not (file-exists-p wav-file))
                    (< (file-attribute-size (file-attributes wav-file)) 100))
                (message "❌ Recording failed: Audio file empty or too small.")
              
              (let ((transcript (emacs-openclaw--whisper-transcribe-file wav-file)))
                (if (and transcript (> (length transcript) 0))
                    (with-current-buffer buffer
                      (save-excursion
                        (goto-char point-mkr)
                        (insert transcript " "))
                      (message "✅ Transcription complete."))
                  (message "❌ Transcription failed.")))))
        
        ;; Ensure cleanup happens even if user aborts
        (emacs-openclaw--whisper-stop-recording proc)
        (when (file-exists-p wav-file) (delete-file wav-file))
        (set-marker point-mkr nil)))))

;; ============================================================================
;; Mode Integration
;; ============================================================================

(defun emacs-openclaw--setup-whisper-keybindings-direct (keymap)
  "Add whisper keybindings to KEYMAP."
  (when (boundp 'emacs-openclaw-whisper-keybinding)
    (define-key keymap 
      (kbd emacs-openclaw-whisper-keybinding) 
      'emacs-openclaw-transcribe-speech)))

(defalias 'emacs-openclaw--setup-whisper-keybindings 
          'emacs-openclaw--setup-whisper-keybindings-direct)

(provide 'emacs-openclaw-whisper-direct)
;;; emacs-openclaw-whisper-direct.el ends here
