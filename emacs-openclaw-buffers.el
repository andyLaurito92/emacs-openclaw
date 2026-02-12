;;; emacs-openclaw-buffers.el --- Buffer manipulation API for OpenClaw -*- lexical-binding: t; -*-

;; Author: Andres Laurito <andy.laurito@gmail.com>
;; Version: 0.1.0

;;; Commentary:
;; Provides buffer manipulation functions accessible via emacsclient
;; for OpenClaw agent integration.

;;; Code:

;;;###autoload
(defun openclaw-list-buffer-names ()
  "List all buffer names that do not start with a space.
Returns a list of buffer names that are user-visible."
  (mapcar #'buffer-name
          (seq-filter (lambda (buf)
                        (not (string-prefix-p " " (buffer-name buf))))
                      (buffer-list))))

;;;###autoload
(defun openclaw-create-buffer (buffer-name)
  "Create a new buffer with the given BUFFER-NAME and return its name.
If a buffer with that name already exists, returns the existing buffer's name."
  (let ((buffer (get-buffer-create buffer-name)))
    (buffer-name buffer)))

;;;###autoload
(defun openclaw-get-buffer-content (buffer-name)
  "Return the content of the buffer with the given BUFFER-NAME as a string.
Signals an error if the buffer does not exist."
  (if (get-buffer buffer-name)
      (with-current-buffer buffer-name
        (buffer-substring-no-properties (point-min) (point-max)))
    (error "Buffer '%s' does not exist" buffer-name)))

;;;###autoload
(defun openclaw-set-buffer-content (buffer-name content)
  "Set the content of the buffer with BUFFER-NAME to CONTENT string.
Erases the entire buffer and inserts the new CONTENT.
Signals an error if the buffer does not exist."
  (if (get-buffer buffer-name)
      (with-current-buffer buffer-name
        (erase-buffer)
        (insert content)
        t)
    (error "Buffer '%s' does not exist" buffer-name)))

;;;###autoload
(defun openclaw-delete-buffer (buffer-name)
  "Delete the buffer with the given BUFFER-NAME.
Returns t if the buffer was deleted, nil if it did not exist."
  (let ((buffer (get-buffer buffer-name)))
    (when buffer
      (kill-buffer buffer)
      t)))

(provide 'emacs-openclaw-buffers)
;;; emacs-openclaw-buffers.el ends here
