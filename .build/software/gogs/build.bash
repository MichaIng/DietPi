#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals

# Build deps
G_AGI gcc libc6-dev 7zip zip

# Download & Build
# shellcheck disable=SC1091
. /etc/bashrc.d/go.sh
G_EXEC_OUTPUT=1 G_EXEC go install 'gogs.io/gogs@latest'

# Archive
G_EXEC mkdir gogs
G_EXEC mv go/bin/gogs gogs/
G_EXEC 7zz a -mx=9 "/tmp/gogs_$G_HW_ARCH_NAME.7z" gogs
(( $G_HW_ARCH == 1 )) && G_EXEC zip -9r /tmp/gogs_armv6.zip gogs

# Cleanup
G_EXEC rm -R gogs

exit 0
}
