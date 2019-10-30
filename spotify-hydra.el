;; -*- mode: emacs-lisp; lexical-binding: t -*-
;;; spotify-hydra.el --- Pre-defined Hydra, in case that interests anyone...

;; Copyright (C) 2019 Cole Brown

;;; Commentary:

;; Hydra with a nice helpful docstr that uses player status cache to populate
;; fields with current values.

;; Requires Hydra to use.
;; Desires s.el for `s-center' - fallback is no centering.
;; Desires bind-key.el for `bind-key' - fallback is `define-key'.

;;; Code:

;;---------------------------------Spotify.el-----------------------------------
;;--                 Hydra - Alternative to the Command Map.                  --
;;------------------------------------------------------------------------------

;;---
;; Requires
;;---
;; want s.el for s-center, but if not we can do without.
(require 's nil 'noerror)

;; want bind-key for keybinds, but if not we can do without.
(require 'bind-key nil 'noerror)


;;---
;; Macros
;;---
(defmacro spotify--with-hydra (&rest body)
  "If Hydra is present (featurep), evaluate BODY forms,
otherwise silently does nothing."
  (declare (indent defun))
  `(when (featurep 'hydra)
     ,@body))


(defmacro spotify--hydra-or-error (error-message &rest body)
  "If Hydra is present (featurep) and player status cache is enabled, evaluate
BODY form, otherwise calls `error' with ERROR-MESSAGE appended to a generic
spotify-hydra error message."
  (declare (indent defun))
  `(if (or (not (featurep 'hydra))
           (not 'spotify-player-status-cache-enabled))
       (error "spotify-hydra error - %s: %s"
              (if (not (featurep 'hydra))
                  "Hydra is not present"
                "Spotify Player Cache is not enabled")
              error-message)
     ,@body))


;;------------------------------------------------------------------------------
;; Settings
;;------------------------------------------------------------------------------

;; Just skip the defcustoms if we don't have Hydra...
(spotify--with-hydra

  (defgroup spotify-hydra nil
    "Hydra settings for Spotify client."
    :version "0.0.1"
    :group 'spotify)


  (defcustom spotify-hydra-keybind nil
    "Keybind to invoke Spotify.el's Hydra.
Will use bind-key if present, else define-key."
    :group 'spotify-hydra
    :type 'string)


  (defcustom spotify-hydra-player-status-format "%a - %t"
    "Format used to display the current Spotify client player status in the
Hydra docstring. The following placeholders are supported:

* %a - Artist name
* %t - Track name
* %n - Track #
* %l - Track duration, in minutes (i.e. 01:35)
* %p - Player status indicator for 'playing', 'paused', and 'stopped' states
* %s - Player shuffling status indicator
* %r - Player repeating status indicator"
    :type 'string
    :group 'spotify-hydra)


  (defcustom spotify-hydra-player-status-truncate nil
    "Whether or not to truncate artist/track names in
`spotify-hydra-player-status-format'."
    :type 'boolean
    :group 'spotify-hydra)


  (defcustom spotify-hydra-auto-remote-mode nil
    "If nil, spotify-hydra will just error if `spotify-remote-mode' is not
enabled.

If non-nil, spotify-hydra will enable
`global-spotify-remote-mode' when it's not enabled before
executing its body."
    :type 'boolean
    :group 'spotify-hydra)

  ;; §-TODO-§ [2019-10-30]: toggle state strings for:
  ;; playing
  ;; repeating
  ;; shuffling
  ;; muted

  ) ;; end Setting's spotify--with-hydra block


;;------------------------------------------------------------------------------
;; Consts & Vars
;;------------------------------------------------------------------------------


;;------------------------------------------------------------------------------
;; Interface
;;------------------------------------------------------------------------------
;; (defun spotify--hydra-hook-into-remote-mode ()
;;   "Hooks hydra setup/teardown into remote mode."
;;   (spotify--with-hydra
;;     (add-hook 'spotify-remote-mode-hook #'spotify--hydra-hook)))

;; (defun spotify--hydra-hook ()
;;   "Configures the Hydra as needed."
;;   ;; Don't error... hooks called too often.
;;   (spotify--with-hydra
;;     (if spotify-remote-mode
;;         ;; Check if setup needed.
;;         (progn
;;           )

;;         )))


;;------------------------------------------------------------------------------
;; The Hydra
;;------------------------------------------------------------------------------
;; Just skip the Hydra if we don't have Hydra? Seems reasonable...
(spotify--with-hydra
  (defhydra spotify-hydra (:color blue ;; default exit heads
                           :idle 0.25  ;; no help for this long
                           :hint none  ;; no hint - just docstr
                           ;; run this before running main hydra body
                           :body-pre #'spotify--hydra-pre-check)
    "
%s(spotify--hydra-status-format)
^Track^                 ^Playlists^                ^Misc^
^-^---------------------^-^------------------------^-^-----------------
_p_:   ?p?^^^^^^^^      _l m_: My Lists            _d_:   Select Device
_b_:   Back a Track     _l f_: Featured Lists
_f_:   Forward a Track  _l u_: User Lists          _v u_: Volume Up
_t s_: Search Track     _l s_: Search List         _v d_: Volume Down
_t p_: Recently Played  _l c_: Create list         _v m_: ?v m?
^ ^                     _l r_: ?l r?^^^^^^^^^^^^
_q_:   quit             _l s_: ?l s?^^^^^^^^^^^^^"

    ;;---
    ;; Track
    ;;---
    ("p" spotify-toggle-play
     (format "%-11s" (if (spotify-player-status-field 'playing)
                         "Pause Track"
                       "Play Track")))

    ("b" spotify-previous-track :color red)
    ("f" spotify-next-track);; :color red)

    ("t s" spotify-track-search)
    ("t p" spotify-recently-played)

    ;;---
    ;; Playlist
    ;;---
    ("l m" spotify-my-playlists)
    ("l f" spotify-featured-playlists)
    ("l u" spotify-user-playlists)
    ("l s" spotify-playlist-search)
    ("l c" spotify-create-playlist)

    ("l r" spotify-toggle-repeat
     (concat (if (spotify-player-status-field 'repeating)
                 "[R] " "[-] ")
             "Toggle Repeat"))
    ("l s" spotify-toggle-shuffle
     (concat (if (spotify-player-status-field 'shuffling)
                 "[S] " "[-] ")
             "Toggle Shuffle"))

    ;;---
    ;; Volume & Misc
    ;;---
    ("v u" spotify-volume-up   :color red)
    ("v d" spotify-volume-down :color red)
    ("v m" spotify-volume-mute-unmute
     (concat (if (spotify-player-status-field 'muted)
                 "[M] " "[-] ")
             "Toggle Mute"))

    ("d"   spotify-select-device)
    ;; quit - no need to do anything; just nil
    ("q"   nil)))


;;------------------------------------------------------------------------------
;; Hydra Helpers
;;------------------------------------------------------------------------------

(defun spotify--hydra-status-format (fmt-str &optional center-at)
  "Formats `spotify-hydra-player-status-format' using FMT-STR and
cached status. Requires `spotify-player-status-cache-enabled' to
be non-nil.

If CENTER-AT is an integer and `s-center' is present (functionp),
centers string at that length."
  (spotify--hydra-or-error "spotify--hydra-status-format"

    ;; get and return format, centered if we can/want
    (let ((ret-val (spotify--player-status-format
                    spotify-hydra-player-status-format
                    nil
                    spotify-hydra-player-status-truncate)))
      (if (and center-at
               (integerp center-at)
               (functionp 's-center))
          (s-center center-at ret-val)
        ret-val))))


(defun spotify--hydra-pre-check ()
  "Sanity check before running hydra..."
  (unless spotify-remote-mode
    (if (bound-and-true-p 'spotify-hydra-auto-remote-mode)
        (global-spotify-remote-mode 1)
      (error (concat "Spotify-Remote-Mode is not enabled... "
                     "Call `spotify-remote-mode' or "
                     "`global-spotify-remote-mode'.")))))


;;------------------------------------------------------------------------------
;; Setup
;;------------------------------------------------------------------------------

;; Only setup hydra keybind if it's defined...
(when (and (bound-and-true-p spotify-hydra-keybind)
           (stringp spotify-hydra-keybind))

  ;; ...and we have hydra.
  (spotify--hydra-or-error "Spotify-Hydra.el setup"

    ;; Prefer `bind-key' over `define-key'. Bind hydra on `global-map'.
    ;; We're binding to `spotify-hydra/body' manually, instead of using hydra's
    ;; bindings, so that the hydra help docstring is actually shown/useful. Not
    ;; sure about more default Emacs, but mine shows nothing or `which-key'
    ;; info if I use hydra's binding.
    (if (featurep 'bind-key)
        (bind-key spotify-hydra-keybind #'spotify-hydra/body)
      (define-key 'global-map
        (kbd spotify-hydra-keybind)
        #'spotify-hydra/body))))


;;------------------------------------------------------------------------------
;; The End.
;;------------------------------------------------------------------------------
(provide 'spotify-hydra)
