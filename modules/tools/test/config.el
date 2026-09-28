;;; tools/test/config.el -*- lexical-binding: t; -*-

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


;; Test results and coverage (Phase 12.5), for every JVM language, from
;; the reports the build tools already write (autoload.el):
;; - after a build that ran tests, *hellmacs-tests* lists them (failures
;;   first, with their message); the failing tests' message points to it.
;;   RET goes to the test (the failing line), r reruns it, f reruns the
;;   failing ones, g reads every report again, c shows coverage per file.
;; - coverage from JaCoCo, added on the command line (a Gradle init
;;   script, the Maven plugin by its coordinates), never to the build:
;;   covered, partly covered and missed lines marked in the fringe (the
;;   margin in a terminal).
;;
;; Owns `C-c t':
;;   t results   f rerun failing tests
;;   c run the tests with coverage   s show coverage   h hide it
;;
;; +watch: saving a JVM source reruns its class's tests
;; (`hellmacs-test-watch-mode'): a test class itself, another class its
;; ...Test class if there's one.

(setq hellmacs-forge-test-failures-hint " -- see *hellmacs-tests* (C-c t t)")

(after! compile
  (add-hook 'compilation-finish-functions #'hellmacs-test-results--after-build-h)
  (add-hook 'compilation-finish-functions #'hellmacs-coverage--after-build-h))

(hellmacs-leader-def
  "t"   "test"
  "t t" '("test results" . hellmacs-test-results)
  "t f" '("rerun failing tests" . hellmacs-test-results-rerun-failures)
  "t c" '("run tests with coverage" . hellmacs-coverage-run)
  "t s" '("show coverage" . hellmacs-coverage-show)
  "t h" '("hide coverage" . hellmacs-coverage-hide))

(when (modulep! +watch)
  (add-hook! (java-mode java-ts-mode kotlin-mode kotlin-ts-mode groovy-mode scala-mode scala-ts-mode)
             #'hellmacs-test-watch-mode))
