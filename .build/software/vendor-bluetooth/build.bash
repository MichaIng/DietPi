#!/bin/bash
{
if [[ -f '/boot/dietpi/func/dietpi-globals' ]]
then
	. /boot/dietpi/func/dietpi-globals || exit 1
else
	# shellcheck disable=SC1090
	. <(curl -sSf "https://raw.githubusercontent.com/${G_GITOWNER:-MichaIng}/DietPi/${G_GITBRANCH:-master}/dietpi/func/dietpi-globals") || exit 1
fi

# Bluetooth UART attach services for Orange Pi SBCs with WiFi/BT modules handled by vendor drivers, where the kernel does not attach the Bluetooth controller itself via serdev. All use BlueZ tools only:
# - sprd-bluetooth: UNISOC/Spreadtrum UWE5622 (Orange Pi Zero 3/Zero 2W/3B v1.1/3 LTS/3/4 LTS)
# - aic8800-bluetooth: AICSemi AIC8800 (Orange Pi 4 Pro/Zero 3W/Zero 4)
# NB: AMPAK AP6611S on Orange Pi 5 Max/Ultra is attached by the kernel via serdev/hci_bcm, configured in the device tree.

# $1: Package name, equals the systemd service name
# $2: Package version
# $3: Package description
# $4: Package homepage
Build_DEB()
{
	local name=$1

	# Control files
	# - postinst
	cat << _EOF_ > "$name/DEBIAN/postinst" || exit 1
#!/bin/dash -e
if [ -d '/run/systemd/system' ]
then
	echo 'Configuring $name systemd service ...'
	systemctl --no-reload unmask $name
	systemctl enable $name
	systemctl --no-block restart $name
fi
_EOF_

	# - prerm
	cat << _EOF_ > "$name/DEBIAN/prerm" || exit 1
#!/bin/dash -e
if [ "\$1" = 'remove' ] && [ -d '/run/systemd/system' ] && [ -f '/lib/systemd/system/$name.service' ]
then
	echo 'Deconfiguring $name systemd service ...'
	systemctl --no-reload unmask $name
	systemctl --no-reload disable --now $name
fi
_EOF_

	# - postrm
	cat << _EOF_ > "$name/DEBIAN/postrm" || exit 1
#!/bin/dash -e
if [ "\$1" = 'purge' ] && [ -d '/etc/systemd/system/$name.service.d' ]
then
	echo 'Removing $name systemd service overrides ...'
	rm -Rv /etc/systemd/system/$name.service.d
fi
_EOF_

	G_EXEC chmod +x "$name/DEBIAN/"{postinst,prerm,postrm}

	# - md5sums
	find "$name" ! \( -path "$name/DEBIAN" -prune \) -type f -exec md5sum {} + | sed "s|$name/||" > "$name/DEBIAN/md5sums" || exit 1

	# - control
	cat << _EOF_ > "$name/DEBIAN/control" || exit 1
Package: $name
Version: $2
Architecture: all
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -uR)
Installed-Size: 0
Depends: bluez
Section: admin
Priority: optional
Homepage: $4
Description: $3
_EOF_
	G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$name" | mawk '{print $1}')" "$name/DEBIAN/control"

	# Build DEB package
	G_EXEC_OUTPUT=1 G_EXEC dpkg-deb --root-owner-group -b "$name"
}

# UNISOC/Spreadtrum UWE5622
# - /dev/ttyBT0 is no UART, but a virtual TTY on top of SDIO, provided by the sprdbt_tty kernel module.
# - Since https://github.com/armbian/uwe5622/commit/9052211, sprdbt_tty does the vendor init (PSKEY, RF and BD address from addr_mgt), when the Bluetooth rfkill switch gets unblocked. This needs to happen before attaching the HCI line discipline, hence BlueZ btattach is all what is needed.
name='sprd-bluetooth'
G_DIETPI-NOTIFY 2 "Building $name package"
[[ -d $name ]] && G_EXEC rm -R "$name"
G_EXEC mkdir -p "$name/"{DEBIAN,lib/systemd/system}
cat << '_EOF_' > "$name/lib/systemd/system/$name.service" || exit 1
[Unit]
Description=UNISOC/Spreadtrum Bluetooth support
BindsTo=dev-ttyBT0.device
After=dev-ttyBT0.device systemd-rfkill.service bluetooth.service

[Service]
ExecStartPre=/bin/dash -c 'read -r v < /sys/module/sprdbt_tty/parameters/vendor_init && [ "$$v" = Y ] || { echo "The sprdbt_tty kernel module does not support or has disabled the in-kernel vendor init"; exit 1; }'
ExecStartPre=/bin/dash -c 'for r in /sys/class/rfkill/rfkill*; do read -r t < "$$r/type"; [ "$$t" = bluetooth ] || continue; echo 0 > "$$r/soft"; read -r b < "$$r/soft"; [ "$$b" = 0 ] || { echo "Failed to unblock $${r##*/}, the vendor init failed"; exit 1; }; done'
ExecStart=/usr/bin/btattach -B /dev/ttyBT0 -P h4

[Install]
WantedBy=multi-user.target
_EOF_
Build_DEB "$name" '0.1.0' 'UNISOC/Spreadtrum Bluetooth support' 'https://github.com/armbian/uwe5622'

# AICSemi AIC8800
# - The aicbsp kernel module loads the Bluetooth firmware patch via SDIO, configured for 1500000 baud with flow control and low-power mode enabled.
# - The aic8800_btlpm kernel module of the Xunlong sun60iw2 vendor kernel drives the BT_WAKE GPIO, deasserted on load. It is written for Android Bluedroid, which asserts it via /proc/bluetooth/sleep/btwrite before sending data. BlueZ does not, hence assert it once, to keep the Bluetooth core awake. Else it does not respond to the HCI reset.
# - The hciattach_opi "aic" type additionally sends vendor commands for BD address, AON and low-power parameters, but the controller works without them, with its own BD address.
name='aic8800-bluetooth'
G_DIETPI-NOTIFY 2 "Building $name package"
[[ -d $name ]] && G_EXEC rm -R "$name"
G_EXEC mkdir -p "$name/"{DEBIAN,lib/systemd/system}
cat << '_EOF_' > "$name/lib/systemd/system/$name.service" || exit 1
[Unit]
Description=AICSemi AIC8800 Bluetooth support
After=systemd-modules-load.service systemd-rfkill.service bluetooth.service

[Service]
ExecStartPre=/bin/dash -c 'for r in /sys/class/rfkill/rfkill*; do read -r t < "$$r/type"; [ "$$t" = bluetooth ] || continue; echo 0 > "$$r/soft"; done'
ExecStartPre=/bin/dash -c 'for i in 1 2 3 4 5 6 7 8 9 10; do [ -e /proc/bluetooth/sleep/btwrite ] && break; sleep 1; done; echo 1 > /proc/bluetooth/sleep/btwrite'
ExecStart=/usr/bin/btattach -B /dev/ttyS1 -P h4 -S 1500000

[Install]
WantedBy=multi-user.target
_EOF_
Build_DEB "$name" '0.0.1' 'AICSemi AIC8800 Bluetooth support' 'https://github.com/MichaIng/DietPi'

exit 0
}
