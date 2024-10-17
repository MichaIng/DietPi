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

G_EXEC mkdir -p sprd-bluetooth/{DEBIAN,usr/bin,lib/systemd/system}

G_EXEC curl -fo sprd-bluetooth/usr/bin/hciattach_opi 'https://raw.githubusercontent.com/orangepi-xunlong/orangepi-build/next/external/packages/blobs/bt/hciattach/hciattach_opi_arm64'
G_EXEC chmod +x sprd-bluetooth/usr/bin/hciattach_opi
cat << '_EOF_' > sprd-bluetooth/lib/systemd/system/sprd-bluetooth.service
[Unit]
Description=Spreadtrum (sprd) Bluetooth support
After=bluetooth.service

[Service]
RemainAfterExit=yes
ExecStart=/usr/bin/hciattach_opi -n -s 1500000 /dev/ttyBT0 sprd

[Install]
WantedBy=multi-user.target
_EOF_

# Control files
# - postinst
cat << '_EOF_' > sprd-bluetooth/DEBIAN/postinst
#!/bin/sh
if [ -d '/run/systemd/system' ]
then
	echo 'Configuring sprd-bluetooth systemd service ...'
	systemctl unmask sprd-bluetooth
	systemctl enable --now sprd-bluetooth
fi
_EOF_

# - prerm
cat << '_EOF_' > sprd-bluetooth/DEBIAN/prerm
#!/bin/sh
if [ "$1" = 'remove' ] && [ -d '/run/systemd/system' ]
then
	if [ -f '/lib/systemd/system/sprd-bluetooth.service' ]
	then
		echo 'Deconfiguring sprd-bluetooth systemd service ...'
		systemctl unmask sprd-bluetooth
		systemctl disable --now sprd-bluetooth
	fi
fi
_EOF_

# - postrm
cat << '_EOF_' > sprd-bluetooth/DEBIAN/postrm
#!/bin/sh
if [ "$1" = 'purge' ]
then
	if [ -d '/etc/systemd/system/sprd-bluetooth.service.d' ]
	then
		echo 'Removing sprd-bluetooth systemd service overrides ...'
		rm -Rv /etc/systemd/system/sprd-bluetooth.service.d
	fi
fi
_EOF_

G_EXEC chmod +x sprd-bluetooth/DEBIAN/{postinst,prerm,postrm}

# - md5sums
find sprd-bluetooth ! \( -path sprd-bluetooth/DEBIAN -prune \) -type f -exec md5sum {} + | sed 's|sprd-bluetooth/||' > sprd-bluetooth/DEBIAN/md5sums

# - control
cat << _EOF_ > sprd-bluetooth/DEBIAN/control
Package: sprd-bluetooth
Version: 0.0.1
Architecture: arm64
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -uR)
Installed-Size: $(du -sk sprd-bluetooth | mawk '{print $1}')
Section: admin
Priority: optional
Homepage: https://github.com/orangepi-xunlong/orangepi-build/tree/next/external/packages/blobs/bt/hciattach
Description: Spreadtrum (sprd) Bluetooth support
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk sprd-bluetooth | mawk '{print $1}')" sprd-bluetooth/DEBIAN/control

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b -Zxz -z9 sprd-bluetooth

# Cleanup
G_EXEC rm -R sprd-bluetooth
}
