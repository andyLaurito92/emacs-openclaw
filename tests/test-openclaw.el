(require 'ert)
(require 'emacs-openclaw)

(ert-deftest test-url-generation ()
  "Test that the base URL is constructed correctly from port."
  (let ((emacs-openclaw-port 9999))
    (should (string-equal (emacs-openclaw--get-base-url) "http://127.0.0.1:9999"))))

(ert-deftest test-config-loading-fallback ()
  "Test that ensure-config returns default port when cache is empty."
  (setq emacs-openclaw--port-cache nil)
  (let ((config (emacs-openclaw--ensure-config)))
    (should (equal (plist-get config :port) 18789))))
