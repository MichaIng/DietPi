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
		# If no manual overclock settings have been applied by user, apply safe overclocking values (RPi1) or update comments to show model-specific defaults: https://www.raspberrypi.org/documentation/configuration/config-txt/overclocking.md
		grep -qE '^[[:blank:]]*(over_voltage|(arm|core|gpu|sdram)_freq)=' /boot/config.txt && return

		# RPi Zero
		if [[ $G_HW_MODEL_NAME == *'Zero'* ]]
		then
			sed -i '/#over_voltage=/c\#over_voltage=0' /boot/config.txt
			sed -i '/#arm_freq=/c\#arm_freq=1000' /boot/config.txt
			sed -i '/#core_freq=/c\#core_freq=400' /boot/config.txt
			sed -i '/#sdram_freq=/c\#sdram_freq=450' /boot/config.txt

		# RPi 1: Apply safe overclock mode
		elif (( $G_HW_MODEL < 2 ))
		then
			G_CONFIG_INJECT 'over_voltage=' 'over_voltage=2' /boot/config.txt
			G_CONFIG_INJECT 'arm_freq=' 'arm_freq=900' /boot/config.txt
			sed -i '/#core_freq=/c\#core_freq=250' /boot/config.txt
			sed -i '/#sdram_freq=/c\#sdram_freq=400' /boot/config.txt

		# RPi 2
		elif (( $G_HW_MODEL == 2 ))
		then
			sed -i '/#over_voltage=/c\#over_voltage=0' /boot/config.txt
			sed -i '/#arm_freq=/c\#arm_freq=900' /boot/config.txt
			sed -i '/#core_freq=/c\#core_freq=250' /boot/config.txt
			sed -i '/#sdram_freq=/c\#sdram_freq=450' /boot/config.txt

		# RPi 3
		elif (( $G_HW_MODEL == 3 ))
		then
			sed -i '/#over_voltage=/c\#over_voltage=0' /boot/config.txt
			sed -i '/#core_freq=/c\#core_freq=400' /boot/config.txt
			G_CONFIG_INJECT 'temp_limit=' 'temp_limit=75' /boot/config.txt # https://github.com/MichaIng/DietPi/issues/356

			# A+/B+
			if [[ $G_HW_MODEL_NAME == *'+'* ]]
			then
				sed -i '/#arm_freq=/c\#arm_freq=1400' /boot/config.txt
				sed -i '/#sdram_freq=/c\#sdram_freq=500' /boot/config.txt
			else
				sed -i '/#arm_freq=/c\#arm_freq=1200' /boot/config.txt
				sed -i '/#sdram_freq=/c\#sdram_freq=450' /boot/config.txt
			fi

		# RPi 4
		elif (( $G_HW_MODEL == 4 ))
		then
			sed -i '/#over_voltage=/c\#over_voltage=0' /boot/config.txt
			sed -i '/#core_freq=/c\#core_freq=500' /boot/config.txt
			sed -i '/#sdram_freq=/d' /boot/config.txt # Not supported on RPi4, defaults to 3200 MHz
			G_CONFIG_INJECT 'temp_limit=' 'temp_limit=75' /boot/config.txt # https://github.com/MichaIng/DietPi/issues/3019

			# 400
			if [[ $G_HW_MODEL_NAME == *'400'* ]]
			then
				sed -i '/#arm_freq=/c\#arm_freq=1800' /boot/config.txt
			else
				sed -i '/#arm_freq=/c\#arm_freq=1500' /boot/config.txt
			fi
		fi
	}

	Apply_DietPi_FirstRun_Settings(){

		# RPi: Apply safe overclocking values or update comments to show model-specific defaults
		(( $G_HW_MODEL < 10 )) && RPi_Set_Clock_Speeds

		# End user automated script
		if [[ -f '/boot/Automation_Custom_PreScript.sh' ]]; then

			G_DIETPI-NOTIFY 2 'Running custom script, please wait...'
			chmod +x /boot/Automation_Custom_PreScript.sh
			if /boot/Automation_Custom_PreScript.sh 2>&1 | tee /var/tmp/dietpi/logs/dietpi-automation_custom_prescript.log; then

				G_DIETPI-NOTIFY 0 'Custom script'

			else

				G_DIETPI-NOTIFY 1 'Custom script: Please see the log file for more information:
         - /var/tmp/dietpi/logs/dietpi-automation_custom_prescript.log'

			fi

		fi

		# Apply swap settings
		/boot/dietpi/func/dietpi-set_swapfile

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

		# Apply keyboard layout
		local autoinstall_keyboard=$(sed -n '/^[[:blank:]]*AUTO_SETUP_KEYBOARD_LAYOUT=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
		if [[ $autoinstall_keyboard ]] && ! grep -q "XKBLAYOUT=\"$autoinstall_keyboard\"" /etc/default/keyboard; then

			G_DIETPI-NOTIFY 2 "Setting keyboard layout $autoinstall_keyboard. Please wait..."
			G_CONFIG_INJECT 'XKBLAYOUT=' "XKBLAYOUT=\"$autoinstall_keyboard\"" /etc/default/keyboard
			setupcon --save # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=818065

		fi

		# Apply headless mode if set in dietpi.txt (RPi, Odroid C1/C2)
		(( $G_HW_MODEL < 11 || $G_HW_MODEL == 12 )) && /boot/dietpi/func/dietpi-set_hardware headless "$(grep -cm1 '^[[:blank:]]*AUTO_SETUP_HEADLESS=1' /boot/dietpi.txt)"

		# Apply forced eth speed, if set in dietpi.txt
		/boot/dietpi/func/dietpi-set_hardware eth-forcespeed "$(sed -n '/^[[:blank:]]*AUTO_SETUP_NET_ETH_FORCE_SPEED=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)"

		# Set hostname
		/boot/dietpi/func/change_hostname "$(sed -n '/^[[:blank:]]*AUTO_SETUP_NET_HOSTNAME=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)"

		if grep -q '^[[:blank:]]*AUTO_SETUP_AUTOMATED=1' /boot/dietpi.txt; then

			# Enable root autologin on local console (/dev/tty1) and container console (/dev/console), reverted during firstrun setup
			mkdir -p /etc/systemd/system/{getty@tty1,console-getty}.service.d
			cat << '_EOF_' > /etc/systemd/system/getty@tty1.service.d/dietpi-autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -a root --noclear %I $TERM
_EOF_
			cat << '_EOF_' > /etc/systemd/system/console-getty.service.d/dietpi-autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -a root --noclear --keep-baud console 115200,38400,9600 $TERM
_EOF_
			# Assume accepted license in automated installs: https://github.com/MichaIng/DietPi/pull/4477
			rm /var/lib/dietpi/license.txt

		elif grep -q '^[[:blank:]]*AUTO_SETUP_ACCEPT_LICENSE=1' /boot/dietpi.txt; then

			rm /var/lib/dietpi/license.txt

		fi

		# Disable serial console if set in dietpi.txt
		grep -q '^[[:blank:]]*CONFIG_SERIAL_CONSOLE_ENABLE=0' /boot/dietpi.txt && /boot/dietpi/func/dietpi-set_hardware serialconsole disable

		# Apply login password if it has not been encrypted before to avoid applying the informational text
		if [[ ! -f '/var/lib/dietpi/dietpi-software/.GLOBAL_PW.bin' ]]; then

			local password=$(sed -n '/^[[:blank:]]*AUTO_SETUP_GLOBAL_PASSWORD=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
			if [[ $password ]]; then

				chpasswd <<< "root:$password"
				chpasswd <<< "dietpi:$password"

			fi
			unset -v password

		fi

		# Set APT mirror
		local target_repo='CONFIG_APT_DEBIAN_MIRROR'
		(( $G_HW_MODEL < 10 )) && (( $G_RASPBIAN )) && target_repo='CONFIG_APT_RASPBIAN_MIRROR'
		/boot/dietpi/func/dietpi-set_software apt-mirror "$(sed -n "/^[[:blank:]]*$target_repo=/{s/^[^=]*=//p;q}" /boot/dietpi.txt)"

		# Regenerate unique Dropbear host keys
		local i type
		for i in /etc/dropbear/dropbear_*_host_key
		do
			type=${i#/etc/dropbear/dropbear_}
			type=${type%_host_key}
			rm -v "$i"
			dropbearkey -t "$type" -f "$i"
		done

		# Recreate machine-id: https://github.com/MichaIng/DietPi/issues/2015
		[[ -f '/etc/machine-id' ]] && rm /etc/machine-id
		[[ -f '/var/lib/dbus/machine-id' ]] && rm /var/lib/dbus/machine-id
		systemd-machine-id-setup

		# Network setup
		# - Grab available network interfaces
		/boot/dietpi/func/obtain_network_details
		local index_eth=$(mawk 'NR==1' /run/dietpi/.network)
		disable_error=1 G_CHECK_VALIDINT "$index_eth" 0 || index_eth=0
		local index_wlan=$(mawk 'NR==2' /run/dietpi/.network)
		disable_error=1 G_CHECK_VALIDINT "$index_wlan" 0 || index_wlan=0

		# - Replace interface names with the ones obtained above
		sed -i "s/eth[0-9]/eth$index_eth/g" /etc/network/interfaces
		sed -i "s/wlan[0-9]/wlan$index_wlan/g" /etc/network/interfaces

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
			sed -Ei "/(allow-hotplug|auto)[[:blank:]]+wlan/c\allow-hotplug wlan$index_wlan" /etc/network/interfaces
			sed -Ei "/(allow-hotplug|auto)[[:blank:]]+eth/c\#allow-hotplug eth$index_eth" /etc/network/interfaces

			# Apply global SSID/keys from dietpi.txt to wpa_supplicant
			/boot/dietpi/func/dietpi-wifidb 1

			# Set WiFi country code
			/boot/dietpi/func/dietpi-set_hardware wificountrycode "$(sed -n '/^[[:blank:]]*AUTO_SETUP_NET_WIFI_COUNTRY_CODE=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)"

		# - Ethernet
		elif (( $ethernet_enabled )); then

			# Enable Eth, disable WiFi
			wifi_enabled=0
			sed -Ei "/(allow-hotplug|auto)[[:blank:]]+eth/c\allow-hotplug eth$index_eth" /etc/network/interfaces
			sed -Ei "/(allow-hotplug|auto)[[:blank:]]+wlan/c\#allow-hotplug wlan$index_wlan" /etc/network/interfaces

			# Disable WiFi kernel modules
			/boot/dietpi/func/dietpi-set_hardware wifimodules disable

		fi

		# - Static IP
		if (( $use_static )); then

			if (( $wifi_enabled )); then

				sed -i "/iface wlan/c\iface wlan$index_wlan inet static" /etc/network/interfaces

			elif (( $ethernet_enabled )); then

				sed -i "/iface eth/c\iface eth$index_eth inet static" /etc/network/interfaces

			fi
			sed -i "/address/c\address $static_ip" /etc/network/interfaces
			sed -i "/netmask/c\netmask $static_mask" /etc/network/interfaces
			sed -i "/gateway/c\gateway $static_gateway" /etc/network/interfaces
			if command -v resolvconf > /dev/null; then

				sed -i "/dns-nameservers/c\dns-nameservers $static_dns" /etc/network/interfaces

			else

				> /etc/resolv.conf
				for i in $static_dns; do echo "nameserver $i" >> /etc/resolv.conf; done

			fi

		fi

		# - IPv6
		local enable_ipv6=$(grep -cm1 '^[[:blank:]]*CONFIG_ENABLE_IPV6=1' /boot/dietpi.txt)
		/boot/dietpi/func/dietpi-set_hardware enableipv6 "$enable_ipv6"
		(( $enable_ipv6 )) && /boot/dietpi/func/dietpi-set_hardware preferipv4 "$(grep -cm1 '^[[:blank:]]*CONFIG_PREFER_IPV4=1' /boot/dietpi.txt)"

		# - Configure enabled interfaces now, /etc/network/interfaces will be effective from next boot on
		#	Failsafe: Bring up Ethernet, whenever WiFi is disabled or fails to be configured, e.g. due to wrong credentials
		# shellcheck disable=SC2015
		(( $wifi_enabled )) && ifup wlan$index_wlan || ifup eth$index_eth

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

	# Apply dietpi.txt settings, device specific workarounds and reset hardware ID + SSH host keys
	Apply_DietPi_FirstRun_Settings

	# Set install stage index to trigger automated DietPi-Update on login
	echo 0 > /boot/dietpi/.install_stage

	# Disable originating service to prevent any futher launch of this script
	systemctl disable dietpi-firstboot
	#-----------------------------------------------------------------------------------
	exit
	#-----------------------------------------------------------------------------------
}
