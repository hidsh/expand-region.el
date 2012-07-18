;;; python-el-fgallina-expansions.el --- fgallina/python.el-specific expansions for expand-region

;; Copyright (C) 2012 Felix Geller

;; Author: Felix Geller
;; Keywords: marking region python

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;;  - Additions implemented here:
;;    - `er/mark-inside-python-string'
;;    - `er/mark-outside-python-string'
;;    - `er/mark-python-statement'
;;    - `er/mark-python-block'
;;    - `er/mark-outer-python-block'
;;  - Supports multi-line strings

;;; Code:

(require 'expand-region-core)

(defvar er--python-string-delimiter
  "'\""
  "Characters that delimit a Python string.")

; copied from @fgallina's python.el as a quick fix. The variable
; `python-rx-constituents' is not bound when we use the python-rx
; macro from here, so we have to construct the regular expression
; manually.
(defvar er--python-block-start-regex
  (rx symbol-start
      (or "def" "class" "if" "elif" "else" "try"
          "except" "finally" "for" "while" "with")
      symbol-end)
  "Regular expression string to match the beginning of a Python block.")

(defun er/mark-python-string (mark-inside)
  "Mark the Python string that surrounds point.

If the optional MARK-INSIDE is not nil, only mark the region
between the string delimiters, otherwise the region includes the
delimiters as well."
  (let ((beginning-of-string (python-info-ppss-context 'string (syntax-ppss))))
    (when beginning-of-string
      (goto-char beginning-of-string)
      ;; Move inside the string, so we can use ppss to find the end of
      ;; the string.
      (skip-chars-forward er--python-string-delimiter)
      (while (python-info-ppss-context 'string (syntax-ppss))
        (forward-char 1))
      (when mark-inside (skip-chars-backward er--python-string-delimiter))
      (set-mark (point))
      (goto-char beginning-of-string)
      (when mark-inside (skip-chars-forward er--python-string-delimiter)))))

(defun er/mark-inside-python-string ()
  "Mark the inside of the Python string that surrounds point.

Command that wraps `er/mark-python-string'."
  (interactive)
  (er/mark-python-string t))

(defun er/mark-outside-python-string ()
  "Mark the outside of the Python string that surrounds point.

Command that wraps `er/mark-python-string'."
  (interactive)
  (er/mark-python-string nil))

(defun er/mark-python-statement ()
  "Mark the Python statement that surrounds point."
  (interactive)
  (python-nav-statement-end)
  (set-mark (point))
  (python-nav-statement-start))

(defun er/mark-python-block (&optional next-indent-level)
  "Mark the Python block that surrounds point.

If the optional NEXT-INDENT-LEVEL is given, select the
surrounding block that is defined at an indentation that is less
than NEXT-INDENT-LEVEL."
  (interactive)
  (back-to-indentation)
  (let ((next-indent-level
         (or
          ;; Use the given level
          next-indent-level
          ;; Check whether point is at the start of a Python block.
          (if (looking-at er--python-block-start-regex)
              ;; Block start means that the next level is deeper.
              (+ (current-indentation) python-indent)
            ;; Assuming we're inside the block that we want to mark
            (current-indentation)))))
    ;; Move point to next Python block start at the correct indent-level
    (while (>= (current-indentation) next-indent-level)
      (re-search-backward er--python-block-start-regex))
    ;; Mark the beginning of the block
    (set-mark (point))
    ;; Save indentation and look for the end of this block
    (let ((block-indentation (current-indentation)))
      (forward-line 1)
      (while (and (or (> (current-indentation) block-indentation)
                      (looking-at (rx line-start (* whitespace) line-end)))
                  (not (looking-at er--python-block-start-regex)))
        (forward-line 1))
      ;; Find the end of the block by skipping comments backwards
      (beginning-of-line)
      (python-util-forward-comment -1)
      (exchange-point-and-mark))))

(defun er/mark-outer-python-block ()
  "Mark the Python block that surrounds the Python block around point.

Command that wraps `er/mark-python-block'."
  (interactive)
  (er/mark-python-block (current-indentation)))

(defun er/add-python-mode-expansions ()
  "Adds python-mode-specific expansions for buffers in python-mode"
  (let ((try-expand-list-additions '(
                                     er/mark-inside-python-string
                                     er/mark-outside-python-string
                                     er/mark-python-statement
                                     er/mark-python-block
                                     er/mark-outer-python-block
                                     )))
    (set (make-local-variable 'er/try-expand-list)
         (remove 'er/mark-inside-quotes
                 (remove 'er/mark-outside-quotes
                         (append er/try-expand-list try-expand-list-additions))))))


(add-hook 'python-mode-hook 'er/add-python-mode-expansions)

(provide 'python-el-fgallina-expansions)

;; python-el-fgallina-expansions.el ends here
