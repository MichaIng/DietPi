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
	# - Filename: /var/lib/dietpi/services/dietpi-firstboot.bash
	# - Activates on first boot from dietpi-firstboot.service, runs before dietpi-boot.service and networking
	#////////////////////////////////////

	# Import DietPi-Globals --------------------------------------------------------------
	. /DietPi/dietpi/func/dietpi-globals
	G_PROGRAM_NAME='DietPi-FirstBoot'
	G_INIT
	# Import DietPi-Globals --------------------------------------------------------------

	#/////////////////////////////////////////////////////////////////////////////////////
	# Globals
	#/////////////////////////////////////////////////////////////////////////////////////

	RPi_Set_Clock_Speeds(){

		# If no manual overclock settings have been applied by user, set safe overclocking values or commented defaults: https://www.raspberrypi.org/documentation/configuration/config-txt/overclocking.md
		if ! grep -qE '^[[:blank:]]*(over_voltage|(arm|core|gpu|sdram)_freq)=' /DietPi/config.txt; then

			# Zero
			if [[ ${G_HW_MODEL_DESCRIPTION,,} == *'zero'* ]]; then

				sed -i '/over_voltage=/c\#over_voltage=0' /DietPi/config.txt
				sed -i '/arm_freq=/c\#arm_freq=1000' /DietPi/config.txt
				sed -i '/core_freq=/c\#core_freq=400' /DietPi/config.txt
				sed -i '/sdram_freq=/c\#sdram_freq=450' /DietPi/config.txt

			# RPi v1 - Apply safe overclock mode
			elif (( $G_HW_MODEL < 2 )); then

				G_CONFIG_INJECT 'over_voltage=' 'over_voltage=2' /DietPi/config.txt
				G_CONFIG_INJECT 'arm_freq=' 'arm_freq=900' /DietPi/config.txt
				sed -i '/core_freq=/c\#core_freq=250' /DietPi/config.txt
				sed -i '/sdram_freq=/c\#sdram_freq=400' /DietPi/config.txt

			# RPi v2
			elif (( $G_HW_MODEL == 2 )); then

				sed -i '/over_voltage=/c\#over_voltage=0' /DietPi/config.txt
				sed -i '/arm_freq=/c\#arm_freq=900' /DietPi/config.txt
				sed -i '/core_freq=/c\#core_freq=250' /DietPi/config.txt
				sed -i '/sdram_freq=/c\#sdram_freq=400' /DietPi/config.txt

			# RPi v3
			elif (( $G_HW_MODEL == 3 )); then

				sed -i '/over_voltage=/c\#over_voltage=0' /DietPi/config.txt
				sed -i '/arm_freq=/c\#arm_freq=1200' /DietPi/config.txt
				sed -i '/core_freq=/c\#core_freq=400' /DietPi/config.txt
				sed -i '/sdram_freq=/c\#sdram_freq=450' /DietPi/config.txt
				G_CONFIG_INJECT 'temp_limit=' 'temp_limit=75' /DietPi/config.txt # https://github.com/MichaIng/DietPi/issues/356

				# A+/B+
				if [[ $G_HW_MODEL_DESCRIPTION == *'+' ]]; then

					sed -i '/arm_freq=/c\#arm_freq=1400' /DietPi/config.txt
					sed -i '/sdram_freq=/c\#sdram_freq=500' /DietPi/config.txt

				fi

			# RPi v4
			elif (( $G_HW_MODEL == 4 )); then

				sed -i '/over_voltage=/c\#over_voltage=0' /DietPi/config.txt
				sed -i '/arm_freq=/c\#arm_freq=1500' /DietPi/config.txt
				sed -i '/core_freq=/c\#core_freq=500' /DietPi/config.txt
				sed -i '/sdram_freq=/c\#sdram_freq=3200' /DietPi/config.txt
				G_CONFIG_INJECT 'temp_limit=' 'temp_limit=75' /DietPi/config.txt # https://github.com/MichaIng/DietPi/issues/3019

			fi

		fi

	}

	Apply_DietPi_FirstRun_Settings(){

		#----------------------------------------------------------------
		# Workarounds
		# - Workaround for NanoPi Fire3 with tty1 disabled: https://github.com/MichaIng/DietPi/issues/2225
		if (( $G_HW_MODEL == 62 )) && dmesg | grep -qi 'NanoPi Fire3'; then

			chvt 2
			echo -e '#!/bin/dash\nchvt 2' > /var/lib/dietpi/postboot.d/fire3_tty2

		fi
		#----------------------------------------------------------------
		# Set RPi v1 safe overclocking profile (900MHz) and apply commented defaults based on RPi model
		(( $G_HW_MODEL < 10 )) && RPi_Set_Clock_Speeds

		# End user automated script
		if [[ -f '/boot/Automation_Custom_PreScript.sh' ]]; then

			G_DIETPI-NOTIFY 2 'Running custom script, please wait...'

			chmod +x /boot/Automation_Custom_PreScript.sh
			if /boot/Automation_Custom_PreScript.sh | tee /tmp/dietpi-automation_custom_prescript.log; then

				G_DIETPI-NOTIFY 0 'Custom script'

			else

				G_DIETPI-NOTIFY 1 'Custom script: Please see the log file for more information:
         - /var/tmp/dietpi/logs/dietpi-automation_custom_prescript.log'

			fi

		fi

		# Create swap file
		local swap_size=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_SWAPFILE_SIZE=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
		disable_error=1 G_CHECK_VALIDINT "$swap_size" 0 || swap_size=1
		local swap_location=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_SWAPFILE_LOCATION=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
		[[ $swap_location ]] || swap_location='/var/swap'
		/DietPi/dietpi/func/dietpi-set_swapfile $swap_size "$swap_location"

		# Apply Timezone
		local autoinstall_timezone=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_TIMEZONE=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
		if [[ $autoinstall_timezone && $autoinstall_timezone != $(</etc/timezone) ]]; then

			G_DIETPI-NOTIFY 2 "Setting Timezone $autoinstall_timezone. Please wait..."
			[[ -f '/etc/timezone' ]] && rm /etc/timezone
			[[ -f '/etc/localtime' ]] && rm /etc/localtime
			ln -sf "/usr/share/zoneinfo/$autoinstall_timezone" /etc/localtime
			dpkg-reconfigure -f noninteractive tzdata

		fi

		# Apply Language (Locale)
		local autoinstall_language=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_LOCALE=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
		grep -q "^$autoinstall_language UTF-8$" /usr/share/i18n/SUPPORTED || autoinstall_language='en_GB.UTF-8'
		if ! locale | grep -qE "(LANG|LC_ALL)=[\'\"]?$autoinstall_language[\'\"]?" || ! locale -a | grep -qiE 'en_GB.UTF-?8'; then

			G_DIETPI-NOTIFY 2 "Setting Locale $autoinstall_language. Please wait..."
			/DietPi/dietpi/func/dietpi-set_software locale "$autoinstall_language"

		fi

		# Apply Keyboard
		local autoinstall_keyboard=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_KEYBOARD_LAYOUT=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
		if [[ $autoinstall_keyboard ]] && ! grep -q "XKBLAYOUT=\"$autoinstall_keyboard\"" /etc/default/keyboard; then

			G_DIETPI-NOTIFY 2 "Setting Keyboard $autoinstall_keyboard. Please wait..."
			G_CONFIG_INJECT 'XKBLAYOUT=' "XKBLAYOUT=\"$autoinstall_keyboard\"" /etc/default/keyboard
			#systemctl restart keyboard-setup

		fi

		# Apply headless mode, if set in dietpi.txt (RPi, Odroid C1/C2)
		(( $G_HW_MODEL < 11 || $G_HW_MODEL == 12 )) && /DietPi/dietpi/func/dietpi-set_hardware headless $(grep -ci -m1 '^[[:blank:]]*AUTO_SETUP_HEADLESS=1' /DietPi/dietpi.txt)

		# Apply forced eth speed, if set in dietpi.txt
		/DietPi/dietpi/func/dietpi-set_hardware eth-forcespeed $(grep -m1 '^[[:blank:]]*AUTO_SETUP_NET_ETH_FORCE_SPEED=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')

		# Set hostname
		/DietPi/dietpi/func/change_hostname "$(grep -m1 '^[[:blank:]]*AUTO_SETUP_NET_HOSTNAME=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')"

		# Set auto login for next bootup
		grep -qi '^[[:blank:]]*AUTO_SETUP_AUTOMATED=1' /DietPi/dietpi.txt && /DietPi/dietpi/dietpi-autostart 7

		# Disable serial console?
		grep -qi '^[[:blank:]]*CONFIG_SERIAL_CONSOLE_ENABLE=0' /DietPi/dietpi.txt && /DietPi/dietpi/func/dietpi-set_hardware serialconsole disable

		# Set root password?
		local root_password=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_GLOBAL_PASSWORD=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
		if [[ $root_password ]]; then

			chpasswd <<< "root:$root_password"
			chpasswd <<< "dietpi:$root_password"

		fi

		# Set APT mirror
		local target_repo='CONFIG_APT_DEBIAN_MIRROR'
		(( $G_HW_MODEL < 10 )) && target_repo='CONFIG_APT_RASPBIAN_MIRROR'
		/DietPi/dietpi/func/dietpi-set_software apt-mirror "$(grep -m1 "^[[:blank:]]*$target_repo=" /DietPi/dietpi.txt | sed 's/^[^=]*=//')"

		# Regenerate unique Dropbear host keys:
		rm -f /etc/dropbear/*_host_key
		dpkg-reconfigure -f noninteractive dropbear-run

		# Recreate machine-id: https://github.com/MichaIng/DietPi/issues/2015
		[[ -f '/etc/machine-id' ]] && rm /etc/machine-id
		[[ -f '/var/lib/dbus/machine-id' ]] && rm /var/lib/dbus/machine-id
		systemd-machine-id-setup

		# Network setup
		# - Grab available network devices
		/DietPi/dietpi/func/obtain_network_details

		local index_eth=$(sed -n 1p /DietPi/dietpi/.network)
		disable_error=1 G_CHECK_VALIDINT "$index_eth" 0 || index_eth=0
		local index_wlan=$(sed -n 2p /DietPi/dietpi/.network)
		disable_error=1 G_CHECK_VALIDINT "$index_wlan" 0 || index_wlan=0

		# - Replace all eth0 and wlan0 values to the indices DietPi has found.
		sed -i "s/eth[0-9]/eth$index_eth/g" /etc/network/interfaces
		sed -i "s/wlan[0-9]/wlan$index_wlan/g" /etc/network/interfaces

		# - Grab user requested settings from /dietpi.txt
		local ethernet_enabled=$(grep -ci -m1 '^[[:blank:]]*AUTO_SETUP_NET_ETHERNET_ENABLED=1' /DietPi/dietpi.txt)
		local wifi_enabled=$(grep -ci -m1 '^[[:blank:]]*AUTO_SETUP_NET_WIFI_ENABLED=1' /DietPi/dietpi.txt)

		local use_static=$(grep -ci -m1 '^[[:blank:]]*AUTO_SETUP_NET_USESTATIC=1' /DietPi/dietpi.txt)
		local static_ip=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_NET_STATIC_IP=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
		local static_mask=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_NET_STATIC_MASK=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
		local static_gateway=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_NET_STATIC_GATEWAY=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
		local static_dns=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_NET_STATIC_DNS=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')

		# - WiFi
		if (( $wifi_enabled )); then

			# - Enable WiFi, disable Eth
			ethernet_enabled=0
			sed -i "/allow-hotplug wlan/c\allow-hotplug wlan$index_wlan" /etc/network/interfaces
			sed -i "/allow-hotplug eth/c\#allow-hotplug eth$index_eth" /etc/network/interfaces

			# - Apply global SSID/Keys from dietpi.txt to wpa_supp
			/DietPi/dietpi/func/dietpi-wifidb 1

		# - Ethernet
		elif (( $ethernet_enabled )); then

			# - Enable Eth, disable WiFi
			wifi_enabled=0
			sed -i "/allow-hotplug eth/c\allow-hotplug eth$index_eth" /etc/network/interfaces
			sed -i "/allow-hotplug wlan/c\#allow-hotplug wlan$index_wlan" /etc/network/interfaces

			# - Disable WiFi kernel modules
			/DietPi/dietpi/func/dietpi-set_hardware wifimodules disable

		fi

		# - Static IPs
		if (( $use_static )); then

			if (( $wifi_enabled )); then

				sed -i "/iface wlan/c\iface wlan$index_wlan inet static" /etc/network/interfaces

			elif (( $ethernet_enabled )); then

				sed -i "/iface eth/c\iface eth$index_eth inet static" /etc/network/interfaces

			fi

			sed -i "/address/c\address $static_ip" /etc/network/interfaces
			sed -i "/netmask/c\netmask $static_mask" /etc/network/interfaces
			sed -i "/gateway/c\gateway $static_gateway" /etc/network/interfaces
			sed -i "/dns-nameservers/c\dns-nameservers $static_dns" /etc/network/interfaces

		fi

		# - IPv6
		local enable_ipv6=$(grep -ci -m1 '^[[:blank:]]*CONFIG_ENABLE_IPV6=1' /DietPi/dietpi.txt)
		/DietPi/dietpi/func/dietpi-set_hardware enableipv6 $enable_ipv6
		(( $enable_ipv6 )) && /DietPi/dietpi/func/dietpi-set_hardware preferipv4 $(grep -ci -m1 '^[[:blank:]]*CONFIG_PREFER_IPV4=1' /DietPi/dietpi.txt)

	}

	#/////////////////////////////////////////////////////////////////////////////////////
	# Main Loop
	#/////////////////////////////////////////////////////////////////////////////////////
	#-----------------------------------------------------------------------------------
	# Apply dietpi.txt settings, device specific workarounds and reset hardware ID + SSH host keys
	Apply_DietPi_FirstRun_Settings

	# Set install stage index to trigger automated DietPi-Update on login
	echo 0 > /DietPi/dietpi/.install_stage

	# Disable originating service to prevent any futher launch of this script
	systemctl disable dietpi-firstboot
	#-----------------------------------------------------------------------------------
	exit
	#-----------------------------------------------------------------------------------
}
