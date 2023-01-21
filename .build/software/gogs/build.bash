#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals

# Build deps
deps=() c7zip='7zr'
(( $G_DISTRO > 6 )) && deps+=('7zip') c7zip='7zz'
(( $G_HW_ARCH == 1 )) && deps+=('zip')
G_AGI gcc libc6-dev "${p7zip[@]}"

# Download & Build
# shellcheck disable=SC1091
. /etc/bashrc.d/go.sh
G_EXEC_OUTPUT=1 G_EXEC go install 'gogs.io/gogs@latest'

# Archive
G_EXEC mkdir gogs
G_EXEC mv /root/go/bin/gogs gogs/
G_EXEC "$c7zip" a -mx=9 "/tmp/gogs_$G_HW_ARCH_NAME.7z" gogs
 # Pre-v8.14 ARMv6 zip generation
(( $G_HW_ARCH$G_DISTRO == 15 )) && G_EXEC zip -9r /tmp/gogs_armv6.zip gogs

# Cleanup
G_EXEC rm -R gogs

exit 0
}
