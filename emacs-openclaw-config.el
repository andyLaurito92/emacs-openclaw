;;; emacs-openclaw-config.el --- Configuration loading and management -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0

;;; Commentary:
;; Handles loading OpenClaw configuration from ~/.openclaw/openclaw.json
;; and persistent tools configuration storage.

;;; Code:

(require 'json)

;; ============================================================================
;; Customization Variables
;; ============================================================================

(defgroup emacs-openclaw nil
  "OpenClaw chat integration for Emacs."
  :group 'tools
  :prefix "emacs-openclaw-")

(defcustom emacs-openclaw-data-dir (locate-user-emacs-file "emacs-openclaw/")
  "Directory for storing emacs-openclaw persistent data and secrets."
  :type 'directory
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-client-secret-path (expand-file-name "client_secret.json" emacs-openclaw-data-dir)
  "Path to the Google API client_secret.json file."
  :type 'file
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-token nil
  "OpenClaw authentication token.
If nil, will attempt to load from ~/.openclaw/openclaw.json."
  :type '(choice (const :tag "Auto-detect from ~/.openclaw/openclaw.json" nil)
                 (string :tag "Explicit token"))
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-port nil
  "OpenClaw gateway port.
If nil, will attempt to load from ~/.openclaw/openclaw.json."
  :type '(choice (const :tag "Auto-detect from ~/.openclaw/openclaw.json" nil)
                 (integer :tag "Explicit port"))
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-session-key nil
  "Session key for OpenClaw requests.
If nil, will be auto-detected from the main session key provided by the gateway."
  :type '(choice (const :tag "Auto-detect from gateway" nil)
                 (string :tag "Explicit session key"))
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-server-port 3333
  "Port for the OpenClaw Gmail/Calendar tools server."
  :type 'integer
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-auto-start-server t
  "Whether to automatically start the Gmail/Calendar tools server if not running."
  :type 'boolean
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-show-tool-activity t
  "Whether to show tool call and result events in the chat buffer.
When non-nil, tool invocations and their results are displayed in a
dimmed style so you can see what the agent is doing.  Set to nil for
a cleaner chat that only shows assistant text."
  :type 'boolean
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-python-executable "python3"
  "Python executable used to start the OpenClaw server.
Defaults to \"python3\" (whatever is on your PATH), but you should set this
to the Python that has the server dependencies (uvicorn, fastapi, etc.)
installed.  Common values:
  - A virtualenv:  \"/path/to/repo/server/venv/bin/python3\"
  - A conda env:   \"/opt/homebrew/anaconda3/envs/myenv/bin/python3\"
  - A specific version: \"/opt/homebrew/opt/python@3.14/bin/python3.14\""
  :type 'string
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-websocket-timeout 10
  "Timeout in seconds for establishing WebSocket connection to OpenClaw gateway."
  :type 'integer
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-allow-speech-to-text nil
  "Enable speech-to-text support in OpenClaw chat buffer.
Requires whisper.el to be installed and configured.
Default is disabled (nil).

Note: This is the main configuration point. Set to t to enable
speech-to-text functionality. All dependencies (whisper.el, Whisper CLI,
ffmpeg) must be installed and configured by the user separately."
  :type 'boolean
  :group 'emacs-openclaw)

(defcustom emacs-openclaw-whisper-keybinding "C-c C-s"
  "Keybinding for starting/stopping speech recording in OpenClaw chat.
Only used if `emacs-openclaw-allow-speech-to-text' is non-nil.
Set to nil to disable keybinding."
  :type '(choice (const :tag "Disabled" nil)
                 (string :tag "Key sequence"))
  :group 'emacs-openclaw)

;; ============================================================================
;; Internal Variables
;; ============================================================================

(defvar emacs-openclaw--token-cache nil)
(defvar emacs-openclaw--port-cache nil)
(defvar emacs-openclaw--session-key-cache nil
  "Cached session key detected from gateway hello-ok response.")

;; ============================================================================
;; Configuration Loading
;; ============================================================================

(defun emacs-openclaw--config-file ()
  "Get the path to the OpenClaw tools config file in the data directory."
  (expand-file-name "tools-config.json" emacs-openclaw-data-dir))

(defun emacs-openclaw--save-tools-config (tools-info)
  "Save TOOLS-INFO to persistent config file."
  (unless (file-directory-p emacs-openclaw-data-dir)
    (make-directory emacs-openclaw-data-dir t))
  (let ((config-file (emacs-openclaw--config-file)))
    (with-temp-file config-file
      (insert (json-encode tools-info)))
    (message "Saved tools configuration to %s" config-file)))

(defun emacs-openclaw--load-tools-config ()
  "Load tools configuration from persistent storage."
  (let ((config-file (emacs-openclaw--config-file)))
    (when (file-exists-p config-file)
      (condition-case err
          (let ((json-object-type 'plist)
                (json-array-type 'list))
            (json-read-file config-file))
        (error
         (message "emacs-openclaw: Failed to load tools config: %s" err)
         nil)))))

(defun emacs-openclaw--load-config ()
  "Load OpenClaw configuration from ~/.openclaw/openclaw.json."
  (let ((config-file (expand-file-name "~/.openclaw/openclaw.json")))
    (when (file-exists-p config-file)
      (condition-case err
          (let* ((json-object-type 'plist)
                 (json-array-type 'list)
                 (config (json-read-file config-file))
                 (gateway (plist-get config :gateway))
                 (auth (plist-get gateway :auth))
                 (token (plist-get auth :token))
                 (port (plist-get gateway :port)))
            (when (and token port)
              (list :token token :port port)))
        (error 
         (message "emacs-openclaw: Failed to load config from %s: %s" config-file err)
         nil)))))

(defun emacs-openclaw--ensure-config ()
  "Ensure token and port are available."
  (unless emacs-openclaw--token-cache
    (let ((config (emacs-openclaw--load-config)))
      (if config
          (progn
            (setq emacs-openclaw--token-cache (plist-get config :token)
                  emacs-openclaw--port-cache (plist-get config :port))
            (message "emacs-openclaw: Loaded config from ~/.openclaw/openclaw.json"))
        (setq emacs-openclaw--token-cache :not-found))))
  
  (let ((token (or emacs-openclaw-token 
                   (when (and emacs-openclaw--token-cache 
                              (not (eq emacs-openclaw--token-cache :not-found)))
                     emacs-openclaw--token-cache)))
        (port (or emacs-openclaw-port 
                  (when (and emacs-openclaw--port-cache 
                             (not (eq emacs-openclaw--port-cache :not-found)))
                    emacs-openclaw--port-cache)
                  18789)))
    
    (unless token
      (error "OpenClaw token not found. Please set emacs-openclaw-token"))
    
    (list :token token :port port)))

(defun emacs-openclaw--get-base-url ()
  (let ((config (emacs-openclaw--ensure-config)))
    (format "http://127.0.0.1:%d" (plist-get config :port))))

(defun emacs-openclaw--get-token ()
  (plist-get (emacs-openclaw--ensure-config) :token))

(defun emacs-openclaw--get-session-key ()
  "Get the session key to use for requests.
Tries in order: explicit config, cached from gateway, or default to main session."
  (or emacs-openclaw-session-key
      emacs-openclaw--session-key-cache
      "agent:main:main"))  ; Fallback to main agent session

(provide 'emacs-openclaw-config)
;;; emacs-openclaw-config.el ends here
