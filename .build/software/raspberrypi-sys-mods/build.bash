#!/bin/bash
{
if [[ -f '/boot/dietpi/func/dietpi-globals' ]]
then
	. /boot/dietpi/func/dietpi-globals || exit 1
else
	# shellcheck disable=SC1090
	. <(curl -sSf "https://raw.githubusercontent.com/${G_GITOWNER:-MichaIng}/DietPi/${G_GITBRANCH:-master}/dietpi/func/dietpi-globals") || exit 1
fi

### data files

# Create directories
[[ -d 'raspberrypi-sys-mods' ]] && G_EXEC rm -R raspberrypi-sys-mods
G_EXEC mkdir -p raspberrypi-sys-mods/{usr/lib/udev/rules.d,usr/{lib,share/doc}/raspberrypi-sys-mods}
G_EXEC cd raspberrypi-sys-mods

# copyright
G_EXEC curl -sSfo usr/share/doc/raspberrypi-sys-mods/copyright 'https://raw.githubusercontent.com/RPi-Distro/raspberrypi-sys-mods/pios/trixie/debian/copyright'

# Grant "video" group access to VideoCore devices
G_EXEC curl -sSfo usr/lib/udev/rules.d/10-vc.rules 'https://raw.githubusercontent.com/RPi-Distro/raspberrypi-sys-mods/pios/trixie/usr/lib/udev/rules.d/10-vc.rules'

# Automatically load kernel modules for attached I2C and SPI devices
cat << '_EOF_' > usr/lib/raspberrypi-sys-mods/i2cprobe
#!/bin/dash
ALIASES="/lib/modules/$(uname -r)/modules.alias"
n=0
while :; do
	eval "comp=\"\${OF_COMPATIBLE_$n##*,}\""
	[ -n "$comp" ] || break
	if grep -q "alias $SUBSYSTEM:$comp " "$ALIASES"; then
		modprobe "$SUBSYSTEM:$comp" && exit 0
	fi
	n=$(expr "$n" + 1)
done
modprobe "$MODALIAS" || modprobe "of:N${OF_NAME}T<NULL>C$OF_COMPATIBLE_0"
_EOF_
G_EXEC chmod +x usr/lib/raspberrypi-sys-mods/i2cprobe
G_EXEC curl -sSfo usr/lib/udev/rules.d/15-i2c-modprobe.rules 'https://raw.githubusercontent.com/RPi-Distro/raspberrypi-sys-mods/pios/trixie/usr/lib/udev/rules.d/15-i2c-modprobe.rules'

# Grant "video" group access to DMA heap buffer and create symlink for libcamera tools
G_EXEC curl -sSfo usr/lib/udev/rules.d/60-dma-heap.rules 'https://raw.githubusercontent.com/RPi-Distro/raspberrypi-sys-mods/pios/trixie/usr/lib/udev/rules.d/60-dma-heap.rules'

# Add "gpiochip4" symlink
G_EXEC curl -sSfo usr/lib/udev/rules.d/60-gpiochip4.rules 'https://raw.githubusercontent.com/RPi-Distro/raspberrypi-sys-mods/pios/trixie/usr/lib/udev/rules.d/60-gpiochip4.rules'

# Add I2C device aliases and grant access to "i2c" group
G_EXEC curl -sSfo usr/lib/udev/rules.d/60-i2c-aliases.rules 'https://raw.githubusercontent.com/RPi-Distro/raspberrypi-sys-mods/pios/trixie/usr/lib/udev/rules.d/60-i2c-aliases.rules'

# Grand PIO device access to "gpio" group
G_EXEC curl -sSfo usr/lib/udev/rules.d/60-piolib.rules 'https://raw.githubusercontent.com/RPi-Distro/raspberrypi-sys-mods/pios/trixie/usr/lib/udev/rules.d/60-piolib.rules'

# Make systemd create DRM device units so other systemd units can depend/order themselves on them
G_EXEC curl -sSfo usr/lib/udev/rules.d/61-drm.rules 'https://raw.githubusercontent.com/RPi-Distro/raspberrypi-sys-mods/pios/trixie/usr/lib/udev/rules.d/61-drm.rules'

# Further GPIO/I2C/SPI/VideoCore group permissions and serial device symlinks
G_EXEC curl -sSfo usr/lib/udev/rules.d/99-com.rules 'https://raw.githubusercontent.com/RPi-Distro/raspberrypi-sys-mods/pios/trixie/usr/lib/udev/rules.d/99-com.rules'
# - The original rules use the "strings" command from binutils, which we do not want to have pre-installed (it is huge!). So we use "cat", which works for the values expected here.
G_EXEC sed --follow-symlinks -i 's/(strings/(cat/g' usr/lib/udev/rules.d/99-com.rules

### control files

G_EXEC mkdir DEBIAN
find . -type f ! -name md5sums -exec md5sum {} + | sed 's|\./||' > DEBIAN/md5sums

# Assure RPi-specific system groups used in above udev rules exist
cat << '_EOF_' > DEBIAN/preinst
#!/bin/dash
groupadd -rf gpio
groupadd -rf i2c
groupadd -rf spi
_EOF_
G_EXEC chmod +x DEBIAN/preinst

cat << _EOF_ > DEBIAN/control
Package: raspberrypi-sys-mods
Version: 2:20251027-dietpi1
Architecture: all
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -uR)
Installed-Size: $(du -sk | mawk '{print $1}')
Section: admin
Priority: optional
Homepage: https://github.com/RPi-Distro/raspberrypi-sys-mods
Description: System tweaks for the Raspberry Pi, DietPi edition
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk | mawk '{print $1}')" DEBIAN/control

# Build DEB package
G_EXEC cd ..
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb --root-owner-group -Zxz -z9 -Sextreme --uniform-compression -b raspberrypi-sys-mods
}
