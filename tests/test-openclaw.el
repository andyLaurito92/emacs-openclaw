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
