;;; test-spring.el --- Tests for Spring Boot support (Phase 12.4) -*- lexical-binding: t; -*-

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

;; Run with `bin/hellmacs test'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'hellmacs-modules)

;; :lang java's code, where the Spring helpers live.
(let ((hellmacs-modules (make-hash-table :test #'equal))
      (warning-minimum-log-level :emergency))
  (hellmacs--enable-modules '(:tools lsp :lang (java +spring)))
  (hellmacs-module--load '(:lang . java) "autoload.el"))

(defmacro test-spring--with-tree (files &rest body)
  "Run BODY in a temporary directory holding FILES (alist of path . content)."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "hellmacs-test-spring" t)))
          (default-directory root))
     (unwind-protect
         (progn
           (dolist (f ,files)
             (let ((path (expand-file-name (car f) root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path (insert (cdr f)))))
           ,@body)
       (delete-directory root t))))

(ert-deftest test-spring/profile-discovery ()
  "Discovers Spring profiles from application-*.yml and application-*.properties."
  (test-spring--with-tree
      '(("src/main/resources/application.yml" . "server:\n  port: 8080\n")
        ("src/main/resources/application-dev.yml" . "spring:\n  datasource:\n    url: jdbc:h2:mem:dev\n")
        ("src/main/resources/application-prod.properties" . "server.port=443\n")
        ("src/main/resources/application-test.yaml" . "mock: true\n"))
    (let ((profiles (hellmacs-spring-discover-profiles root)))
      (should (member "dev" profiles))
      (should (member "prod" profiles))
      (should (member "test" profiles))
      (should-not (member "default" profiles))))
  ;; Once each, sorted; test resources, build output and the default profile
  ;; (active when no other is) aren't offered.
  (test-spring--with-tree
      '(("src/main/resources/application-dev.yml" . "")
        ("src/main/resources/application-dev.properties" . "")
        ("api/src/main/resources/config/application-local.yaml" . "")
        ("src/main/resources/application-default.yml" . "")
        ("src/test/resources/application-it.yml" . "")
        ("target/classes/application-stale.yml" . "")
        ("build/resources/main/application-stale.yml" . "")
        ("src/main/resources/logback-dev.xml" . ""))
    (should (equal (hellmacs-spring-discover-profiles root) '("dev" "local")))))

(ert-deftest test-spring/properties-yaml-completion-hooks ()
  "Verifies association of Spring application properties/yaml files with spring ls."
  (let ((spring-files '("application.properties" "application-dev.yml" "bootstrap.yaml")))
    (dolist (file spring-files)
      (should (hellmacs-spring-config-file-p file)))))

(ert-deftest test-spring/config-files-and-language-ids ()
  "Spring's config files, by name, and the language ids its server expects for them."
  (dolist (file '("pom.xml" "src/app.yml" "config.properties" "application.xml" "my-application.yml"))
    (should-not (hellmacs-spring-config-file-p file)))
  (should (hellmacs-spring-config-file-p "/p/src/main/resources/application-dev.properties"))
  (should (equal (hellmacs-spring-language-id "/p/src/main/resources/application.yml")
                 "spring-boot-properties-yaml"))
  (should (equal (hellmacs-spring-language-id "/p/bootstrap-cloud.yaml") "spring-boot-properties-yaml"))
  (should (equal (hellmacs-spring-language-id "/p/application-dev.properties") "spring-boot-properties"))
  (should-not (hellmacs-spring-language-id "/p/src/main/resources/logback.yml"))
  ;; As lsp-mode reads them: (FILE-REGEXP . ID), matched against the file name.
  (pcase-dolist (`(,file . ,id) '(("/p/application.yml" . "spring-boot-properties-yaml")
                                  ("/p/application-x.properties" . "spring-boot-properties")))
    (should (equal (cdr (seq-find (lambda (entry) (string-match-p (car entry) file))
                                  hellmacs-spring-language-ids))
                   id))))

(provide 'test-spring)
;;; test-spring.el ends here
