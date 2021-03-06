;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(in-package :nyxt)

(define-class search-engine ()
  ((shortcut (error "Slot `shortcut' must be set")
             :type string
             :documentation "The word used to refer to the search engine, for
instance from the `set-url' commands.")
   (search-url (error "Slot `search-url' must be set")
               :type string
               :documentation "The URL containing a '~a' which will be replaced with the search query.")
   (fallback-url nil
                 :type (or null quri:uri)
                 :writer t
                 :documentation "The URL to fall back to when given an empty
query.  This is optional: if nil, use `search-url' instead with ~a expanded to
the empty string."))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:accessor-name-transformer (hu.dwim.defclass-star:make-name-transformer name)))

(defmethod fallback-url ((engine search-engine))
  (or (slot-value engine 'fallback-url)
      (quri:uri (format nil (search-url engine) ""))))

(export-always 'make-search-engine)
(defun make-search-engine (shortcut search-url &optional fallback-url)
  (make-instance 'search-engine
                 :shortcut shortcut
                 :search-url search-url
                 :fallback-url fallback-url))

(defmethod prompter:object-attributes ((engine search-engine))
  `(("Shortcut" ,(shortcut engine))
    ("Search URL" ,(search-url engine))))

(defun bookmark-search-engines (&optional (bookmarks (get-data (bookmarks-path
                                                                (or (current-buffer)
                                                                    (make-instance 'user-buffer))))))
  (mapcar (lambda (b)
            (make-instance 'search-engine
                           :shortcut (shortcut b)
                           :search-url (if (quri:uri-scheme (quri:uri (search-url b)))
                                           (search-url b)
                                           (str:concat (render-url (url b)) (search-url b)))
                           :fallback-url (render-url (url b))))
          (remove-if (lambda (b) (or (str:emptyp (search-url b))
                                     (str:emptyp (shortcut b))))
                     bookmarks)))

(defun all-search-engines ()
  "Return the `search-engines' from the current buffer."
  (let ((buffer (or (current-buffer)
                    (make-instance 'user-buffer))))
    (search-engines buffer)))

(defun default-search-engine (&optional (search-engines (all-search-engines)))
  "Return the last search engine of the SEARCH-ENGINES."
  (first (last search-engines)))

(define-class search-engine-source (prompter:source)
  ((prompter:name "Search Engines")
   (prompter:constructor (all-search-engines))))

(define-class search-engine-url-source (prompter:source)
  ((prompter:name "Search Engines")
   (prompter:constructor (delete nil (mapcar #'fallback-url (all-search-engines))))))

(define-command search-selection ()
  "Search selected text using the queried search engine."
  (let* ((selection (%copy))
         (engine (first (prompt
                         :prompt "Search engine:"
                         :sources (make-instance 'search-engine-source)))))
    (when engine
      (buffer-load (make-instance 'new-url-query :query selection :engine engine)))))
