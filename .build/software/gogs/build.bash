#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals

# Build deps
deps=() c7zip='7zr'
(( $G_DISTRO > 6 )) && deps+=('7zip') c7zip='7zz'

G_AGUP
G_AGDUG gcc libc6-dev "${deps[@]}"

# Download & Build
# shellcheck disable=SC1091
. /etc/bashrc.d/go.sh
G_EXEC_OUTPUT=1 G_EXEC go install 'gogs.io/gogs@latest'

# Archive
G_EXEC mkdir gogs
G_EXEC mv /root/go/bin/gogs gogs/
G_EXEC strip gogs/gogs
G_EXEC "$c7zip" a -mx=9 "/tmp/gogs_$G_HW_ARCH_NAME.7z" gogs

# Cleanup
G_EXEC rm -R gogs

exit 0
}
