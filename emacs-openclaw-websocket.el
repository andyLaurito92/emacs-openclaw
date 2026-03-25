;;; emacs-openclaw-websocket.el -*- lexical-binding: t; -*-

(require 'json)
(require 'websocket)
(require 'cl-lib)
(require 'emacs-openclaw-config)
(require 'emacs-openclaw-tts)

(defvar emacs-openclaw--websocket nil)
(defvar emacs-openclaw--websocket-connected nil)
(defvar emacs-openclaw--request-id-counter 0)
(defvar emacs-openclaw--pending-requests (make-hash-table :test 'equal))
(defvar emacs-openclaw--current-message-buffer "")
(defvar emacs-openclaw--session-key nil)

(defvar emacs-openclaw--connect-nonce nil)

(defun emacs-openclaw--ensure-session-key ()
  (unless emacs-openclaw--session-key
    (setq emacs-openclaw--session-key
          (format "emacs:%s:%d" (system-name) (emacs-pid)))
    (message "emacs-openclaw: Using session %s" emacs-openclaw--session-key)))

(defun emacs-openclaw--generate-request-id ()
  (setq emacs-openclaw--request-id-counter (1+ emacs-openclaw--request-id-counter))
  (format "emacs-req-%d" emacs-openclaw--request-id-counter))

;; ============================================================================
;; Agent Event Handling
;; ============================================================================

(defun emacs-openclaw--handle-agent-event (msg)
  (ignore-errors
    (let* ((payload (alist-get 'payload msg))
           (session-key (alist-get 'sessionKey payload)))

      ;; Ignore other sessions
      (when (and session-key
                 (not (equal session-key emacs-openclaw--session-key)))
        (cl-return-from emacs-openclaw--handle-agent-event))

      (let ((stream (alist-get 'stream payload))
            (data (alist-get 'data payload)))
        (cond
         ((string= stream "assistant")
          (when-let ((delta (alist-get 'delta data)))
            (setq emacs-openclaw--current-message-buffer
                  (concat emacs-openclaw--current-message-buffer delta))
            (emacs-openclaw--log delta nil)))

         ((and (string= stream "lifecycle")
               (string= (alist-get 'phase data) "end"))
          (emacs-openclaw--log "\n" nil)
          (emacs-openclaw--log (concat emacs-openclaw-message-separator "\n") 'shadow)
          (emacs-openclaw--log "\n" nil)
          ;; Speak the complete response if TTS is enabled
          (when (> (length emacs-openclaw--current-message-buffer) 0)
            (emacs-openclaw-tts-speak-response emacs-openclaw--current-message-buffer))
          ;; Clear buffer for next response
          (setq emacs-openclaw--current-message-buffer ""))

         (t
          ;; Unknown stream type — log to server buffer for debugging
          (let ((server-buf (get-buffer-create "*OpenClaw-Server*")))
            (with-current-buffer server-buf
              (goto-char (point-max))
              (insert (format "[emacs-openclaw debug] Unknown stream type: %S data: %S\n"
                              stream data))))))))))
;; ----------------------------------------------------------------------------
;; Message handling
;; ----------------------------------------------------------------------------

(defun emacs-openclaw--websocket-on-message (_ws frame)
  (let* ((json-object-type 'alist)
         (json-array-type 'list)
         (msg (json-read-from-string (websocket-frame-text frame)))
         (type (alist-get 'type msg)))
    (pcase type
      ("event"
       (pcase (alist-get 'event msg)
         ("connect.challenge"
          (setq emacs-openclaw--connect-nonce
                (alist-get 'nonce (alist-get 'payload msg)))
          (emacs-openclaw--send-connect))
         ("agent"
          (emacs-openclaw--handle-agent-event msg))))
      ("res"
       (setq emacs-openclaw--websocket-connected t)
       (when-let ((cb (gethash (alist-get 'id msg)
                               emacs-openclaw--pending-requests)))
         (funcall cb msg)
         (remhash (alist-get 'id msg)
                  emacs-openclaw--pending-requests))))))

;; ----------------------------------------------------------------------------
;; Handshake
;; ----------------------------------------------------------------------------

(defun emacs-openclaw--send-connect ()
  "Send WebSocket connect frame to OpenClaw."
  (let ((token (emacs-openclaw--get-token))
        (req-id (emacs-openclaw--generate-request-id)))
    (websocket-send-text
     emacs-openclaw--websocket
     (json-encode
      `((type . "req")
        (id . ,req-id)
        (method . "connect")
        (params . (
                   (minProtocol . 3)
                   (maxProtocol . 3)
                   (client . (
                              (id . "cli")             ;; must be valid client id
                              (displayName . "Emacs OpenClaw")
                              (version . "0.1.0")
                              (platform . "emacs")
                              (mode . "cli")           ;; must match schema
                              ))
                   (role . "operator")
                   (scopes . ["operator.admin"])
                   (caps . [])
                   (commands . [])
                   (auth . ((token . ,token)))
                   (locale . "en-US")
                   (userAgent . "emacs-openclaw/0.1.0")
                   )))))))

(defun emacs-openclaw--websocket-on-open (_ws)
  (message "emacs-openclaw: WebSocket opened, waiting for challenge…"))

(defun emacs-openclaw--websocket-on-close (_ws)
  (setq emacs-openclaw--websocket nil
        emacs-openclaw--websocket-connected nil
        emacs-openclaw--connect-nonce nil)
  (message "emacs-openclaw: WebSocket closed"))

(defun emacs-openclaw--connect-websocket ()
  (let* ((config (emacs-openclaw--ensure-config))
         (port (plist-get config :port)))
    (setq emacs-openclaw--websocket
          (websocket-open
           (format "ws://127.0.0.1:%d" port)
           :on-open #'emacs-openclaw--websocket-on-open
           :on-message #'emacs-openclaw--websocket-on-message
           :on-close #'emacs-openclaw--websocket-on-close))))

(defun emacs-openclaw--ensure-websocket ()
  (unless (and emacs-openclaw--websocket emacs-openclaw--websocket-connected)
    (emacs-openclaw--connect-websocket)
    (accept-process-output nil 1)
    (unless emacs-openclaw--websocket-connected
      (error "OpenClaw handshake did not complete"))))

;; ----------------------------------------------------------------------------
;; Chat
;; ----------------------------------------------------------------------------

(defun emacs-openclaw--websocket-send-chat (prompt callback)
  (emacs-openclaw--ensure-websocket)
  (emacs-openclaw--ensure-session-key)
  (let ((id (emacs-openclaw--generate-request-id)))
    (puthash id callback emacs-openclaw--pending-requests)
    (websocket-send-text
     emacs-openclaw--websocket
     (json-encode
      `((type . "req")
        (id . ,id)
        (method . "agent")
        (params . ((sessionKey . ,emacs-openclaw--session-key)
                   (message . ,prompt)
                   (idempotencyKey . ,id))))))))

;; ----------------------------------------------------------------------------
;; Disconnect
;; ----------------------------------------------------------------------------

;;;###autoload
(defun emacs-openclaw-disconnect ()
  "Disconnect the WebSocket connection to OpenClaw."
  (interactive)
  (when emacs-openclaw--websocket
    (websocket-close emacs-openclaw--websocket)
    (setq emacs-openclaw--websocket nil)
    (message "emacs-openclaw: Disconnected")))

(provide 'emacs-openclaw-websocket)
