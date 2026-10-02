;;; tools/test/config.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 petrolal <petrolalucas@gmail.com>
;;
;; Author: petrolal <petrolalucas@gmail.com>
;; URL: https://github.com/petrolal/hell-emacs
;; License: GPL-3.0-or-later
;;
;; This file is part of Hell Emacs.
;;
;; Hell Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Hell Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;; Test results and coverage (Phase 12.5), for every JVM language, from
;; the reports the build tools already write (autoload.el):
;; - after a build that ran tests, *hell-tests* lists them (failures
;;   first, with their message); the failing tests' message points to it.
;;   RET goes to the test (the failing line), r reruns it, f reruns the
;;   failing ones, g reads every report again, c shows coverage per file.
;; - coverage from JaCoCo, added on the command line (a Gradle init
;;   script, the Maven plugin by its coordinates), never to the build:
;;   covered, partly covered and missed lines marked in the fringe (the
;;   margin in a terminal).
;;
;; Adds to the localleader's test group, `C-c l t' in a buffer that
;; builds with the project's build tool (`hell-forge-mode', from
;; `:tools build', which binds `t' the test at point and `T' the class):
;;   r results   f rerun failing tests
;;   c run the tests with coverage   s show coverage   h hide it
;;
;; +watch: saving a JVM source reruns its class's tests
;; (`hell-test-watch-mode'): a test class itself, another class its
;; ...Test class if there's one.

(setq hell-forge-test-failures-hint " -- see *hell-tests* (C-c l t r)")

(after! compile
  (add-hook 'compilation-finish-functions #'hell-test-results--after-build-h)
  (add-hook 'compilation-finish-functions #'hell-coverage--after-build-h))

(hell-localleader-def 'hell-forge-mode
  "t"   "test"
  "t r" '("test results" . hell-test-results)
  "t f" '("rerun failing tests" . hell-test-results-rerun-failures)
  "t c" '("run tests with coverage" . hell-coverage-run)
  "t s" '("show coverage" . hell-coverage-show)
  "t h" '("hide coverage" . hell-coverage-hide))

(when (modulep! +watch)
  (add-hook! (java-mode java-ts-mode kotlin-mode kotlin-ts-mode groovy-mode scala-mode scala-ts-mode)
             #'hell-test-watch-mode))
