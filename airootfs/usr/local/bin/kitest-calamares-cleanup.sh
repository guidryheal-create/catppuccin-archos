#!/bin/bash
# Remove installer from the installed system; ignore errors (shared Qt deps with Plasma).
set +e
pacman -R --noconfirm calamares 2>/dev/null
pacman -R --noconfirm kpmcore 2>/dev/null
exit 0
