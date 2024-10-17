#!/bin/bash
{
	#////////////////////////////////////
	# DietPi FirstBoot Script
	#
	#////////////////////////////////////
	# Created by Frederic Guilbault / fred@0464.ca
	#
	#////////////////////////////////////
	#
	# Info:
	# - Location: /var/lib/dietpi/services/dietpi-firstboot.bash
	# - Activates on first boot from dietpi-firstboot.service, runs before dietpi-boot.service and networking
	#////////////////////////////////////

	# Import DietPi-Globals --------------------------------------------------------------
	. /boot/dietpi/func/dietpi-globals
	readonly G_PROGRAM_NAME='DietPi-FirstBoot'
	G_CHECK_ROOT_USER
	G_CHECK_ROOTFS_RW
	G_INIT
	# Import DietPi-Globals --------------------------------------------------------------

	#/////////////////////////////////////////////////////////////////////////////////////
	# Globals
	#/////////////////////////////////////////////////////////////////////////////////////

	RPi_Set_Clock_Speeds()
	{
		# Update comments to show model-specific defaults and apply safe overclocking profile on RPi 1: https://github.com/raspberrypi/documentation/blob/develop/documentation/asciidoc/computers/config_txt/overclocking.adoc

		# RPi Zero/Zero 2 W
		if [[ $G_HW_MODEL_NAME == *'Zero'* ]]
		then
			sed --follow-symlinks -i '/^#over_voltage=/c\#over_voltage=0' /boot/config.txt
			sed --follow-symlinks -i '/^#arm_freq=/c\#arm_freq=1000' /boot/config.txt
			sed --follow-symlinks -i '/^#core_freq=/c\#core_freq=400' /boot/config.txt
			sed --follow-symlinks -i '/^#sdram_freq=/c\#sdram_freq=450' /boot/config.txt

		# RPi 1: Apply safe overclock mode
		elif (( $G_HW_MODEL < 2 ))
		then
			GCI_PRESERVE=1 G_CONFIG_INJECT 'arm_freq=' 'arm_freq=900' /boot/config.txt
			grep -q '^arm_freq=900$' /boot/config.txt && G_CONFIG_INJECT 'over_voltage=' 'over_voltage=2' /boot/config.txt
			sed --follow-symlinks -i '/^#core_freq=/c\#core_freq=250' /boot/config.txt
			sed --follow-symlinks -i '/^#sdram_freq=/c\#sdram_freq=400' /boot/config.txt

		# RPi 2
		elif (( $G_HW_MODEL == 2 ))
		then
			sed --follow-symlinks -i '/^#over_voltage=/c\#over_voltage=0' /boot/config.txt
			sed --follow-symlinks -i '/^#arm_freq=/c\#arm_freq=900' /boot/config.txt
			sed --follow-symlinks -i '/^#core_freq=/c\#core_freq=250' /boot/config.txt
			sed --follow-symlinks -i '/^#sdram_freq=/c\#sdram_freq=450' /boot/config.txt

		# RPi 3
		elif (( $G_HW_MODEL == 3 ))
		then
			sed --follow-symlinks -i '/^#over_voltage=/c\#over_voltage=0' /boot/config.txt
			sed --follow-symlinks -i '/^#core_freq=/c\#core_freq=400' /boot/config.txt
			grep -q '^temp_limit=65$' /boot/config.txt && G_CONFIG_INJECT 'temp_limit=' 'temp_limit=75' /boot/config.txt # https://github.com/MichaIng/DietPi/issues/356

			# A+/B+
			if [[ $G_HW_MODEL_NAME == *'+'* ]]
			then
				sed --follow-symlinks -i '/^#arm_freq=/c\#arm_freq=1400' /boot/config.txt
				sed --follow-symlinks -i '/^#sdram_freq=/c\#sdram_freq=500' /boot/config.txt
			else
				sed --follow-symlinks -i '/^#arm_freq=/c\#arm_freq=1200' /boot/config.txt
				sed --follow-symlinks -i '/^#sdram_freq=/c\#sdram_freq=450' /boot/config.txt
			fi

		# RPi 4
		elif (( $G_HW_MODEL == 4 ))
		then
			sed --follow-symlinks -i '/^#over_voltage=/c\#over_voltage=0' /boot/config.txt
			sed --follow-symlinks -i '/^#core_freq=/c\#core_freq=500' /boot/config.txt
			sed --follow-symlinks -i '/^#sdram_freq=/d' /boot/config.txt # Not supported on RPi 4, defaults to 3200 MHz
			grep -q '^temp_limit=65$' /boot/config.txt && G_CONFIG_INJECT 'temp_limit=' 'temp_limit=75' /boot/config.txt # https://github.com/MichaIng/DietPi/issues/3019

			# 400
			if [[ $G_HW_MODEL_NAME == *'400'* ]]
			then
				sed --follow-symlinks -i '/^#arm_freq=/c\#arm_freq=1800' /boot/config.txt
			else
				sed --follow-symlinks -i '/^#arm_freq=/c\#arm_freq=1500' /boot/config.txt
			fi

		# RPi 5
		elif (( $G_HW_MODEL == 5 ))
		then
			sed --follow-symlinks -i '/^#over_voltage=/c\#over_voltage=0' /boot/config.txt
			sed --follow-symlinks -i '/^#arm_freq=/c\#arm_freq=2400' /boot/config.txt
			sed --follow-symlinks -i '/^#core_freq=/c\#core_freq=910' /boot/config.txt
			sed --follow-symlinks -i '/^#sdram_freq=/d' /boot/config.txt # Not supported on RPi 5, defaults to 4267 MHz
			grep -q '^temp_limit=65$' /boot/config.txt && G_CONFIG_INJECT 'temp_limit=' 'temp_limit=75' /boot/config.txt # https://github.com/MichaIng/DietPi/issues/3019
		fi
	}

	Apply_DietPi_FirstRun_Settings(){

		# RPi: Apply safe overclocking values or update comments to show model-specific defaults
		if (( $G_HW_MODEL < 10 ))
		then
			RPi_Set_Clock_Speeds

		# VisionFive 2
		elif [[ $G_HW_MODEL == 81 && -f '/proc/device-tree/serial-number' && -f '/boot/extlinux/extlinux.conf' ]] && ! grep -q '^[[:blank:]]*fdtoverlays[[:blank:]]' /boot/extlinux/extlinux.conf
		then
			local serial overlays=()
			read -r serial < /proc/device-tree/serial-number
			if [[ $serial == 'VF7110A1-'* ]]
			then
				G_DIETPI-NOTIFY 2 'A revision detected, applying device tree overlay to fix Ethernet ...'
				read -ra overlays < <(mawk '$1=="fdtoverlays"{$1="";print}' /boot/extlinux/extlinux.conf)
				local i=
				for i in "${overlays[@]}"; do [[ $i == *'/ethernet-A12.dtbo' ]] && break; done
				if [[ $i == *'/ethernet-A12.dtbo' ]]
				then
					G_DIETPI-NOTIFY 2 'A revision Ethernet overlay was applied already ...'
				else
					overlays+=('/usr/lib/linux-image-visionfive2/starfive/vf2-overlay/ethernet-A12.dtbo')
					G_CONFIG_INJECT 'fdtoverlays[[:blank:]]' "fdtoverlays ${overlays[*]}" /boot/extlinux/extlinux.conf
				fi
			fi
			if [[ $serial == *'-D008E000-'* ]]
			then
				G_DIETPI-NOTIFY 2 '8 GB RAM model detected, applying device tree overlay to make all 8 GB available to the system ...'
				read -ra overlays < <(mawk '$1=="fdtoverlays"{$1="";print}' /boot/extlinux/extlinux.conf)
				local i=
				for i in "${overlays[@]}"; do [[ $i == *'/8GB.dtbo' ]] && break; done
				if [[ $i == *'/8GB.dtbo' ]]
				then
					G_DIETPI-NOTIFY 2 '8 GB RAM overlay was applied already ...'
				else
					overlays+=('/usr/lib/linux-image-visionfive2/starfive/vf2-overlay/8GB.dtbo')
					G_CONFIG_INJECT 'fdtoverlays[[:blank:]]' "fdtoverlays ${overlays[*]}" /boot/extlinux/extlinux.conf
				fi
			fi
			grep -q '^[[:blank:]]*fdtoverlays[[:blank:]]' /boot/extlinux/extlinux.conf && { reboot; exit 0; }
		fi

		# End user automated script
		if [[ -f '/boot/Automation_Custom_PreScript.sh' ]]
		then
			G_DIETPI-NOTIFY 2 'Running custom script, please wait ...'
			chmod +x /boot/Automation_Custom_PreScript.sh
			if /boot/Automation_Custom_PreScript.sh 2>&1 | tee /var/tmp/dietpi/logs/dietpi-automation_custom_prescript.log
			then
				G_DIETPI-NOTIFY 0 'Custom script'
			else
				G_DIETPI-NOTIFY 1 'Custom script: Please see the log file for more information:
         - /var/tmp/dietpi/logs/dietpi-automation_custom_prescript.log'
			fi
		fi

		# Apply swap settings
		/boot/dietpi/func/dietpi-set_swapfile

		# Apply headless mode if set in dietpi.txt (RPi, Odroid C1/C2)
		(( $G_HW_MODEL < 11 || $G_HW_MODEL == 12 )) && /boot/dietpi/func/dietpi-set_hardware headless "$(grep -cm1 '^[[:blank:]]*AUTO_SETUP_HEADLESS=1' /boot/dietpi.txt)"

		# Set hostname
		/boot/dietpi/func/change_hostname "$(sed -n '/^[[:blank:]]*AUTO_SETUP_NET_HOSTNAME=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)"

		if grep -q '^[[:blank:]]*AUTO_SETUP_AUTOMATED=1' /boot/dietpi.txt
		then
			# Enable root autologin on local console (/dev/tty1) and container console (/dev/console), overwritten during 1st run setup
			mkdir -p /etc/systemd/system/{getty@tty1,console-getty}.service.d
			cat << '_EOF_' > /etc/systemd/system/getty@tty1.service.d/dietpi-autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -a root -J %I $TERM
_EOF_
			cat << '_EOF_' > /etc/systemd/system/console-getty.service.d/dietpi-autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -a root -J -s console 115200,38400,9600 $TERM
_EOF_
		fi

		# Apply login password if it has not been encrypted before to avoid applying the informational text
		if [[ ! -f '/var/lib/dietpi/dietpi-software/.GLOBAL_PW.bin' ]]
		then
			local password=$(sed -n '/^[[:blank:]]*AUTO_SETUP_GLOBAL_PASSWORD=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
			if [[ $password ]]
			then
				chpasswd <<< "root:$password"
				chpasswd <<< "dietpi:$password"
			fi
			unset -v password
		fi

		# Set APT mirror
		local target_repo='CONFIG_APT_DEBIAN_MIRROR'
		(( $G_RASPBIAN )) && target_repo='CONFIG_APT_RASPBIAN_MIRROR'
		/boot/dietpi/func/dietpi-set_software apt-mirror "$(sed -n "/^[[:blank:]]*$target_repo=/{s/^[^=]*=//p;q}" /boot/dietpi.txt)"

		# Recreate machine-id: https://github.com/MichaIng/DietPi/issues/2015
		[[ -f '/etc/machine-id' ]] && rm /etc/machine-id
		[[ -f '/var/lib/dbus/machine-id' ]] && rm /var/lib/dbus/machine-id
		systemd-machine-id-setup

		# Apply time zone
		local autoinstall_timezone=$(sed -n '/^[[:blank:]]*AUTO_SETUP_TIMEZONE=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
		if [[ -f /usr/share/zoneinfo/$autoinstall_timezone && $autoinstall_timezone != $(</etc/timezone) ]]; then

			G_DIETPI-NOTIFY 2 "Setting time zone $autoinstall_timezone. Please wait..."
			rm -fv /etc/{timezoner,localtime}
			ln -s "/usr/share/zoneinfo/$autoinstall_timezone" /etc/localtime
			dpkg-reconfigure -f noninteractive tzdata

		fi

		# Apply language (locale)
		local autoinstall_language=$(sed -n '/^[[:blank:]]*AUTO_SETUP_LOCALE=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
		grep -q "^$autoinstall_language UTF-8$" /usr/share/i18n/SUPPORTED || autoinstall_language='C.UTF-8'
		if ! locale | grep -qE "(LANG|LC_ALL)=[\'\"]?${autoinstall_language}[\'\"]?" || ! locale -a | grep -qiE 'C\.UTF-?8'; then

			G_DIETPI-NOTIFY 2 "Setting locale $autoinstall_language. Please wait..."
			/boot/dietpi/func/dietpi-set_software locale "$autoinstall_language"

		fi

		# Skip keyboard, SSH, serial console and network setup on container systems
		(( $G_HW_MODEL == 75 )) && return 0

		# Apply keyboard layout
		local autoinstall_keyboard=$(sed -n '/^[[:blank:]]*AUTO_SETUP_KEYBOARD_LAYOUT=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
		if [[ $autoinstall_keyboard ]] && ! grep -q "XKBLAYOUT=\"$autoinstall_keyboard\"" /etc/default/keyboard; then

			G_DIETPI-NOTIFY 2 "Setting keyboard layout $autoinstall_keyboard. Please wait..."
			G_CONFIG_INJECT 'XKBLAYOUT=' "XKBLAYOUT=\"$autoinstall_keyboard\"" /etc/default/keyboard
			setupcon --save # https://bugs.debian.org/818065

		fi

		# Disable serial console if set in dietpi.txt
		grep -q '^[[:blank:]]*CONFIG_SERIAL_CONSOLE_ENABLE=0' /boot/dietpi.txt && /boot/dietpi/func/dietpi-set_hardware serialconsole disable

		# Regenerate unique Dropbear host keys
		local i type
		for i in /etc/dropbear/dropbear_*_host_key
		do
			type=${i#/etc/dropbear/dropbear_}
			type=${type%_host_key}
			rm -v "$i"
			dropbearkey -t "$type" -f "$i"
		done

		# Apply SSH pubkey(s) from dietpi.txt
		/boot/dietpi/func/dietpi-set_software add_ssh_pubkeys

		# Apply SSH password login setting
		/boot/dietpi/func/dietpi-set_software disable_ssh_password_logins

		# Apply forced Ethernet link speed if set in dietpi.txt
		/boot/dietpi/func/dietpi-set_hardware eth-forcespeed "$(sed -n '/^[[:blank:]]*AUTO_SETUP_NET_ETH_FORCE_SPEED=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)"

		# Network setup
		# - Grab available network interfaces
		local iface_eth=$(G_GET_NET -q -t eth iface)
		[[ $iface_eth ]] || iface_eth='eth0'
		local iface_wlan=$(G_GET_NET -q -t wlan iface)
		[[ $iface_wlan ]] || iface_wlan='wlan0'

		# - Replace interface names with the ones obtained above
		sed --follow-symlinks -i "s/eth[0-9]/$iface_eth/g" /etc/network/interfaces
		sed --follow-symlinks -i "s/wlan[0-9]/$iface_wlan/g" /etc/network/interfaces

		# - Grab user requested settings from dietpi.txt
		local ethernet_enabled=$(grep -cm1 '^[[:blank:]]*AUTO_SETUP_NET_ETHERNET_ENABLED=1' /boot/dietpi.txt)
		local wifi_enabled=$(grep -cm1 '^[[:blank:]]*AUTO_SETUP_NET_WIFI_ENABLED=1' /boot/dietpi.txt)
		local use_static=$(grep -cm1 '^[[:blank:]]*AUTO_SETUP_NET_USESTATIC=1' /boot/dietpi.txt)
		local static_ip=$(sed -n '/^[[:blank:]]*AUTO_SETUP_NET_STATIC_IP=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
		local static_mask=$(sed -n '/^[[:blank:]]*AUTO_SETUP_NET_STATIC_MASK=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
		local static_gateway=$(sed -n '/^[[:blank:]]*AUTO_SETUP_NET_STATIC_GATEWAY=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
		local static_dns=$(sed -n '/^[[:blank:]]*AUTO_SETUP_NET_STATIC_DNS=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)

		# - WiFi
		if (( $wifi_enabled )); then

			# Enable WiFi, disable Ethernet
			ethernet_enabled=0
			sed --follow-symlinks -Ei "/(allow-hotplug|auto)[[:blank:]]+wlan/c\allow-hotplug $iface_wlan" /etc/network/interfaces
			sed --follow-symlinks -Ei "/(allow-hotplug|auto)[[:blank:]]+eth/c\#allow-hotplug $iface_eth" /etc/network/interfaces

			# Apply global SSID/keys from dietpi.txt to wpa_supplicant
			/boot/dietpi/func/dietpi-wifidb 1

			# Set WiFi country code
			/boot/dietpi/func/dietpi-set_hardware wificountrycode

		# - Ethernet
		elif (( $ethernet_enabled )); then

			# Enable Ethernet, disable WiFi
			wifi_enabled=0
			sed --follow-symlinks -Ei "/(allow-hotplug|auto)[[:blank:]]+eth/c\allow-hotplug $iface_eth" /etc/network/interfaces
			sed --follow-symlinks -Ei "/(allow-hotplug|auto)[[:blank:]]+wlan/c\#allow-hotplug $iface_wlan" /etc/network/interfaces

			# Disable WiFi kernel modules
			/boot/dietpi/func/dietpi-set_hardware wifimodules disable

			# RPi: Keep onboard WiFi enabled until end of first run installs: https://github.com/MichaIng/DietPi/issues/5391
			(( $G_HW_MODEL > 9 )) || /boot/dietpi/func/dietpi-set_hardware wifimodules onboard_enable

		fi

		# - Static IP
		if (( $use_static )); then

			if (( $wifi_enabled )); then

				sed --follow-symlinks -i "/iface wlan/c\iface $iface_wlan inet static" /etc/network/interfaces

			elif (( $ethernet_enabled )); then

				sed --follow-symlinks -i "/iface eth/c\iface $iface_eth inet static" /etc/network/interfaces

			fi
			sed --follow-symlinks -i "/address/c\address $static_ip" /etc/network/interfaces
			sed --follow-symlinks -i "/netmask/c\netmask $static_mask" /etc/network/interfaces
			sed --follow-symlinks -i "/gateway/c\gateway $static_gateway" /etc/network/interfaces
			if command -v resolvconf > /dev/null; then

				sed --follow-symlinks -i "/dns-nameservers/c\dns-nameservers $static_dns" /etc/network/interfaces

			else

				> /etc/resolv.conf
				for i in $static_dns; do echo "nameserver $i" >> /etc/resolv.conf; done
				sed --follow-symlinks -i "/dns-nameservers/c\#dns-nameservers $static_dns" /etc/network/interfaces

			fi

		fi

		# - IPv6
		/boot/dietpi/func/dietpi-set_hardware enableipv6 "$(( ! $(grep -cm1 '^[[:blank:]]*CONFIG_ENABLE_IPV6=0' /boot/dietpi.txt) ))"

		# - Configure enabled interfaces now, /etc/network/interfaces will be effective from next boot on
		#	Failsafe: Bring up Ethernet, whenever WiFi is disabled or fails to be configured, e.g. due to wrong credentials
		# shellcheck disable=SC2015
		(( $wifi_enabled )) && ifup "$iface_wlan" || ifup "$iface_eth"

		# - Boot wait for network
		/boot/dietpi/func/dietpi-set_software boot_wait_for_network "$(( ! $(grep -cm1 '^[[:blank:]]*AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=0' /boot/dietpi.txt) ))"

		# Apply network time sync mirror and force sync now to speed up first run setup
		/boot/dietpi/func/dietpi-set_software timesync-mirror
		systemctl restart systemd-timesyncd

		# x86_64 BIOS: Set GRUB install device: https://github.com/MichaIng/DietPi/issues/4542
		if (( $G_HW_MODEL == 10 )) && dpkg-query -s grub-pc &> /dev/null
		then
			local root_drive=$(lsblk -npo PKNAME "$(findmnt -Ufnro SOURCE -M /)")
			[[ $root_drive == '/dev/'* ]] && debconf-set-selections <<< "grub-pc grub-pc/install_devices multiselect $root_drive"
		fi

	}

	#/////////////////////////////////////////////////////////////////////////////////////
	# Main Loop
	#/////////////////////////////////////////////////////////////////////////////////////

	# Failsafe: https://github.com/MichaIng/DietPi/issues/3646#issuecomment-653739919
	chown root:root /
	chmod 0755 /

	# Apply dietpi.txt settings and reset hardware ID + SSH host keys
	Apply_DietPi_FirstRun_Settings

	# Set install stage index to trigger automated DietPi-Update on login
	echo 0 > /boot/dietpi/.install_stage

	# Disable originating service to prevent any further launch of this script
	systemctl disable dietpi-firstboot
	#-----------------------------------------------------------------------------------
	exit 0
	#-----------------------------------------------------------------------------------
}
