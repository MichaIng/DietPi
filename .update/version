#!/bin/bash
# shellcheck disable=SC2034
# Available DietPi version
G_REMOTE_VERSION_CORE=8
G_REMOTE_VERSION_SUB=14
G_REMOTE_VERSION_RC=2
# Minimum DietPi version to allow update
G_MIN_VERSION_CORE=6
G_MIN_VERSION_SUB=14
# Alternative Git branch to automatically migrate to when DietPi version is too low
G_OLD_VERSION_BRANCH='pre-v6.14'
# Minimum Debian version to allow update
G_MIN_DEBIAN=5
# Alternative Git branch to automatically migrate to when Debian version is too low
G_OLD_DEBIAN_BRANCH='stretch'
# Live patches
G_LIVE_PATCH_DESC=('Fix serial getty baudrate override')
# shellcheck disable=SC2016
G_LIVE_PATCH_COND=('(( $G_DISTRO < 7 )) && grep -q '\''9600 -'\'' /etc/systemd/system/serial-getty@*.service.d/dietpi-baudrate.conf 2> /dev/null')
G_LIVE_PATCH=('sed -i '\''s/9600 -/9600 %I/'\'' /boot/dietpi/func/dietpi-set_hardware /etc/systemd/system/serial-getty@*.service.d/dietpi-baudrate.conf')
