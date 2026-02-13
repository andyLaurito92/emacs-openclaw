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

;;;###autoload
(defun openclaw-append-buffer-content (buffer-name content)
  "Append CONTENT to the buffer with BUFFER-NAME.
Signals an error if the buffer does not exist."
  (if (get-buffer buffer-name)
      (with-current-buffer buffer-name
        (goto-char (point-max))
        (insert content)
        t)
    (error "Buffer '%s' does not exist" buffer-name)))

;;;###autoload
(defun openclaw-get-buffer-info (buffer-name)
  "Return information about the buffer with BUFFER-NAME as JSON.
Returns a JSON string with keys: line_count, char_count, modified, read_only, mode.
Signals an error if the buffer does not exist."
  (if (get-buffer buffer-name)
      (with-current-buffer buffer-name
        (let* ((line-count (count-lines (point-min) (point-max)))
               (char-count (- (point-max) (point-min)))
               (modified (buffer-modified-p))
               (read-only buffer-read-only)
               (mode major-mode))
          (json-encode (list :line_count line-count
                            :char_count char-count
                            :modified modified
                            :read_only read-only
                            :mode (symbol-name mode)))))
    (error "Buffer '%s' does not exist" buffer-name)))

;;;###autoload
(defun openclaw-get-buffer-region (buffer-name start end)
  "Get the region from START to END in buffer with BUFFER-NAME.
START and END are 0-indexed character positions.
Signals an error if the buffer does not exist."
  (if (get-buffer buffer-name)
      (with-current-buffer buffer-name
        (let* ((full-content (buffer-substring-no-properties (point-min) (point-max)))
               (safe-start (max 0 start))
               (safe-end (min (length full-content) end)))
          (substring full-content safe-start safe-end)))
    (error "Buffer '%s' does not exist" buffer-name)))

;;;###autoload
(defun openclaw-set-buffer-region (buffer-name start end content)
  "Replace the region from START to END in buffer with BUFFER-NAME with CONTENT.
START and END are 0-indexed character positions.
Signals an error if the buffer does not exist."
  (if (get-buffer buffer-name)
      (with-current-buffer buffer-name
        (let ((full-content (buffer-substring-no-properties (point-min) (point-max)))
              (safe-start (max 0 start)))
          (let ((safe-end (min (length full-content) end)))
            (erase-buffer)
            (insert (substring full-content 0 safe-start))
            (insert content)
            (insert (substring full-content safe-end))
            t)))
    (error "Buffer '%s' does not exist" buffer-name)))

;;;###autoload
(defun openclaw-buffer-replace (buffer-name find replace all-occurrences)
  "Search and replace in buffer with BUFFER-NAME.
Returns a JSON string with keys: success, count.
If ALL-OCCURRENCES is t, replace all; otherwise replace only first.
Signals an error if the buffer does not exist."
  (if (get-buffer buffer-name)
      (with-current-buffer buffer-name
        (let ((count 0))
          (goto-char (point-min))
          (if all-occurrences
              (while (search-forward find nil t)
                (replace-match replace)
                (setq count (1+ count)))
            (when (search-forward find nil t)
              (replace-match replace)
              (setq count 1)))
          (json-encode (list :success t :count count))))
    (error "Buffer '%s' does not exist" buffer-name)))

(provide 'emacs-openclaw-buffers)
;;; emacs-openclaw-buffers.el ends here
