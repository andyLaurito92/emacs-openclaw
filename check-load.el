#!/usr/bin/env emacs --script
;; Simple script to check if emacs-openclaw loads without errors

(add-to-list 'load-path (expand-file-name "."))

(condition-case err
    (progn
      (require 'emacs-openclaw)
      (message "✓ emacs-openclaw loaded successfully")
      
      ;; Check that all modules are loaded
      (unless (featurep 'emacs-openclaw-config)
        (error "emacs-openclaw-config not loaded"))
      (message "✓ emacs-openclaw-config loaded")
      
      (unless (featurep 'emacs-openclaw-websocket)
        (error "emacs-openclaw-websocket not loaded"))
      (message "✓ emacs-openclaw-websocket loaded")
      
      (unless (featurep 'emacs-openclaw-server)
        (error "emacs-openclaw-server not loaded"))
      (message "✓ emacs-openclaw-server loaded")
      
      (unless (featurep 'emacs-openclaw-mode)
        (error "emacs-openclaw-mode not loaded"))
      (message "✓ emacs-openclaw-mode loaded")
      
      (unless (featurep 'emacs-openclaw-chat)
        (error "emacs-openclaw-chat not loaded"))
      (message "✓ emacs-openclaw-chat loaded")
      
      ;; Check that all public functions exist
      (unless (fboundp 'emacs-openclaw-chat)
        (error "emacs-openclaw-chat function not defined"))
      (message "✓ emacs-openclaw-chat function exists")
      
      (unless (fboundp 'emacs-openclaw-mode)
        (error "emacs-openclaw-mode function not defined"))
      (message "✓ emacs-openclaw-mode function exists")
      
      (unless (fboundp 'emacs-openclaw-send-line)
        (error "emacs-openclaw-send-line function not defined"))
      (message "✓ emacs-openclaw-send-line function exists")
      
      (message "\n✅ All checks passed!")
      (kill-emacs 0))
  (error
   (message "❌ Error: %s" (error-message-string err))
   (kill-emacs 1)))
