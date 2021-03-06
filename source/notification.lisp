;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(in-package :nyxt)

(defvar *notify-send-program* "notify-send")

(export-always 'notify)
(defun notify (msg)
  "Echo this message and display it with a desktop notification system (notify-send on linux, terminal-notifier on macOs)."
  (echo-warning msg)
  (ignore-errors
    (uiop:launch-program
     #+linux
     (list *notify-send-program* msg)
     #+darwin
     (list "terminal-notifier" "-title" "Nyxt" "-message" msg))))

(export-always 'launch-and-notify)
(defun launch-and-notify (command &key (success-msg "Command succeded.") (error-msg "Command failed."))
  "Run this program asynchronously and notify when it is finished."
  (run-thread
    (let ((exit-code (uiop:wait-process
                      (uiop:launch-program command))))
      (notify (if (zerop exit-code) success-msg error-msg)))))
