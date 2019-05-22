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
	# - filename /DietPi/dietpi/dietpi-firstboot
	# - activates on the first boot from dietpi-firstboot.service, runs before dietpi-boot.service and networking
	#////////////////////////////////////

	# Import DietPi-Globals --------------------------------------------------------------
	/DietPi/dietpi/func/dietpi-obtain_hw_model # Runs every boot to allow e.g. switching SDcards between devices and to be failsafe
	. /DietPi/dietpi/func/dietpi-globals
	G_PROGRAM_NAME='DietPi-FirstBoot'
	G_INIT
	# Import DietPi-Globals --------------------------------------------------------------

	#/////////////////////////////////////////////////////////////////////////////////////
	# Globals
	#/////////////////////////////////////////////////////////////////////////////////////


	Apply_DietPi_FirstRun_Settings(){

	        #----------------------------------------------------------------
	        # Automation
	        #----------------------------------------------------------------
	        # - Generate Swapfile
	        /DietPi/dietpi/func/dietpi-set_swapfile $(grep -m1 '^[[:blank:]]*AUTO_SETUP_SWAPFILE_SIZE=' /DietPi/dietpi.txt | sed 's/^[^=]*=//') "$(grep -m1 '^[[:blank:]]*AUTO_SETUP_SWAPFILE_LOCATION=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')"

	        # - Apply Timezone
	        local autoinstall_timezone=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_TIMEZONE=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
	        if [[ $autoinstall_timezone != $(</etc/timezone) ]]; then

	                G_DIETPI-NOTIFY 2 "Setting Timezone $autoinstall_timezone. Please wait..."
	                [[ -f /etc/timezone ]] && rm /etc/timezone
	                [[ -f /etc/localtime ]] && rm /etc/localtime
	                ln -sf "/usr/share/zoneinfo/$autoinstall_timezone" /etc/localtime
	                dpkg-reconfigure -f noninteractive tzdata

	        fi

	        # - Apply Language (Locale)
	        local autoinstall_language=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_LOCALE=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
	        if ! locale | grep -qE "(LANG|LC_ALL)=[\'\"]?$autoinstall_language[\'\"]?" ||
	                ! locale -a | grep -q 'en_GB.UTF-8'; then

	                G_DIETPI-NOTIFY 2 "Setting Locale $autoinstall_language. Please wait..."

	                #	Sanity, wrong result, revert back to default
	                [[ $autoinstall_language =~ 'UTF-8' ]] || autoinstall_language='en_GB.UTF-8'

	                # - Re-apply locale + auto install en_GB.UTF-8 alongside
	                /DietPi/dietpi/func/dietpi-set_software locale "$autoinstall_language"

	        fi

	        # - Apply Keyboard
	        local autoinstall_keyboard=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_KEYBOARD_LAYOUT=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
	        if ! grep -q "XKBLAYOUT=\"$autoinstall_keyboard\"" /etc/default/keyboard; then

	                G_DIETPI-NOTIFY 2 "Setting Keyboard $autoinstall_keyboard. Please wait..."
	                G_CONFIG_INJECT 'XKBLAYOUT=' "XKBLAYOUT=\"$autoinstall_keyboard\"" /etc/default/keyboard
	                #systemctl restart keyboard-setup

	        fi

	        # - Apply headless mode, if set in dietpi.txt (RPi, Odroid C1/C2)
	        (( $G_HW_MODEL < 11 || $G_HW_MODEL == 12 )) && /DietPi/dietpi/func/dietpi-set_hardware headless $(grep -ci -m1 '^[[:blank:]]*AUTO_SETUP_HEADLESS=1' /DietPi/dietpi.txt)

	        # - Apply forced eth speed, if set in dietpi.txt
	        /DietPi/dietpi/func/dietpi-set_hardware eth-forcespeed $(grep -m1 '^[[:blank:]]*AUTO_SETUP_NET_ETH_FORCE_SPEED=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')

	        # - Set hostname
	        /DietPi/dietpi/func/change_hostname "$(grep -m1 '^[[:blank:]]*AUTO_SETUP_NET_HOSTNAME=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')"

	        # - Set auto login for next bootup
	        if grep -qi '^[[:blank:]]*AUTO_SETUP_AUTOMATED=1' /DietPi/dietpi.txt; then

	                /DietPi/dietpi/dietpi-autostart 7

	        fi

	        # - Disable serial console?
	        if grep -qi '^[[:blank:]]*CONFIG_SERIAL_CONSOLE_ENABLE=0' /DietPi/dietpi.txt; then

	                /DietPi/dietpi/func/dietpi-set_hardware serialconsole disable

	        fi

	        # - Set root password?
	        local root_password=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_GLOBAL_PASSWORD=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
	        if [[ $root_password ]]; then

	                chpasswd <<< "root:$root_password"
	                chpasswd <<< "dietpi:$root_password"

	        fi

	        # - Set APT mirror
	        local target_repo='CONFIG_APT_DEBIAN_MIRROR'
	        (( $G_HW_MODEL < 10 )) && target_repo='CONFIG_APT_RASPBIAN_MIRROR'

	        /DietPi/dietpi/func/dietpi-set_software apt-mirror "$(grep -m1 "^[[:blank:]]*$target_repo=" /DietPi/dietpi.txt | sed 's/^[^=]*=//')"

	        # - Generate unique Dropbear host keys:
	        rm -f /etc/dropbear/*_host_key
	        #	Distro specific package and on Jessie, ECDSA is not created automatically
	        if (( $G_DISTRO < 4 )); then

	                dpkg-reconfigure -f noninteractive dropbear
	                dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key

	        else

	                dpkg-reconfigure -f noninteractive dropbear-run

	        fi

	        # - Recreate machine-id: https://github.com/MichaIng/DietPi/issues/2015
	        [[ -f /etc/machine-id ]] && rm /etc/machine-id
	        [[ -f /var/lib/dbus/machine-id ]] && rm /var/lib/dbus/machine-id
	        systemd-machine-id-setup

	        # - Network setup
	        #	Grab available network devices
	        /DietPi/dietpi/func/obtain_network_details

	        local index_eth=$(sed -n 1p /DietPi/dietpi/.network)
	        local index_wlan=$(sed -n 2p /DietPi/dietpi/.network)

	        #	Replace all eth0 and wlan0 values to the indices DietPi has found.
	        sed -i "s/eth[0-9]/eth$index_eth/g" /etc/network/interfaces
	        sed -i "s/wlan[0-9]/wlan$index_wlan/g" /etc/network/interfaces

	        #	Grab user requested settings from /dietpi.txt
	        local ethernet_enabled=$(grep -ci -m1 '^[[:blank:]]*AUTO_SETUP_NET_ETHERNET_ENABLED=1' /DietPi/dietpi.txt)
	        local wifi_enabled=$(grep -ci -m1 '^[[:blank:]]*AUTO_SETUP_NET_WIFI_ENABLED=1' /DietPi/dietpi.txt)

	        local use_static=$(grep -ci -m1 '^[[:blank:]]*AUTO_SETUP_NET_USESTATIC=1' /DietPi/dietpi.txt)
	        local static_ip=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_NET_STATIC_IP=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
	        local static_mask=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_NET_STATIC_MASK=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
	        local static_gateway=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_NET_STATIC_GATEWAY=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')
	        local static_dns=$(grep -m1 '^[[:blank:]]*AUTO_SETUP_NET_STATIC_DNS=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')

	        #	WiFi
	        if (( $wifi_enabled )); then

	                #Enable Wlan, disable Eth
	                ethernet_enabled=0
	                sed -i "/allow-hotplug wlan/c\allow-hotplug wlan$index_wlan" /etc/network/interfaces
	                sed -i "/allow-hotplug eth/c\#allow-hotplug eth$index_eth" /etc/network/interfaces

	                # - Apply global SSID/Keys from dietpi.txt to wpa_supp
	                /DietPi/dietpi/func/dietpi-wifidb 1

	        #	Ethernet
	        elif (( $ethernet_enabled )); then

	                #Enable Eth, disable Wlan
	                wifi_enabled=0
	                sed -i "/allow-hotplug eth/c\allow-hotplug eth$index_eth" /etc/network/interfaces
	                sed -i "/allow-hotplug wlan/c\#allow-hotplug wlan$index_wlan" /etc/network/interfaces

	                /DietPi/dietpi/func/dietpi-set_hardware wifimodules disable

	        fi

	        #	Static IPs
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

	        #	IPv6
	        local enable_ipv6=$(grep -ci -m1 '^[[:blank:]]*CONFIG_ENABLE_IPV6=1' /DietPi/dietpi.txt)
	        /DietPi/dietpi/func/dietpi-set_hardware enableipv6 $enable_ipv6
	        (( $enable_ipv6 )) && /DietPi/dietpi/func/dietpi-set_hardware preferipv4 $(grep -ci -m1 '^[[:blank:]]*CONFIG_PREFER_IPV4=1' /DietPi/dietpi.txt)

	}


	#/////////////////////////////////////////////////////////////////////////////////////
	# Main Loop
	#/////////////////////////////////////////////////////////////////////////////////////
	#-----------------------------------------------------------------------------------
	# - Activate DietPi Boot Loader User Settings and bring up network (dietpi.txt)
	Apply_DietPi_FirstRun_Settings

	# - Set Install stage index to trigger DietPi-Update 1st run on login
	echo 0 > /DietPi/dietpi/.install_stage

	# - Disable the service to prevent any futher launch of this script
	systemctl disable dietpi-firstboot.service

}
