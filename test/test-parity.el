;;; test-parity.el --- Tests for the java-parity script's helpers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hellmacs
;; License: GPL-3.0-or-later
;;
;; This file is part of Hellmacs.
;;
;; Hellmacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Hellmacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; Run with `bin/hellmacs test'. The parity checks themselves need
;; JDTLS (test/integration/java-parity.el); these check the helpers they
;; pick their inputs with.

;;; Code:

(require 'ert)
(require 'cl-lib)
(load (expand-file-name "test/integration/e2e-lib" hellmacs-dir) nil t)

(ert-deftest test-parity/unresolved-type-is-not-in-the-file ()
  "The quick-fix check's type: a JDK class the file doesn't name at all.
On Spring Framework the check inserted ArrayList into a file that
imports it, so nothing was unresolved and no import was offered."
  (with-temp-buffer
    (insert "import java.util.ArrayList;\nclass A { ArrayList<String> xs; }\n")
    (let ((type (e2e-unimported-jdk-type)))
      (should (stringp type))
      (should-not (equal type "ArrayList"))
      (should (assoc type e2e-jdk-import-types))))
  ;; A wildcard import resolves every type in its package.
  (with-temp-buffer
    (insert "import java.util.*;\nimport java.util.concurrent.*;\nclass A {}\n")
    (let ((type (e2e-unimported-jdk-type)))
      (should type)
      (should-not (member (cdr (assoc type e2e-jdk-import-types))
                          '("java.util" "java.util.concurrent")))))
  ;; A name used anywhere (a field, a comment) is skipped: whole words only.
  (with-temp-buffer
    (insert "class A { MyArrayListX a; }\n")
    (should (equal (e2e-unimported-jdk-type) (caar e2e-jdk-import-types))))
  (with-temp-buffer
    (insert (mapconcat #'car e2e-jdk-import-types " "))
    (should-not (e2e-unimported-jdk-type))))

(provide 'test-parity)
;;; test-parity.el ends here
