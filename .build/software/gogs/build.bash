#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals

G_AGUP
G_AGDUG gcc libc6-dev 7zip
(( $G_DISTRO == 7 )) && c7zip='7zz' || c7zip='7zr' # Since Trixie, the 7zip package provides again (only) the 7z/7zr commands, not 7zz

# Download & Build
# shellcheck disable=SC1091
. /etc/bashrc.d/go.sh
G_EXEC_OUTPUT=1 G_EXEC go install 'gogs.io/gogs@latest'

# Archive
G_EXEC mkdir gogs
G_EXEC mv /root/go/bin/gogs gogs/
G_EXEC strip gogs/gogs
grep -q '^ID=raspbian' /etc/os-release && G_HW_ARCH_NAME='armv6l'
G_EXEC "$c7zip" a -mx=9 "/tmp/gogs_$G_HW_ARCH_NAME.7z" gogs

exit 0
}
