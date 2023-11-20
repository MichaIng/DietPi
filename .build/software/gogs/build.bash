#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals

# Build deps
(( $G_DISTRO < 7 )) && deps=('p7zip') || deps=('7zip')
(( $G_DISTRO == 7 )) && c7zip='7zz' || c7zip='7zr' # Since Trixie, the 7zip package provides again (only) the 7z/7zr commands, not 7zz

G_AGUP
G_AGDUG gcc libc6-dev "${deps[@]}"

# Download & Build
# shellcheck disable=SC1091
. /etc/bashrc.d/go.sh
# - Trixie: Workaround for missing HOME, as we run dietpi-login from a systemd service instead of after an actual autologin, so that GOPATH is not defined either: go: go: module cache not found: neither GOMODCACHE nor GOPATH is set
[[ $HOME ]] || export HOME='/root'
G_EXEC_OUTPUT=1 G_EXEC go install 'gogs.io/gogs@latest'

# Archive
G_EXEC mkdir gogs
G_EXEC mv /root/go/bin/gogs gogs/
G_EXEC strip gogs/gogs
grep -q '^ID=raspbian' /etc/os-release && G_HW_ARCH_NAME='armv6l'
G_EXEC "$c7zip" a -mx=9 "/tmp/gogs_$G_HW_ARCH_NAME.7z" gogs

# Cleanup
G_EXEC rm -R gogs

exit 0
}
