from pathlib import Path
from typing import Final

from archinstall.lib.linux_path import LPath

ARCHISO_MOUNTPOINT: Final = Path('/run/archiso/airootfs')
MIRRORLIST: Final = LPath('/etc/pacman.d/mirrorlist')
PACMAN_CONF: Final = LPath('/etc/pacman.conf')
KITEST_DEFAULT_LOCAL_REPO: Final = '/var/tmp/kitest-localrepo'
