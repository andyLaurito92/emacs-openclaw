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

;; Load submodules
(require 'emacs-openclaw-config)
(require 'emacs-openclaw-websocket)
(require 'emacs-openclaw-chat)
(require 'emacs-openclaw-server)
(require 'emacs-openclaw-mode)

;; Re-export public commands
;;;###autoload
(defalias 'emacs-openclaw-disconnect 'emacs-openclaw-disconnect)

;;;###autoload
(defalias 'emacs-openclaw-chat 'emacs-openclaw-chat)

;;;###autoload
(defalias 'emacs-openclaw-send-region-or-buffer 'emacs-openclaw-send-region-or-buffer)

;;;###autoload
(defalias 'emacs-openclaw-show-server-buffer 'emacs-openclaw-show-server-buffer)

;;;###autoload
(defalias 'emacs-openclaw-get-available-tools 'emacs-openclaw-get-available-tools)

(provide 'emacs-openclaw)
;;; emacs-openclaw.el ends here
