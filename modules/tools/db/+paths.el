;;; tools/db/+paths.el -*- lexical-binding: t; -*-

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


;; The jars `bin/hellmacs sync' installs (sqlline and `hellmacs-db-drivers')
;; or a first connect does (any other driver): pinned by SHA-256 from Maven
;; Central, whose own SHA-1s they match. Loaded by autoload.el, cli.el and
;; doctor.el.

(require 'cl-lib)

(defun hellmacs-db--central (path file)
  (concat "https://repo1.maven.org/maven2/" path "/" file))

(defvar hellmacs-db-jars
  (let ((dir (expand-file-name "jdbc/" hellmacs-data-dir)))
    (cl-flet ((jar (path version file sha256 &rest props)
                (append (list :version version :url (hellmacs-db--central path file)
                              :sha256 sha256 :file (expand-file-name file dir))
                        props)))
      `((sqlline . ,(jar "sqlline/sqlline/1.12.0" "1.12.0" "sqlline-1.12.0-jar-with-dependencies.jar"
                         "95106610c9e859e5ba0719139878f143107c5c2ef32dd613edebe6ca20c09077"))
        (postgresql . ,(jar "org/postgresql/postgresql/42.7.13" "42.7.13" "postgresql-42.7.13.jar"
                            "6e0e4cc2d8cae902084f8a2b18728b073a6fd9d1f87c9d8bff8f298c18185b93" :port 5432))
        (mysql . ,(jar "com/mysql/mysql-connector-j/26.7.0" "26.7.0" "mysql-connector-j-26.7.0.jar"
                       "69084713593a4aa8d07c383619b9639276f08bccf8faf1c562178147d389b1e1" :port 3306))
        (mariadb . ,(jar "org/mariadb/jdbc/mariadb-java-client/3.5.10" "3.5.10" "mariadb-java-client-3.5.10.jar"
                         "919b8c1c771d9ee3465811462f242c9543ab401e140c64988ddbf1d8abcb18b2" :port 3306))
        (sqlserver . ,(jar "com/microsoft/sqlserver/mssql-jdbc/13.6.0.jre11" "13.6.0.jre11" "mssql-jdbc-13.6.0.jre11.jar"
                           "4c566e4022c4dcf1489aeb639fe49a0f6ffae3d796fdc2f56b5b8882d4c3bf5a" :port 1433))
        (oracle . ,(jar "com/oracle/database/jdbc/ojdbc11/23.26.3.0.0" "23.26.3.0.0" "ojdbc11-23.26.3.0.0.jar"
                        "764cc3f88454d1be117e155d01ed617467b984c9c68f13090dd6083799d2bb8c" :port 1521))
        (db2 . ,(jar "com/ibm/db2/jcc/12.1.5.0" "12.1.5.0" "jcc-12.1.5.0.jar"
                     "04150111a29370247d162c3f05b8e938bf1314f19a63ad9a5302d88dd478e8e8" :port 50000))
        (h2 . ,(jar "com/h2database/h2/2.5.252" "2.5.252" "h2-2.5.252.jar"
                    "90b11dc413da82070ef15fc943282c1408e6ffd34fa68998335fea8603b5ff20"))
        (sqlite . ,(jar "org/xerial/sqlite-jdbc/3.53.4.0" "3.53.4.0" "sqlite-jdbc-3.53.4.0.jar"
                        "bcb1f51e36f940867e83342f9efbf5968ac44a6bef4d397bb4af7b17b45cd2fb")))))
  "sqlline and the JDBC drivers: (NAME :version :url :sha256 :file [:port]).")

(defvar hellmacs-db-drivers '(postgresql)
  "Drivers `bin/hellmacs sync' installs ahead of time (and puts in offline
bundles); others are installed, pinned, the first time they're used.")
