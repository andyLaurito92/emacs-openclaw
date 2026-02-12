(require 'ert)
(require 'emacs-openclaw)

(ert-deftest test-url-generation ()
  "Test that the base URL is constructed correctly from port."
  ;; We set the token here to "fake-token" so emacs-openclaw--ensure-config 
  ;; doesn't try to load the missing JSON file.
  (let ((emacs-openclaw-port 9999)
        (emacs-openclaw-token "fake-token"))
    (should (string-equal (emacs-openclaw--get-base-url) "http://127.0.0.1:9999"))))

(ert-deftest test-config-loading-fallback ()
  "Test that ensure-config returns default port when cache is empty."
  ;; Force the cache to be empty and provide an explicit token to skip the file check
  (setq emacs-openclaw--token-cache nil)
  (setq emacs-openclaw--port-cache nil)
  (let ((emacs-openclaw-token "fake-token"))
    (let ((config (emacs-openclaw--ensure-config)))
      (should (equal (plist-get config :port) 18789)))))

(ert-deftest test-module-loading ()
  "Test that all modules load without circular dependency errors."
  ;; If we got here, emacs-openclaw was loaded successfully
  ;; This would fail if there were circular requires
  (should (featurep 'emacs-openclaw))
  (should (featurep 'emacs-openclaw-config))
  (should (featurep 'emacs-openclaw-websocket))
  (should (featurep 'emacs-openclaw-server))
  (should (featurep 'emacs-openclaw-mode))
  (should (featurep 'emacs-openclaw-chat))
  (should (featurep 'emacs-openclaw-tts)))

(ert-deftest test-functions-exist ()
  "Test that all public functions are defined."
  (should (fboundp 'emacs-openclaw-chat))
  (should (fboundp 'emacs-openclaw-send-line))
  (should (fboundp 'emacs-openclaw-send-region-or-buffer))
  (should (fboundp 'emacs-openclaw-disconnect))
  (should (fboundp 'emacs-openclaw-mode)))

(ert-deftest test-session-key-getter ()
  "Test that session key getter returns correct values."
  (let ((emacs-openclaw-session-key nil)
        (emacs-openclaw--session-key-cache nil))
    ;; Should return default when both are nil
    (should (equal (emacs-openclaw--get-session-key) "agent:main:main")))
  
  (let ((emacs-openclaw-session-key nil)
        (emacs-openclaw--session-key-cache "cached-key"))
    ;; Should return cached key when set
    (should (equal (emacs-openclaw--get-session-key) "cached-key")))
  
  (let ((emacs-openclaw-session-key "explicit-key")
        (emacs-openclaw--session-key-cache "cached-key"))
    ;; Should prefer explicit over cached
    (should (equal (emacs-openclaw--get-session-key) "explicit-key"))))

(ert-deftest test-log-with-deleted-buffer ()
  "Test that emacs-openclaw--log handles deleted buffers gracefully."
  (let ((buf-name "*OpenClaw-Test-Buffer*"))
    ;; Temporarily override the buffer name for testing
    (let ((emacs-openclaw-buffer-name buf-name))
      ;; Create and then kill the buffer
      (with-current-buffer (get-buffer-create buf-name)
        (insert "test"))
      (kill-buffer buf-name)
      ;; This should not raise an error even though the buffer is deleted
      (should-not
       (condition-case err
           (progn
             (emacs-openclaw--log "test message" nil)
             nil)  ;; Return nil if no error
         (error err)))  ;; Return the error if one occurs
      ;; Verify buffer is still not alive
      (should-not (buffer-live-p (get-buffer buf-name))))))

(ert-deftest test-tts-module-loading ()
  "Test that TTS module loads correctly."
  (should (featurep 'emacs-openclaw-tts))
  (should (fboundp 'emacs-openclaw-tts-speak))
  (should (fboundp 'emacs-openclaw-tts-toggle))
  (should (fboundp 'emacs-openclaw-tts-speak-response))
  (should (fboundp 'emacs-openclaw-tts-list-voices)))

(ert-deftest test-tts-toggle ()
  "Test that TTS toggle works correctly."
  (let ((original-state emacs-openclaw-tts-enabled))
    ;; Test toggling from disabled to enabled
    (setq emacs-openclaw-tts-enabled nil)
    (emacs-openclaw-tts-toggle)
    (should emacs-openclaw-tts-enabled)
    
    ;; Test toggling from enabled to disabled
    (emacs-openclaw-tts-toggle)
    (should-not emacs-openclaw-tts-enabled)
    
    ;; Restore original state
    (setq emacs-openclaw-tts-enabled original-state)))

(ert-deftest test-tts-speak-empty-text ()
  "Test that TTS speak handles empty text gracefully."
  ;; Should not raise an error with empty text
  (should-not
   (condition-case err
       (progn
         (emacs-openclaw-tts-speak "")
         nil)
     (error err)))
  
  ;; Should not raise an error with nil
  (should-not
   (condition-case err
       (progn
         (emacs-openclaw-tts-speak nil)
         nil)
     (error err))))

