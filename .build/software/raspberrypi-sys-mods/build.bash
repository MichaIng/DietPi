#!/bin/bash
{
if [[ -f '/boot/dietpi/func/dietpi-globals' ]]
then
	. /boot/dietpi/func/dietpi-globals || exit 1
else
	curl -sSf "https://raw.githubusercontent.com/${G_GITOWNER:-MichaIng}/DietPi/${G_GITBRANCH:-master}/dietpi/func/dietpi-globals" -o /tmp/dietpi-globals || exit 1
	# shellcheck disable=SC1091
	. /tmp/dietpi-globals || exit 1
	G_EXEC_NOHALT=1 G_EXEC rm /tmp/dietpi-globals
fi

G_EXEC mkdir -p raspberrypi-sys-mods/{DEBIAN,lib/udev/rules.d,usr/{lib,share/doc}/raspberrypi-sys-mods}

G_EXEC curl -sSfo raspberrypi-sys-mods/usr/share/doc/raspberrypi-sys-mods/copyright 'https://raw.githubusercontent.com/RPi-Distro/raspberrypi-sys-mods/master/debian/copyright'

cat << '_EOF_' > raspberrypi-sys-mods/usr/lib/raspberrypi-sys-mods/i2cprobe
#!/bin/dash
ALIASES="/lib/modules/$(uname -r)/modules.alias"
n=0
while :; do
	eval "comp=\"\$OF_COMPATIBLE_$n\""
	comp=$(echo "$comp" | sed 's/.*,//')
	if [ -z "$comp" ]; then
		break
	fi
	if grep -q "alias $SUBSYSTEM:$comp " $ALIASES; then
		modprobe "$SUBSYSTEM:$comp" && exit 0
	fi
	n=$(expr $n + 1)
done
modprobe "$MODALIAS" || modprobe "of:N${OF_NAME}T<NULL>C$OF_COMPATIBLE_0"
_EOF_
G_EXEC chmod +x raspberrypi-sys-mods/usr/lib/raspberrypi-sys-mods/i2cprobe

G_EXEC curl -sSfo raspberrypi-sys-mods/lib/udev/rules.d/15-i2c-modprobe.rules 'https://raw.githubusercontent.com/RPi-Distro/raspberrypi-sys-mods/master/lib/udev/rules.d/15-i2c-modprobe.rules'

G_EXEC curl -sSfo raspberrypi-sys-mods/lib/udev/rules.d/99-com.rules 'https://raw.githubusercontent.com/RPi-Distro/raspberrypi-sys-mods/master/etc.armhf/udev/rules.d/99-com.rules'
# The original rule uses the "strings" command from binutils, which we do not want to have pre-installed (it is huge!). So we use cat, which is safe for the node values read here.
G_EXEC sed --follow-symlinks -i 's/(strings/(cat/g' raspberrypi-sys-mods/lib/udev/rules.d/99-com.rules

cat << '_EOF_' > raspberrypi-sys-mods/DEBIAN/preinst
#!/bin/dash
groupadd -rf spi
groupadd -rf i2c
groupadd -rf gpio
_EOF_
G_EXEC chmod +x raspberrypi-sys-mods/DEBIAN/preinst

find raspberrypi-sys-mods ! \( -path raspberrypi-sys-mods/DEBIAN -prune \) -type f -exec md5sum {} + | sed 's|raspberrypi-sys-mods/||' > raspberrypi-sys-mods/DEBIAN/md5sums

cat << _EOF_ > raspberrypi-sys-mods/DEBIAN/control
Package: raspberrypi-sys-mods
Version: 2:20230510-dietpi2
Architecture: all
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -uR)
Installed-Size: $(du -sk raspberrypi-sys-mods | mawk '{print $1}')
Section: admin
Priority: optional
Homepage: https://github.com/RPi-Distro/raspberrypi-sys-mods
Description: System tweaks for the Raspberry Pi, DietPi edition
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk raspberrypi-sys-mods | mawk '{print $1}')" raspberrypi-sys-mods/DEBIAN/control

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b -Zxz -z9 raspberrypi-sys-mods

# Cleanup
G_EXEC rm -R raspberrypi-sys-mods
}
