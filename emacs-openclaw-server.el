;;; emacs-openclaw-server.el --- Server management for Gmail/Calendar tools -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0

;;; Commentary:
;; Manages the Gmail/Calendar tools server (startup, shutdown, health checks).

;;; Code:

(require 'request)
(require 'cl-lib)
(require 'emacs-openclaw-config)

;; ============================================================================
;; Internal Variables
;; ============================================================================

(defvar emacs-openclaw--server-process nil)
(defvar emacs-openclaw--server-buffer "*OpenClaw-Server*")

;; ============================================================================
;; Server Health & Discovery
;; ============================================================================

(defun emacs-openclaw--server-running-p ()
  "Check if the Gmail/Calendar tools server is running."
  (condition-case nil
      (with-current-buffer (url-retrieve-synchronously 
                            (format "http://127.0.0.1:%d/health" emacs-openclaw-server-port)
                            t nil 1)
        (goto-char (point-min))
        (prog1 (search-forward "\"status\"" nil t)
          (kill-buffer)))
    (error nil)))

(defun emacs-openclaw--find-server-dir ()
  "Find the directory containing the OpenClaw server."
  (let* ((library-path (locate-library "emacs-openclaw"))
         (library-dir (when library-path (file-name-directory library-path))))
    (or
     (let ((candidate (and library-dir (expand-file-name "server" library-dir))))
       (when (and candidate (file-directory-p candidate)) candidate))
     (when (and library-dir (string-match-p "/straight/build/" library-dir))
       (let* ((repo-dir (replace-regexp-in-string "/straight/build/" "/straight/repos/" library-dir))
              (candidate (expand-file-name "server" repo-dir)))
         (when (and candidate (file-directory-p candidate)) candidate)))
     (let* ((current-file (or load-file-name buffer-file-name))
            (dev-dir (when current-file (expand-file-name "server" (file-name-directory current-file)))))
       (when (and dev-dir (file-directory-p dev-dir)) dev-dir)))))

;; ============================================================================
;; Server Lifecycle
;; ============================================================================

;;;###autoload
(defun emacs-openclaw--start-server ()
  "Start the Gmail/Calendar tools server."
  (interactive)
  (if (emacs-openclaw--server-running-p)
      (message "OpenClaw server already running on port %d" emacs-openclaw-server-port)
    (let ((server-dir (emacs-openclaw--find-server-dir)))
      
      (unless (file-directory-p emacs-openclaw-data-dir)
        (make-directory emacs-openclaw-data-dir t))

      (unless server-dir
        (error "Cannot find server directory. Please ensure emacs-openclaw is installed correctly"))
      
      (unless (executable-find "python3")
        (error "python3 not found. Please install Python 3"))
      
      (unless (file-exists-p emacs-openclaw-client-secret-path)
        (error "client_secret.json not found! Please place it in: %s" emacs-openclaw-client-secret-path))
      
      (let ((default-directory server-dir)
            (process-environment (cons (format "OPENCLAW_CLIENT_SECRET=%s" emacs-openclaw-client-secret-path)
                                       process-environment)))
        (setq emacs-openclaw--server-process
              (start-process
               "openclaw-server"
               (get-buffer-create emacs-openclaw--server-buffer)
               "python3" "-m" "uvicorn" "server:app"
               "--host" "127.0.0.1"
               "--port" (number-to-string emacs-openclaw-server-port)))
        
        (message "Starting OpenClaw server on port %d..." emacs-openclaw-server-port)
        
        (let ((max-attempts 15) (attempt 0) (delay 0.8))
          (while (and (< attempt max-attempts)
                      (not (emacs-openclaw--server-running-p)))
            (setq attempt (1+ attempt))
            (sit-for delay)
            (setq delay (min 2.0 (* delay 1.2))))
          
          (if (emacs-openclaw--server-running-p)
              (message "OpenClaw server started successfully")
            (message "Server taking longer than expected. Check %s" emacs-openclaw--server-buffer)))))))

;;;###autoload
(defun emacs-openclaw--stop-server ()
  "Stop the Gmail/Calendar tools server."
  (interactive)
  (when (and emacs-openclaw--server-process (process-live-p emacs-openclaw--server-process))
    (kill-process emacs-openclaw--server-process)
    (setq emacs-openclaw--server-process nil)
    (message "OpenClaw server stopped")))

(defun emacs-openclaw--ensure-server-running ()
  "Ensure the server is running, starting it if necessary."
  (when (and emacs-openclaw-auto-start-server (not (emacs-openclaw--server-running-p)))
    (emacs-openclaw--start-server)))

;;;###autoload
(defun emacs-openclaw-show-server-buffer ()
  "Show the server output buffer."
  (interactive)
  (if (get-buffer emacs-openclaw--server-buffer)
      (pop-to-buffer emacs-openclaw--server-buffer)
    (message "Server buffer not found.")))

;;;###autoload
(defun emacs-openclaw-get-available-tools ()
  "Get list of available tools from the server."
  (interactive)
  (if (emacs-openclaw--server-running-p)
      (request
        (format "http://127.0.0.1:%d/tools" emacs-openclaw-server-port)
        :type "GET"
        :parser 'json-read
        :success (cl-function
                  (lambda (&key data &allow-other-keys)
                    (let ((tools (alist-get 'tools data)))
                      (emacs-openclaw--save-tools-config 
                       (list :server-port emacs-openclaw-server-port
                             :tools (append tools nil)
                             :last-updated (format-time-string "%Y-%m-%d %H:%M:%S")))
                      (message "Available OpenClaw tools: %d found" (length tools))
                      (with-current-buffer (get-buffer-create "*OpenClaw-Tools*")
                        (erase-buffer)
                        (insert "Available OpenClaw Gmail/Calendar Tools:\n\n")
                        (dolist (tool tools)
                          (insert (format "• %s (%s %s)\n  %s\n\n"
                                        (alist-get 'name tool)
                                        (alist-get 'method tool)
                                        (alist-get 'endpoint tool)
                                        (alist-get 'description tool))))
                        (goto-char (point-min))
                        (pop-to-buffer (current-buffer))))))
        :error (cl-function
                (lambda (&key error-thrown &allow-other-keys)
                  (message "Failed to get tools: %s" error-thrown))))
    (message "Server is not running.")))

(provide 'emacs-openclaw-server)
;;; emacs-openclaw-server.el ends here
