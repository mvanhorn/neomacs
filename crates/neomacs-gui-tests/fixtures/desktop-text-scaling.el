;;; desktop-text-scaling.el --- GNOME text-scaling-factor startup -*- lexical-binding: t -*-
(setq native-comp-jit-compilation nil native-comp-enable-subr-trampolines nil)

(defun desktop-text-scaling-env-number (variable)
  (let ((value (getenv variable)))
    (unless value
      (error "Set %s" variable))
    (string-to-number value)))

(run-at-time
 1 nil
 (lambda ()
   (condition-case err
       (progn
         (switch-to-buffer (get-buffer-create "*desktop-text-scaling*"))
         (let* ((family (or (getenv "NEOMACS_GUI_EXPECTED_FAMILY") "Ubuntu Mono"))
                (width (desktop-text-scaling-env-number
                        "NEOMACS_GUI_EXPECTED_FONT_WIDTH"))
                (height (desktop-text-scaling-env-number
                         "NEOMACS_GUI_EXPECTED_FONT_HEIGHT"))
                (tolerance (desktop-text-scaling-env-number
                            "NEOMACS_GUI_FONT_METRIC_TOLERANCE"))
                (min-menu (desktop-text-scaling-env-number
                           "NEOMACS_GUI_MIN_MENU_HEIGHT"))
                (menu-height (frame-char-height))
                (actual-width (window-font-width))
                (actual-height (window-font-height)))
           (unless (equal (font-get-system-font) "Ubuntu Mono 13")
             (error "Desktop monospace query: expected Ubuntu Mono 13, got %S"
                    (font-get-system-font)))
           (unless (equal (font-get-system-normal-font) "Ubuntu 10")
             (error "Desktop application font was not kept separate"))
           (unless (= (frame-width) 80)
             (error "Initial geometry used a different font: expected 80 columns, got %S"
                    (frame-width)))
           (unless (equal (face-attribute 'default :family) family)
             (error "Startup family: expected %S, got %S"
                    family (face-attribute 'default :family)))
           (unless (and (<= (abs (- actual-width width)) tolerance)
                        (<= (abs (- actual-height height)) tolerance))
             (error "Startup font cell %S differed from expected %S ±%S"
                    (list actual-width actual-height)
                    (list width height)
                    tolerance))
           (unless (>= menu-height min-menu)
             (error "Menu text metrics did not grow: menu-height %S min %S"
                    menu-height min-menu))
           (when (getenv "NEOMACS_GUI_STATE_JSON")
             (with-temp-file (getenv "NEOMACS_GUI_STATE_JSON")
               (insert (json-serialize
                        `((family . ,family)
                          (font_width . ,actual-width)
                          (font_height . ,actual-height)
                          (menu_height . ,menu-height)
                          (frame_width . ,(frame-width))
                          (native_width . ,(frame-native-width))
                          (native_height . ,(frame-native-height))
                          (pixel_width . ,(frame-pixel-width))
                          (pixel_height . ,(frame-pixel-height)))))))
           (when (fboundp 'neomacs--write-frame-snapshot)
             (neomacs--write-frame-snapshot
              (getenv "NEOMACS_GUI_FRAME_SNAPSHOT_JSON") t 'json))
           ;; Observe the settled native resize, not just the pending Lisp request.
           (let ((original-height (frame-pixel-height)))
             (set-frame-width nil 91)
             (run-at-time
              1 nil
              (lambda ()
                (if (and (= (frame-width) 91)
                         (= (frame-pixel-height) original-height))
                    (kill-emacs 0)
                  (message "Resized geometry: expected 91 columns and height %S, got %S / %S"
                           original-height (frame-width) (frame-pixel-height))
                  (kill-emacs 1)))))))
     (error (message "Desktop text scaling regression: %S" err) (kill-emacs 1)))))
