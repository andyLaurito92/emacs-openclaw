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

(defun emacs-openclaw--list-audio-devices ()
  "List available audio devices on macOS using ffmpeg."
  (interactive)
  (with-temp-buffer
    (call-process "ffmpeg" nil t nil "-f" "avfoundation" "-list_devices" "true" "-i" "")
    (message (buffer-string))))

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
      (let* ((has-ffmpeg (executable-find "ffmpeg"))
             (recorder-cmd (if has-ffmpeg
                               ;; AVFoundation syntax: -f avfoundation -i '<video>:<audio>'
                               ;; On macOS with multiple audio devices, use index directly.
                               ;; To find your device: ffmpeg -f avfoundation -list_devices true -i ""
                               ;; Common devices: :0 = Microsoft Teams, :1 = External Mic, :2 = MacBook Pro Mic
                               (format "ffmpeg -f avfoundation -i ':1' -c:a pcm_s16le -ar 16000 -ac 1 %s -y 2>&1"
                                       (shell-quote-argument wav-file))
                             (format "sox -d -r 16000 -c 1 -b 16 %s --no-show-progress"
                                     (shell-quote-argument wav-file))))
             (proc (start-process "emacs-openclaw-record" nil "/bin/sh" "-c" recorder-cmd)))
        (message "🎙️ Recording started... (Press C-g to stop)")
        (message "[DEBUG] ffmpeg available: %s" has-ffmpeg)
        (message "[DEBUG] recorder cmd: %s" recorder-cmd)
        (message "[DEBUG] output file: %s" wav-file)
        (message "[DEBUG] process created: %s" proc)
        proc)
    (error
     (message "Failed to start recording: %s" (error-message-string err))
     nil)))

(defun emacs-openclaw--whisper-stop-recording ()
  "Stop the current recording process."
  (message "[DEBUG] Stopping recording, process: %s" emacs-openclaw--whisper-recording-process)
  (when emacs-openclaw--whisper-recording-process
    (message "[DEBUG] Process status before interrupt: %s" 
             (process-status emacs-openclaw--whisper-recording-process))
    (interrupt-process emacs-openclaw--whisper-recording-process)
    (message "[DEBUG] Interrupted, waiting for process to finish...")
    (setq emacs-openclaw--whisper-recording-process nil))
  (message "[DEBUG] Waiting 2s for ffmpeg to finalize file...")
  (sit-for 2.0)
  (message "[DEBUG] Done waiting"))

