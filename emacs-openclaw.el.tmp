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

(require 'emacs-openclaw-config)
(require 'emacs-openclaw-websocket)
(require 'emacs-openclaw-server)
(require 'emacs-openclaw-mode)
(require 'emacs-openclaw-chat)

;; Public API is re-exported from submodules via require statements above.
;; No need for defalias — the submodules define the actual functions.

(provide 'emacs-openclaw)
;;; emacs-openclaw.el ends here
