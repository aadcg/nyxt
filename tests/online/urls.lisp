;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(in-package :nyxt/tests)

(plan nil)

(subtest "Parse URL"
  (let* ((*browser* (make-instance 'user-browser)))
    (is (nyxt::parse-url "https://nyxt.atlas.engineer")
        (quri:uri "https://nyxt.atlas.engineer")
        :test #'quri:uri=
        "full URL")
    (is (nyxt::parse-url "nyxt.atlas.engineer")
        (quri:uri "https://nyxt.atlas.engineer")
        :test #'quri:uri=
        "URL without protocol")
    (is (nyxt::parse-url "wiki wikipedia")
        (quri:uri "https://en.wikipedia.org/w/index.php?search=wikipedia")
        :test #'quri:uri=
        "search engine")
    (is (nyxt::parse-url "nyxt browser")
        (quri:uri "https://duckduckgo.com/?q=nyxt+browser")
        :test #'quri:uri=
        "default search engine")
    (is (nyxt::parse-url "wiki wikipedia")
        (quri:uri "https://en.wikipedia.org/w/index.php?search=wikipedia")
        :test #'quri:uri=
        "wiki search engine")
    (is (nyxt::parse-url "file:///readme.org")
        (quri:uri "file:///readme.org")
        :test #'quri:uri=
        "local file")
    (is (nyxt::parse-url "foo")
        (quri:uri "https://duckduckgo.com/?q=foo")
        :test #'quri:uri=
        "empty domain")
    (is (nyxt::parse-url "algo")
        (quri:uri "https://duckduckgo.com/?q=algo")
        :test #'quri:uri=
        "same domain and TLD")
    (is (nyxt::parse-url "http://localhost:8080")
        (quri:uri "http://localhost:8080")
        :test #'quri:uri=
        "localhost")
    (is (nyxt::parse-url "*spurious*")
        (quri:uri "https://duckduckgo.com/?q=%2Aspurious%2A")
        :test #'quri:uri=
        "ignore wildcards")
    (is (nyxt::parse-url "about:blank")
        (quri:uri "about:blank")
        :test #'quri:uri=
        "about:blank")
    (is (nyxt::parse-url "foo:blank")
        (quri:uri "https://duckduckgo.com/?q=foo%3Ablank")
        :test #'quri:uri=
        "valid syntax but unknown scheme")))

(subtest "URL processing"
  (is (valid-url-p "http://foo")
      nil
      "Invalid URL (empty host)")
  (is (valid-url-p "http://algo")
      nil
      "Invalid URL (TLD == host)")
  (ok (valid-url-p "http://example.org/foo/bar?query=baz#qux")
      "Valid URL")
  (ok (valid-url-p "http://192.168.1.1")
      "Valid IP URL")
  (ok (valid-url-p "http://192.168.1.1/foo")
      "Valid IP URL with path")
  (is (nyxt::url-equal (quri:uri "http://example.org")
                       (quri:uri "https://example.org/"))
      t
      "same schemeless URIs")
  (is (nyxt::url-equal (quri:uri "https://example.org")
                       (quri:uri "https://example.org/foo"))
      nil
      "different schemeless URIs")
  (is (nyxt::schemeless-url (quri:uri "http://example.org/foo/bar?query=baz#qux"))
      "example.org/foo/bar?query=baz#qux"
      "schemeless URL")
  (is (nyxt::uri< (quri:uri "http://example.org")
                  (quri:uri "http://example.org"))
      nil
      "comparing same URL")
  (is (nyxt::uri< (quri:uri "http://example.org")
                  (quri:uri "http://example.org/"))
      nil
      "comparing same URL but for trailing slash")
  (is (nyxt::uri< (quri:uri "https://example.org")
                  (quri:uri "http://example.org"))
      nil
      "comparing same URL but for scheme")
  (is (nyxt::uri< (quri:uri "https://example.org")
                  (quri:uri "http://example.org/"))
      nil
      "comparing same URL but for scheme and trailing slash")
  (is (null (nyxt::uri< (quri:uri "https://example.org/a")
                        (quri:uri "http://example.org/b")))
      nil
      "comparing different URLs (HTTPS first)")
  (is (null (nyxt::uri< (quri:uri "http://example.org/a")
                        (quri:uri "https://example.org/b")))
      nil
      "comparing different URLs (HTTP first)"))

(finalize)
