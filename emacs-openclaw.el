;;; emacs-openclaw.el --- OpenClaw chat integration for Emacs -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.2.0
;; Package-Requires: ((emacs "27.1") (request "0.3.0") (websocket "1.13"))
;; Keywords: tools, openclaw, chat, ai
;; URL: https://github.com/andyLaurito92/emacs-openclaw

;;; Commentary:

;; emacs-openclaw provides an interactive chat interface for OpenClaw
;; directly within Emacs. It uses WebSocket protocol for real-time
;; streaming chat responses. Configuration is automatically detected from
;; ~/.openclaw/openclaw.json (gateway token and port).
;;
;; Optional features:
;; - Speech-to-text support via whisper.el (disabled by default)
;;   Set `emacs-openclaw-allow-speech-to-text' to t to enable.
;; - Text-to-speech support via macOS `say` command (disabled by default)
;;   Set `emacs-openclaw-tts-enabled' to t or use M-x emacs-openclaw-tts-toggle
;;   to enable audio playback of responses.

(require 'emacs-openclaw-config)
(require 'emacs-openclaw-websocket)
(require 'emacs-openclaw-server)
(require 'emacs-openclaw-mode)
(require 'emacs-openclaw-chat)
(require 'emacs-openclaw-buffers)

;; Conditionally load whisper integration (only if user enables it)
;; Uses direct Whisper CLI integration (no whisper.el dependency)
(eval-after-load 'emacs-openclaw-mode
  '(when (and (boundp 'emacs-openclaw-allow-speech-to-text)
              emacs-openclaw-allow-speech-to-text)
     (require 'emacs-openclaw-whisper-direct nil t)))

;; Public API is re-exported from submodules via require statements above.
;; No need for defalias — the submodules define the actual functions.

(provide 'emacs-openclaw)
;;; emacs-openclaw.el ends here
