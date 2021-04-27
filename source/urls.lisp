;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(in-package :nyxt)

(export-always 'render-url)
(declaim (ftype (function ((or quri:uri string)) string) render-url))
(defun render-url (url)
    "Return decoded URL.
If the URL contains hexadecimal-encoded characters, return their unicode counterpart."
  (let ((url (if (stringp url)
                 url
                 (quri:render-uri url))))
    (the (values (or string null) &optional)
         (or (ignore-errors (ffi-display-uri url))
             url))))

(export-always 'generate-search-query)
(defun generate-search-query (search-string search-url)
  (let* ((encoded-search-string
           ;; We need to encode the search string to escape special characters.
           ;; Besides, we separate search patterns by a "+".
           (cl-ppcre:regex-replace-all "(%20)+" (quri:url-encode search-string) "+"))
         (url (format nil search-url encoded-search-string)))
    url))

(export-always 'valid-url-p)
(defun valid-url-p (url)
  ;; List of URI schemes: https://www.iana.org/assignments/uri-schemes/uri-schemes.xhtml
  ;; Last updated 2020-08-26.
  (let* ((nyxt-schemes '("lisp" "javascript"))
         (iana-schemes
           '("aaa" "aaas" "about" "acap" "acct" "cap" "cid" "coap" "coap+tcp" "coap+ws"
             "coaps" "coaps+tcp" "coaps+ws" "crid" "data" "dav" "dict" "dns" "example" "file"
             "ftp" "geo" "go" "gopher" "h323" "http" "https" "iax" "icap" "im" "imap" "info"
             "ipp" "ipps" "iris" "iris.beep" "iris.lwz" "iris.xpc" "iris.xpcs" "jabber"
             "ldap" "leaptofrogans" "mailto" "mid" "msrp" "msrps" "mtqp" "mupdate" "news"
             "nfs" "ni" "nih" "nntp" "opaquelocktoken" "pkcs11" "pop" "pres" "reload" "rtsp"
             "rtsps" "rtspu" "service" "session" "shttp" "sieve" "sip" "sips" "sms" "snmp"
             "soap.beep" "soap.beeps" "stun" "stuns" "tag" "tel" "telnet" "tftp"
             "thismessage" "tip" "tn3270" "turn" "turns" "tv" "urn" "vemmi" "vnc" "ws" "wss"
             "xcon" "xcon-userid" "xmlrpc.beep" "xmlrpc.beeps" "xmpp" "z39.50r" "z39.50s"))
         (valid-schemes (append nyxt-schemes iana-schemes))
         (uri (ignore-errors (quri:uri url))))
    (flet ((hostname-found-p (name)
             (handler-case (iolib/sockets:lookup-hostname name)
               (t () nil)))
           (valid-scheme-p (scheme)
             (find scheme valid-schemes :test #'string=))
           (http-p (scheme)
             (find scheme '("http" "https") :test #'string=)))
      (and uri
           (quri:uri-p uri)
           (valid-scheme-p (quri:uri-scheme uri))
           ;; `parse-url' tries to guess
           ;; the URL from the user input by prefixing it with HTTPS:
           (or (not (http-p (quri:uri-scheme uri)))
               (and
                ;; "http://" does not have a host.
                ;; A valid URL may have an empty domain, e.g. http://192.168.1.1.
                (quri:uri-host uri)
                ;; "http://algo" has the "algo" hostname but it's probably invalid
                ;; unless it's found on the local network.  We also need to
                ;; support "localhost" and the current system hostname.
                ;; get-host-by-name may signal a ns-try-again-condition which is
                ;; not an error, so we can't use `ignore-errors' here.
                (or (quri:ip-addr-p (quri:uri-host uri))
                    (hostname-found-p (quri:uri-host uri)))))))))

(declaim (ftype (function (t) quri:uri) ensure-url))
(defun ensure-url (thing)
  "Return `quri:uri' derived from THING.
If it cannot be derived, return an empty `quri:uri'."
  (the (values quri:uri &optional)
       (if (quri:uri-p thing)
           thing
           (or (ignore-errors (quri:uri thing))
               (quri:uri "")))))

(declaim (ftype (function ((or quri:uri string null)) boolean) url-empty-p))
(export-always 'url-empty-p)
(defun url-empty-p (url)
  "Small convenience function to check whether the given URL is empty."
  (the (values boolean &optional)
       (uiop:emptyp (if (quri:uri-p url) (quri:render-uri url) url))))

(declaim (ftype (function (quri:uri) boolean)
                empty-path-url-p host-only-url-p))
(export-always 'empty-path-url-p)
(defun empty-path-url-p (url)
  (or (string= (quri:uri-path url) "/")
      (null (quri:uri-path url))))

(export-always 'host-only-url-p)
(defun host-only-url-p (url)
  (every #'null
         (list (quri:uri-query url)
               (quri:uri-fragment url)
               (quri:uri-userinfo url))))

(declaim (ftype (function (quri:uri quri:uri) boolean) schemeless-uri=))
(defun schemeless-uri= (uri1 uri2)
  "Like `quri:uri=' but ignore scheme in comparison.
Authority is compared case-insensitively (RFC 3986)."
 (and (equal  (or (quri:uri-path uri1) "/") (or (quri:uri-path uri2) "/"))
      (equal  (quri:uri-query uri1)     (quri:uri-query uri2))
      (equal  (quri:uri-fragment uri1)  (quri:uri-fragment uri2))
      (equalp (quri:uri-authority uri1) (quri:uri-authority uri2))))

(declaim (ftype (function (quri:uri) string) schemeless-url))
(defun schemeless-url (uri)             ; Inspired by `quri:render-uri'.
  "Return URL without its scheme (e.g. it removes 'https://')."
  ;; Warning: We can't just set `quri:uri-scheme' to nil because that would
  ;; change the port (e.g. HTTP defaults to 80, HTTPS to 443).
  (format nil
          "~@[~A~]~@[~A~]~@[?~A~]~@[#~A~]"
          (quri:uri-authority uri)
          (or (quri:uri-path uri) "/")
          (quri:uri-query uri)
          (quri:uri-fragment uri)))

(declaim (ftype (function (quri:uri quri:uri) boolean) url<))
(defun uri< (uri1 uri2)
  "Like `string<' but ignore the URI scheme.
This way, HTTPS and HTTP is ignored when comparing URIs."
  (string< (schemeless-url uri1)
           (schemeless-url uri2)))

(declaim (ftype (function (quri:uri quri:uri) boolean) url-equal))
(defun url-equal (url1 url2)
  "URLs are equal if the URIs are equal, scheme excluded.
Empty paths are also excluded from the comparison.
For instance, these are equal:
- http://example.org
- https://example.org/"
  (if (and (quri:uri-http-p url1)
           (quri:uri-http-p url2))
      (schemeless-uri= url1 url2)
      (the (values boolean &optional) (quri:uri= url1 url2))))

(declaim (ftype (function (string) (values (or quri:uri null) t &optional)) parse-url))
(defun parse-url (input-url)
  "From user input, return the full URL to visit.

If the first word references a search engine, generate a search query.
If the input starts with an URI scheme, open it as is.
If the input is actually a file path, open it.
Suppose the user omitted the scheme: if the input prefixed by 'https://' gives a valid URI, go to it.
Otherwise, build a search query with the default search engine."
  (let* ((search-engines (all-search-engines))
         (terms (str:split " " input-url :omit-nulls t))
         (engine (find (first terms)
                       search-engines :test #'string= :key #'shortcut)))
    (if engine
        (let ((new-input (str:join " " (rest terms))))
          (if (and (not (str:emptyp (fallback-url engine)))
                   (str:emptyp new-input))
              (quri:uri (fallback-url engine))
              (quri:uri (generate-search-query new-input (search-url engine)))))
        (let ((recognized-scheme (and (valid-url-p input-url)
                                      (quri:uri-scheme (quri:uri input-url)))))
          (cond
            ((and recognized-scheme
                  (not (string= "file" recognized-scheme)))
             (quri:uri input-url))
            ((or (string= "file" recognized-scheme)
                 (uiop:file-exists-p input-url))
             (quri:uri (if (string= "file" recognized-scheme)
                           input-url
                           (format nil "file://~a"
                                   (uiop:ensure-absolute-pathname
                                    input-url *default-pathname-defaults*)))))
            ((valid-url-p (str:concat "https://" input-url))
             (quri:uri (str:concat "https://" input-url)))
            (t (alex:if-let ((default (default-search-engine search-engines)))
                 (quri:uri (generate-search-query input-url (search-url default)))
                 (quri:uri input-url))))))))

(export-always 'lisp-url)
(declaim (ftype (function (t &rest t) string) lisp-url))
(defun lisp-url (lisp-form &rest more-lisp-forms)
  "Generate a lisp:// URL from the given Lisp forms. This is useful for encoding
functionality into internal-buffers."
  (the (values string &optional)
       (apply #'str:concat "lisp://"
              (mapcar (alex:compose #'quri:url-encode #'write-to-string)
                      (cons lisp-form more-lisp-forms)))))

(declaim (ftype (function (quri:uri quri:uri) boolean) path=))
(defun path= (url1 url2)
  "Return non-nil when URL1 and URL2 have the same path."
  ;; See https://github.com/fukamachi/quri/issues/48.
  (equalp (string-right-trim "/" (or (quri:uri-path url1) ""))
          (string-right-trim "/" (or (quri:uri-path url2) ""))))

(declaim (ftype (function (quri:uri quri:uri) boolean) scheme=))
(defun scheme= (url1 url2)
  "Return non-nil when URL1 and URL2 have the same scheme.
HTTP and HTTPS belong to the same equivalence class."
  (or (equalp (quri:uri-scheme url1) (quri:uri-scheme url2))
      (and (quri:uri-http-p url1) (quri:uri-http-p url2))))

(declaim (ftype (function (quri:uri quri:uri) boolean) domain=))
(defun domain= (url1 url2)
  "Return non-nil when URL1 and URL2 have the same domain."
  (equalp (quri:uri-domain url1) (quri:uri-domain url2)))

(declaim (ftype (function (quri:uri quri:uri) boolean) host=))
(defun host= (url1 url2)
  "Return non-nil when URL1 and URL2 have the same host.
This is a more restrictive requirement than `domain='."
  (equalp (quri:uri-host url1) (quri:uri-host url2)))

(declaim (ftype (function (quri:uri quri:uri list) boolean) url-eqs))
(defun url-eqs (url1 url2 eq-fn-list)
  "Return non-nil when URL1 and URL2 are \"equal\" as dictated by EQ-FN-LIST.

EQ-FN-LIST is a list of functions that take URL1 and URL2 as arguments and
return a boolean.  It defines an equivalence relation induced by EQ-FN-LIST.
`quri:uri=' and `url-equal' are examples of equivalence relations."
  ;; (and (fn1 url1 url2) (fn2 url1 url2) ...) stops as soon as any fn returns
  ;; nil, unlike the solution below.
  (every #'identity (mapcar (lambda (fn) (funcall fn url1 url2)) eq-fn-list)))
