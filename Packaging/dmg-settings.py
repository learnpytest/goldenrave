# dmgbuild layout for goldenrave.dmg: the app on the left, Applications on the
# right, and a background arrow between them. Scripts/build-dmg.sh passes the
# paths in with -D app=... -D background=...
import os

app = defines["app"]
application = os.path.basename(app)

# Built writable; build-dmg.sh fixes the layout file, then compresses it.
format = "UDRW"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}

# dmg-background@2x.png next to it is picked up for Retina screens.
background = defines["background"]
# 428 tall: the window bounds include the title bar, the background is 400.
window_rect = ((200, 120), (600, 428))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 128
text_size = 13
# Centres in window points; the background arrow runs between x=250 and 350.
icon_locations = {
    application: (170, 200),
    "Applications": (430, 200),
}
