;;; emacs-openclaw.el --- OpenClaw chat integration for Emacs -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (request "0.3.0") (websocket "1.13"))
;; Keywords: tools, openclaw, chat, ai
;; URL: https://github.com/andyLaurito92/emacs-openclaw

;;; Commentary:

;; emacs-openclaw provides an interactive chat interface for OpenClaw
;; directly within Emacs. It uses WebSocket protocol for real-time
;; streaming chat responses. Configuration is automatically detected from
;; ~/.openclaw/openclaw.json (gateway token and port).

;;; Code:

;; Load submodules in dependency order
(message "emacs-openclaw: Loading config...")
(require 'emacs-openclaw-config)
(message "emacs-openclaw: Loading websocket...")
(require 'emacs-openclaw-websocket)
(message "emacs-openclaw: Loading server...")
(require 'emacs-openclaw-server)
(message "emacs-openclaw: Loading mode...")
(condition-case err
    (require 'emacs-openclaw-mode)
  (error
   (message "emacs-openclaw: ERROR loading mode module: %s" (error-message-string err))
   (signal (car err) (cdr err))))
(message "emacs-openclaw: Mode loaded, checking if emacs-openclaw-mode exists: %s" (fboundp 'emacs-openclaw-mode))
(message "emacs-openclaw: Loading chat...")
(require 'emacs-openclaw-chat)
(message "emacs-openclaw: All modules loaded!")

;; Public API is re-exported from submodules via require statements above.
;; No need for defalias — the submodules define the actual functions.

(provide 'emacs-openclaw)
;;; emacs-openclaw.el ends here