(defun emacs-openclaw--whisper-transcribe-file (wav-file)
  "Transcribe WAV-FILE using Whisper CLI.
Returns the transcribed text or nil on failure.

Note: Whisper writes a .json file to the current directory, not stdout."
  (condition-case err
      (let* ((cmd-args (list emacs-openclaw-whisper-binary
                             "--model" emacs-openclaw-whisper-model
                             "--output_format" "json"))
             (cmd-args (if emacs-openclaw-whisper-language
                           (append cmd-args (list "--language" emacs-openclaw-whisper-language))
                         cmd-args))
             (cmd-args (append cmd-args (list wav-file)))
             (stdout-buffer (get-buffer-create " *whisper-out*"))
             (stderr-buffer (get-buffer-create " *whisper-err*"))
             ;; Whisper will create a .json file: replace .wav with .json
             (json-output-file (concat (file-name-sans-extension wav-file) ".json")))
        
        (message "[DEBUG] Whisper transcribe: binary=%s, model=%s, file=%s" 
                 emacs-openclaw-whisper-binary emacs-openclaw-whisper-model wav-file)
        (message "[DEBUG] Full cmd args: %s" cmd-args)
        (message "[DEBUG] Expected JSON output: %s" json-output-file)
        
        ;; Clear buffers
        (with-current-buffer stdout-buffer (erase-buffer))
        (with-current-buffer stderr-buffer (erase-buffer))
        
        ;; Remove any stale JSON output file
        (when (file-exists-p json-output-file)
          (delete-file json-output-file)
          (message "[DEBUG] Removed stale JSON file"))
        
        ;; Call Whisper with separate stdout/stderr
        (let ((exit-code (apply #'call-process (car cmd-args) nil 
                                (list stdout-buffer stderr-buffer) nil (cdr cmd-args))))
          (message "[DEBUG] Whisper exit code: %s" exit-code))
        
        ;; Get stderr output
        (let ((stderr (with-current-buffer stderr-buffer (buffer-string))))
          (message "[DEBUG] Whisper stderr: %s" stderr))
        
        ;; Read the JSON file that whisper created
        (message "[DEBUG] Checking for JSON file: %s" json-output-file)
        (if (not (file-exists-p json-output-file))
            (progn
              (message "[DEBUG] JSON file not found at %s" json-output-file)
              nil)
          
          ;; Read and parse the JSON file
          (let ((json-content (with-temp-buffer
                                (insert-file-contents json-output-file)
                                (buffer-string))))
            (message "[DEBUG] JSON file content length: %d" (length json-content))
            (message "[DEBUG] JSON content: %s" json-content)
            
            ;; Try to parse JSON
            (let ((json-object-type 'plist)
                  (json-array-type 'list))
              (condition-case parse-err
                  (let* ((json-data (json-read-from-string json-content))
                         (text (plist-get json-data :text)))
                    (message "[DEBUG] Parsed JSON successfully, text: %s" text)
                    (when text (string-trim text)))
                (error
                 ;; If JSON parsing fails, try extracting text field manually
                 (message "[DEBUG] JSON parse error: %s" (error-message-string parse-err))
                 (let ((text-match (string-match "\"text\":\\s *\"\\([^\"]*\\)\"" json-content)))
                   (when text-match
                     (match-string 1 json-content))))))))))
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
  
  (message "[DEBUG] Starting whisper recording workflow")
  (message "[DEBUG] Temp file: %s" emacs-openclaw--whisper-recording-file)
  
  ;; Start recording
  (setq emacs-openclaw--whisper-recording-process 
        (emacs-openclaw--whisper-record-start emacs-openclaw--whisper-recording-file))
  
  (if (not emacs-openclaw--whisper-recording-process)
      (message "Failed to start recording")
    
    ;; Wait for user to stop recording (C-g)
    (condition-case nil
        (progn
          (message "[DEBUG] Waiting for user to press C-g...")
          (while t (sit-for 1)))
      (quit 
       ;; Stop recording
       (message "[DEBUG] User pressed C-g, stopping recording...")
       (emacs-openclaw--whisper-stop-recording)
       
       ;; Check if file was created and has size
       (message "[DEBUG] Checking if file exists: %s" emacs-openclaw--whisper-recording-file)
       (if (not (file-exists-p emacs-openclaw--whisper-recording-file))
           (message "❌ Recording failed: no audio file created")
         
         (let ((file-attrs (file-attributes emacs-openclaw--whisper-recording-file))
               (file-size (file-attribute-size 
                          (file-attributes emacs-openclaw--whisper-recording-file))))
           (message "[DEBUG] File exists. Attributes: %s" file-attrs)
           (message "[DEBUG] File size: %d bytes" file-size)
           (if (< file-size 100)
               (message "❌ Recording failed: audio file too small (%d bytes)" file-size)
             
             ;; Transcribe
             (message "⏳ Transcribing audio...")
             (let* ((transcript (emacs-openclaw--whisper-transcribe-file 
                                 emacs-openclaw--whisper-recording-file))
                    (was-valid (and emacs-openclaw--whisper-recording-buffer
                                   (buffer-live-p emacs-openclaw--whisper-recording-buffer))))
               
               (message "[DEBUG] Transcript result: %s" transcript)
               (if transcript
                   (when was-valid
                     (with-current-buffer emacs-openclaw--whisper-recording-buffer
                       (goto-char emacs-openclaw--whisper-recording-point)
                       (insert transcript " ")))
                 (message "❌ Transcription failed or returned empty"))
               
               ;; Clean up
               (message "[DEBUG] Cleaning up temp file...")
               (when (file-exists-p emacs-openclaw--whisper-recording-file)
                 (delete-file emacs-openclaw--whisper-recording-file))
               (setq emacs-openclaw--whisper-recording-file nil
                     emacs-openclaw--whisper-recording-buffer nil
                     emacs-openclaw--whisper-recording-point nil
                     emacs-openclaw--whisper-recording-process nil)
               (message "[DEBUG] Cleanup complete")))))))))

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
