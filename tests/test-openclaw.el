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
  (should (featurep 'emacs-openclaw-chat)))

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
