;;; emacs-openclaw-whisper-direct.el --- Direct Whisper CLI integration -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.2.0

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
  "Language code for Whisper (e.g., 'en', 'es'). nil = auto-detect."
  :type '(choice (const nil) string)
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
  "Start recording audio via sox using the default system device."
  (let* ((sox-bin (executable-find "sox"))
         (recorder-cmd 
          (if sox-bin
              (format "sox -d -r 16000 -c 1 -b 16 %s --no-show-progress"
                      (shell-quote-argument wav-file))
            (error "Sox not found. Run 'brew install sox'"))))
    (message "[WHISPER] Recording started (using System Default Input)...")
    ;; Output redirected to a debug buffer so we can monitor for silence/errors
    (let ((proc (start-process-shell-command "emacs-openclaw-record" "*openclaw-sox*" recorder-cmd)))
      (set-process-query-on-exit-flag proc nil)
      proc)))

(defun emacs-openclaw--whisper-stop-recording (proc)
  "Stop the sox process gracefully."
  (when (and proc (process-live-p proc))
    (message "[WHISPER] Stopping recording...")
    (interrupt-process proc)
    (let ((timeout 0))
      (while (and (process-live-p proc) (< timeout 20))
        (accept-process-output proc 0.1)
        (setq timeout (1+ timeout))))
    (sleep-for 0.5)))

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
              (message "[WHISPER DEBUG] Whisper Failed. Stderr: %s" (buffer-string))
              nil)
          (let* ((json-object-type 'plist)
                 (raw-content (with-temp-buffer 
                                (insert-file-contents json-file) 
                                (buffer-string)))
                 (json-data (json-read-from-string raw-content))
                 (text (plist-get json-data :text)))

            (message "[WHISPER DEBUG] RAW JSON CONTENT: %s" raw-content)
            
            ;; Fallback for hallucinations/empty text
            (when (or (not text) (string-match-p "^\\s-*You\\s-*$" text))
              (message "[WHISPER DEBUG] Primary text field was '%s', checking segments..." text)
              (let ((segments (plist-get json-data :segments)))
                (setq text (mapconcat (lambda (s) (plist-get s :text)) segments " "))))
            
            (when (file-exists-p json-file) (delete-file json-file))
            
            (if (and text (> (length (string-trim text)) 0))
                (string-trim text)
              (progn
                (message "[WHISPER DEBUG] Failed to extract text. Check *openclaw-sox* for audio issues.")
                nil))))))))

;; ============================================================================
;; Main Command
;; ============================================================================

;;;###autoload
(defun emacs-openclaw-transcribe-speech ()
  "Record and transcribe speech at point using Sox and Whisper CLI."
  (interactive)
  (unless (emacs-openclaw--whisper-binary-exists-p)
    (error "Whisper binary not found at %s" emacs-openclaw-whisper-binary))

  (let* ((wav-file (emacs-openclaw--whisper-temp-file))
         (buffer (current-buffer))
         (point-mkr (point-marker))
         (proc (emacs-openclaw--whisper-record-start wav-file)))

    (unwind-protect
        (when (y-or-n-p "🎙️ Recording... Stop and transcribe?")
          (emacs-openclaw--whisper-stop-recording proc)
          
          ;; Check if file exists and has reasonable size (Sox files are usually > 40k for a few seconds)
          (if (not (and (file-exists-p wav-file) 
                        (> (file-attribute-size (file-attributes wav-file)) 2000)))
              (message "❌ Recording failed: Audio file empty. Ensure Microphone permissions are enabled for Emacs.")
            
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
;;; emacs-openclaw-whisper-direct.el ends here
