;;; emacs-openclaw-websocket.el --- WebSocket connection and protocol handling -*- lexical-binding: t; -*-

(require 'json)
(require 'websocket)
(require 'emacs-openclaw-config)

;; ============================================================================
;; Internal Variables
;; ============================================================================

(defvar emacs-openclaw--websocket nil)
(defvar emacs-openclaw--websocket-connected nil)
(defvar emacs-openclaw--request-id-counter 0)

(defvar emacs-openclaw--pending-requests (make-hash-table :test 'equal))
(defvar emacs-openclaw--current-message-buffer "")

;; 🔒 Session isolation
(defvar emacs-openclaw--session-key nil
  "Session key used by this Emacs instance.")

(defun emacs-openclaw--ensure-session-key ()
  (unless emacs-openclaw--session-key
    (setq emacs-openclaw--session-key
          (format "emacs:%s:%d"
                  (system-name)
                  (emacs-pid)))
    (message "emacs-openclaw: Using session %s" emacs-openclaw--session-key)))

;; ============================================================================
;; Request ID
;; ============================================================================

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

      ;; 🔴 Ignore events from other sessions
      (when (and session-key
                 (not (equal session-key emacs-openclaw--session-key)))
        (cl-return-from emacs-openclaw--handle-agent-event))

      (let* ((stream (alist-get 'stream payload))
             (data (alist-get 'data payload))
             (run-id (alist-get 'runId payload)))

        (when (string= stream "assistant")
          (let ((delta (alist-get 'delta data)))
            (when delta
              (setq emacs-openclaw--current-message-buffer
                    (concat emacs-openclaw--current-message-buffer delta))
              (emacs-openclaw--log delta nil))))

        (when (and (string= stream "lifecycle")
                   (string= (alist-get 'phase data) "end"))
          (emacs-openclaw--log "\n" nil)
          (emacs-openclaw--log (concat emacs-openclaw-message-separator "\n") 'shadow)
          (emacs-openclaw--log "\n" nil))))))

;; ============================================================================
;; WebSocket Message Handler
;; ============================================================================

(defun emacs-openclaw--websocket-on-message (_ws frame)
  (ignore-errors
    (let ((msg-text (websocket-frame-text frame)))
      (when (and msg-text (not (string-empty-p (string-trim msg-text))))
        (let ((json-object-type 'alist)
              (json-array-type 'list))
          (let* ((msg (json-read-from-string msg-text))
                 (type (alist-get 'type msg))
                 (id (alist-get 'id msg)))
            (cond
             ((and (string= type "res") id)
              (when-let ((handler (gethash id emacs-openclaw--pending-requests)))
                (funcall handler msg)
                (remhash id emacs-openclaw--pending-requests))
              (setq emacs-openclaw--websocket-connected t))

             ((string= type "event")
              (when (string= (alist-get 'event msg) "agent")
                (emacs-openclaw--handle-agent-event msg))))))))))

;; ============================================================================
;; WebSocket Lifecycle
;; ============================================================================

(defun emacs-openclaw--websocket-on-open (ws)
  "Handle websocket connection open event."
  (message "emacs-openclaw: WebSocket connection opened, sending handshake...")
  (let* ((token (emacs-openclaw--get-token))
         (connect-msg
          (json-encode
           `((type . "req")
             (id . ,(emacs-openclaw--generate-request-id))
             (method . "connect")
             (params . ((minProtocol . 3)
                        (maxProtocol . 3)
                        (client . ((id . "cli")
                                   (displayName . "Emacs OpenClaw")
                                   (version . "0.1.0")
                                   (platform . "emacs")
                                   (mode . "cli")))
                        (role . "operator")
                        (scopes . ["operator.admin"])
                        (caps . [])
                        (commands . [])
                        (auth . ((token . ,token)))
                        (locale . "en-US")
                        (userAgent . "emacs-openclaw/0.1.0")))))))
    (websocket-send-text ws connect-msg)))

(defun emacs-openclaw--websocket-on-close (_ws)
  (setq emacs-openclaw--websocket-connected nil
        emacs-openclaw--websocket nil)
  (message "emacs-openclaw: WebSocket closed"))

(defun emacs-openclaw--connect-websocket ()
  (let* ((config (emacs-openclaw--ensure-config))
         (port (plist-get config :port))
         (url (format "ws://127.0.0.1:%d" port)))
    (setq emacs-openclaw--websocket
          (websocket-open
           url
           :on-open #'emacs-openclaw--websocket-on-open
           :on-message #'emacs-openclaw--websocket-on-message
           :on-close #'emacs-openclaw--websocket-on-close))))

(defun emacs-openclaw--ensure-websocket ()
  (unless (and emacs-openclaw--websocket emacs-openclaw--websocket-connected)
    (emacs-openclaw--connect-websocket)
    (accept-process-output nil 0.5)))

;; ============================================================================
;; Chat Sending
;; ============================================================================

(defun emacs-openclaw--websocket-send-chat (prompt callback)
  (emacs-openclaw--ensure-websocket)
  (emacs-openclaw--ensure-session-key)

  (let* ((req-id (emacs-openclaw--generate-request-id))
         (msg (json-encode
               `((type . "req")
                 (id . ,req-id)
                 (method . "agent")
                 (params . ((sessionKey . ,emacs-openclaw--session-key)
                            (message . ,prompt)
                            (idempotencyKey . ,req-id)))))))
    (puthash req-id callback emacs-openclaw--pending-requests)
    (setq emacs-openclaw--current-message-buffer "")
    (websocket-send-text emacs-openclaw--websocket msg)))

(declare-function emacs-openclaw--log "emacs-openclaw-chat")

(provide 'emacs-openclaw-websocket)
