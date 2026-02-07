;;; emacs-openclaw-websocket.el --- WebSocket connection and protocol handling -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0

;;; Commentary:
;; Manages WebSocket connection to OpenClaw gateway, message parsing,
;; and event routing.

;;; Code:

(require 'json)
(require 'websocket)
(require 'emacs-openclaw-config)

;; ============================================================================
;; Internal Variables
;; ============================================================================

(defvar emacs-openclaw--websocket nil
  "The websocket connection to OpenClaw gateway.")

(defvar emacs-openclaw--websocket-connected nil
  "Whether the websocket is currently connected.")

(defvar emacs-openclaw--request-id-counter 0
  "Counter for generating unique request IDs.")

(defvar emacs-openclaw--pending-requests (make-hash-table :test 'equal)
  "Hash table mapping request IDs to response handlers.")

(defvar emacs-openclaw--current-message-buffer ""
  "Buffer for accumulating streaming message content.")

;; ============================================================================
;; Request ID Generation
;; ============================================================================

(defun emacs-openclaw--generate-request-id ()
  "Generate a unique request ID."
  (setq emacs-openclaw--request-id-counter (1+ emacs-openclaw--request-id-counter))
  (format "emacs-req-%d" emacs-openclaw--request-id-counter))

;; ============================================================================
;; Event Handlers
;; ============================================================================

(defun emacs-openclaw--handle-agent-event (msg)
  "Handle an agent streaming event from OpenClaw."
  (ignore-errors
    (let* ((payload (alist-get 'payload msg))
           (stream (alist-get 'stream payload))
           (data (alist-get 'data payload))
           (state (alist-get 'state payload)))
      (message "emacs-openclaw: Agent event stream=%s data=%s state=%s" stream (when data (type-of data)) state)
      ;; Handle assistant response stream
      (when (and (string= stream "assistant") data)
        (let* ((text (alist-get 'text data))
               (delta (alist-get 'delta data)))
          (message "emacs-openclaw: Agent stream text=%s delta=%s" text delta)
          ;; Use delta if available (incremental), otherwise use full text
          (let ((content (or delta text)))
            (when content
              (message "emacs-openclaw: Logging content: %s" content)
              (setq emacs-openclaw--current-message-buffer 
                    (concat emacs-openclaw--current-message-buffer content))
              (emacs-openclaw--log content nil)))))
      ;; Add separator when response stream completes
      (when (string= state "end")
        (emacs-openclaw--log "\n" nil)
        (emacs-openclaw--log (concat emacs-openclaw-message-separator "\n") 'shadow)))))

(defun emacs-openclaw--handle-chat-event (msg)
  "Handle a chat streaming event from OpenClaw."
  (let* ((payload (alist-get 'payload msg))
         (state (alist-get 'state payload))
         (message-obj (alist-get 'message payload)))
    (message "emacs-openclaw: Chat event state=%s" state)
    ;; Extract text from the message object
    (when message-obj
      (let* ((content (alist-get 'content message-obj))
             (first-content (when (listp content) (car content)))
             (text (when first-content (alist-get 'text first-content))))
        (when text
          (setq emacs-openclaw--current-message-buffer 
                (concat emacs-openclaw--current-message-buffer text))
          (emacs-openclaw--log text nil))))))

;; ============================================================================
;; WebSocket Message Handler
;; ============================================================================

(defun emacs-openclaw--websocket-on-message (ws frame)
  "Handle incoming websocket messages."
  (ignore-errors
    (let ((msg-text (websocket-frame-text frame)))
      (when msg-text
        (unless (string-empty-p (string-trim msg-text))
          (let ((preview (substring msg-text 0 (min 80 (length msg-text)))))
            (message "emacs-openclaw: Processing frame (%d bytes): %s..." (length msg-text) preview))
          
          (let ((msg nil)
                (parse-err nil))
            (condition-case err
                (let ((json-object-type 'alist)
                      (json-array-type 'list))
                  (setq msg (json-read-from-string msg-text)))
              (error
               (setq parse-err err)))
            
            (if parse-err
                (message "emacs-openclaw: Failed to parse JSON: %s. Text: %s" 
                         parse-err
                         (substring msg-text 0 (min 100 (length msg-text))))
              
              (let ((msg-type (alist-get 'type msg))
                    (msg-id (alist-get 'id msg)))
                
                (message "emacs-openclaw: Parsed message type=%s id=%s" msg-type msg-id)
                
                (cond
                 ((and (string= msg-type "res") msg-id)
                  (message "emacs-openclaw: Got response to request %s" msg-id)
                  (let ((ok (alist-get 'ok msg)))
                    (if ok
                        (progn
                          ;; Extract and cache the session key from hello-ok response
                          (let* ((payload (alist-get 'payload msg))
                                 (snapshot (alist-get 'snapshot payload))
                                 (session-defaults (alist-get 'sessionDefaults snapshot))
                                 (main-session-key (alist-get 'mainSessionKey session-defaults)))
                            (when main-session-key
                              (setq emacs-openclaw--session-key-cache main-session-key)
                              (message "emacs-openclaw: Detected main session key: %s" main-session-key)))
                          (setq emacs-openclaw--websocket-connected t)
                          (message "emacs-openclaw: WebSocket connected and authenticated"))
                      (let ((error-msg (alist-get 'error msg)))
                        (message "emacs-openclaw: Connection error: %S" error-msg))))
                  (let ((handler (gethash msg-id emacs-openclaw--pending-requests)))
                    (when handler
                      (message "emacs-openclaw: Calling handler for %s" msg-id)
                      (funcall handler msg)
                      (remhash msg-id emacs-openclaw--pending-requests))))
                 
                 ((string= msg-type "event")
                  (let ((event-type (alist-get 'event msg)))
                    (message "emacs-openclaw: Got event: %s" event-type)
                    (cond
                     ((string= event-type "agent")
                      (message "emacs-openclaw: Processing agent event")
                      (emacs-openclaw--handle-agent-event msg)))))
                 
                 (t
                  (message "emacs-openclaw: Unknown message type: %s" msg-type)))))))))))

;; ============================================================================
;; WebSocket Lifecycle
;; ============================================================================

(defun emacs-openclaw--websocket-on-open (ws)
  "Handle websocket connection open event."
  (message "emacs-openclaw: WebSocket connection opened, sending handshake...")
  (let* ((token (emacs-openclaw--get-token))
         (connect-msg (json-encode
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

(defun emacs-openclaw--websocket-on-close (ws)
  "Handle websocket connection close event."
  (setq emacs-openclaw--websocket-connected nil)
  (setq emacs-openclaw--websocket nil)
  (message "emacs-openclaw: WebSocket connection closed"))

(defun emacs-openclaw--websocket-on-error (ws type err)
  "Handle websocket errors."
  (message "emacs-openclaw: WebSocket error: %s - %s" type err))

(defun emacs-openclaw--connect-websocket ()
  "Connect to OpenClaw gateway via websocket."
  (when (and emacs-openclaw--websocket 
             (websocket-openp emacs-openclaw--websocket))
    (websocket-close emacs-openclaw--websocket))
  
  (let* ((config (emacs-openclaw--ensure-config))
         (port (plist-get config :port))
         (url (format "ws://127.0.0.1:%d" port)))
    
    (message "emacs-openclaw: Connecting to %s..." url)
    (setq emacs-openclaw--websocket-connected nil)
    (setq emacs-openclaw--websocket
          (websocket-open
           url
           :on-open #'emacs-openclaw--websocket-on-open
           :on-message #'emacs-openclaw--websocket-on-message
           :on-close #'emacs-openclaw--websocket-on-close
           :on-error #'emacs-openclaw--websocket-on-error))))

(defun emacs-openclaw--ensure-websocket ()
  "Ensure websocket connection is established."
  (unless (and emacs-openclaw--websocket emacs-openclaw--websocket-connected)
    (emacs-openclaw--connect-websocket)
    (let ((retries (floor (/ emacs-openclaw-websocket-timeout 0.2))))
      (while (and (> retries 0) 
                  (not emacs-openclaw--websocket-connected))
        (accept-process-output nil 0.2)
        (setq retries (1- retries)))
      (unless emacs-openclaw--websocket-connected
        (error "Failed to establish websocket connection to OpenClaw gateway")))))

;;;###autoload
(defun emacs-openclaw-disconnect ()
  "Disconnect from OpenClaw gateway."
  (interactive)
  (when (and emacs-openclaw--websocket 
             (websocket-openp emacs-openclaw--websocket))
    (websocket-close emacs-openclaw--websocket)
    (setq emacs-openclaw--websocket nil)
    (setq emacs-openclaw--websocket-connected nil)
    (message "emacs-openclaw: Disconnected from gateway")))

;; ============================================================================
;; Chat Request Sending
;; ============================================================================

(defun emacs-openclaw--websocket-send-chat (prompt callback)
  "Send a message request via the agent method."
  (emacs-openclaw--ensure-websocket)
  
  (let* ((req-id (emacs-openclaw--generate-request-id))
         (session-key (emacs-openclaw--get-session-key))
         (msg (json-encode
               `((type . "req")
                 (id . ,req-id)
                 (method . "agent")
                 (params . ((sessionKey . ,session-key)
                           (message . ,prompt)
                           (idempotencyKey . ,req-id)
                           (deliver . :json-false)))))))
    
    (message "emacs-openclaw: Sending agent request id=%s session=%s msg=%s" req-id session-key prompt)
    
    (puthash req-id callback emacs-openclaw--pending-requests)
    (setq emacs-openclaw--current-message-buffer "")
    (websocket-send-text emacs-openclaw--websocket msg)))

;; Forward declare for use in event handlers
(declare-function emacs-openclaw--log "emacs-openclaw-chat")

(provide 'emacs-openclaw-websocket)
;;; emacs-openclaw-websocket.el ends here
