#!/bin/sh
# Only read when X is started with startx/xinit (the greetd + tuigreet path).
# Under a display manager — GDM here — this file is never sourced: the DM runs
# /etc/X11/Xsession and then execs the command from /usr/share/xsessions/i3.desktop.
#
# So nothing session-critical may live here, or it breaks the moment you log in
# through a DM. Per-session setup belongs in ~/.config/i3/startup.sh, which the
# i3 config runs itself and which therefore works under both launchers.
# Environment that has to exist *before* the session starts belongs in
# ~/.xsessionrc (read by /etc/X11/Xsession.d/40x11-common_xsessionrc).

exec i3
