#!/bin/bash
{
	#------------------------------------------------------------------------------------------------
	# Optimize current Debian installation and prep for DietPi installation.
	#------------------------------------------------------------------------------------------------
	# REQUIREMENTS
	# - Currently running Debian (ideally minimal, eg: Raspbian Lite-ish =)) )
	# - Active eth0 connection
	#------------------------------------------------------------------------------------------------
	# DO NOT USE. Currently under testing.
	#------------------------------------------------------------------------------------------------

	#G_AGUP
	#apt-get install wget || or make it a pre-req?
	#wget
	#load
	#Pull in dietpi-globals

	#Force en_GB Locale for whole script. Prevents incorrect parsing with non-english locales.
	LANG=en_GB.UTF-8

	#Ensure we are in users home dir: https://github.com/Fourdee/DietPi/issues/905#issuecomment-298223705
	cd "$HOME"

	#------------------------------------------------------------------------------------------------
	# Critical checks with exit, prior to initial run of script
	#------------------------------------------------------------------------------------------------
	#Exit path for non-root logins.
	if (( $UID != 0 )); then

		echo -e 'Error: Root privileges required. Please run the command with "sudo"\n'
		exit 1

	fi

	#Check for minimal APT Pre-Reqs
	a_MIN_APT_PREREQS=(

		'wget'
		'ca-certificates'
		'sudo'

	)

	for (( i=0; i<${#a_MIN_APT_PREREQS[@]}; i++))
	do

		if (( ! $(dpkg --get-selections | grep -ci -m1 "^${a_MIN_APT_PREREQS[$i]}[[:space:]]") )); then

			#attempt to install it:
			apt-get install -y ${a_MIN_APT_PREREQS[$i]}
			if (( $? != 0 )); then

				echo -e "Error: unable to install ${a_MIN_APT_PREREQS[$i]}, please install it manually with\n - apt-get install ${a_MIN_APT_PREREQS[$i]} -y"
				exit 1

			fi

		fi

	done

	unset a_MIN_APT_PREREQS

	#Download DietPi-Globals
	# - NB: we'll have to manually handle errors, until script is sucessfully loaded
	wget https://raw.githubusercontent.com/Fourdee/DietPi/$GIT_BRANCH/dietpi/func/dietpi-globals -O dietpi-globals
	if (( $? != 0 )); then

		echo -e 'Error: Unable to download dietpi-globals. Aborting...\n'
		exit 1

	fi

	# - load
	chmod +x dietpi-globals
	. ./dietpi-globals
	if (( $? != 0 )); then

		echo -e 'Error: Unable to load dietpi-globals. Aborting...\n'
		exit 1

	fi

	#------------------------------------------------------------------------------------------------
	#Globals
	#------------------------------------------------------------------------------------------------
	#System
	#G_DISTRO # init from dietpi-globals
	#G_DISTRO_NAME # init from dietpi-globals
	DISTRO_TARGET=0
	DISTRO_TARGET_NAME=''
	if grep -q 'wheezy' /etc/os-release; then

		G_DISTRO=2
		G_DISTRO_NAME='wheezy'

	elif grep -q 'jessie' /etc/os-release; then

		G_DISTRO=3
		G_DISTRO_NAME='jessie'

	elif grep -q 'stretch' /etc/os-release; then

		G_DISTRO=4
		G_DISTRO_NAME='stretch'

	elif grep -q 'buster' /etc/os-release; then

		G_DISTRO=5
		G_DISTRO_NAME='buster'

	else

		echo -e 'Error: Unknown or unsupported distribution version, aborting...\n'
		exit 1

	fi

	#G_HW_MODEL # init from dietpi-globals
	#G_HW_ARCH_DESCRIPTION # init from dietpi-globals
	G_HW_ARCH_DESCRIPTION=$(uname -m)
	if [ "$G_HW_ARCH_DESCRIPTION" = "armv6l" ]; then

		G_HW_ARCH=1

	elif [ "$G_HW_ARCH_DESCRIPTION" = "armv7l" ]; then

		G_HW_ARCH=2

	elif [ "$G_HW_ARCH_DESCRIPTION" = "aarch64" ]; then

		G_HW_ARCH=3

	elif [ "$G_HW_ARCH_DESCRIPTION" = "x86_64" ]; then

		G_HW_ARCH=10

	else

		G_DIETPI-NOTIFY 1 "Error: Unknown or unsupported CPU architecture $G_HW_ARCH_DESCRIPTION, aborting..."
		exit 1

	fi

	#URL connection test var holder
	INTERNET_ADDRESS=''

	#Funcs

	Error_Check(){

		#Grab exit code in case of failure
		local exit_code=$?
		if (( $exit_code != 0 )); then

			G_DIETPI-NOTIFY 1 "($exit_code): Script aborted"
			exit $exit_code

		else

			G_DIETPI-NOTIFY 2 "($exit_code): Passed"
		fi

	}

	#Whiptail
	WHIP_BACKTITLE='DietPi-Prep'
	WHIP_TITLE=0
	WHIP_DESC=0
	WHIP_MENU_ARRAY=0
	WHIP_RETURN_VALUE=0
	WHIP_DEFAULT_ITEM=0
	WHIP_OPTION=0
	WHIP_CHOICE=0
	Run_Whiptail(){

		WHIP_OPTION=$(whiptail --title "$WHIP_TITLE" --menu "$WHIP_DESC" --default-item "$WHIP_DEFAULT_ITEM" --backtitle "$WHIP_BACKTITLE" 20 80 12 "${WHIP_MENU_ARRAY[@]}" 3>&1 1>&2 2>&3)
		WHIP_CHOICE=$?
		if (( $WHIP_CHOICE == 0 )); then

			WHIP_RETURN_VALUE=$WHIP_OPTION

		else

			G_DIETPI-NOTIFY 1 'No choices detected, aborting'
			exit 0

		fi

		#delete []
		unset WHIP_MENU_ARRAY

	}

	#------------------------------------------------------------------------------------------------
	#------------------------------------------------------------------------------------------------
	#------------------------------------------------------------------------------------------------
	# MAIN LOOP
	#------------------------------------------------------------------------------------------------
	#------------------------------------------------------------------------------------------------
	#------------------------------------------------------------------------------------------------

	#------------------------------------------------------------------------------------------------
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	G_DIETPI-NOTIFY 0 'Step 0: Detecting existing DietPi system:'
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	#------------------------------------------------------------------------------------------------
	if [ -f /DietPi/dietpi/.installed ]; then

		G_DIETPI-NOTIFY 2 'DietPi system found, running pre-prep'

		# - Stop services
		/DietPi/dietpi/dietpi-services stop

		systemctl stop dietpi-ramlog
		Error_Check
		systemctl stop dietpi-ramdisk
		Error_Check

		# - Delete any previous exsiting data
		rm -R /DietPi/*
		rm -R /boot/dietpi

		rm -R /mnt/dietpi-backup &> /dev/null
		rm -R /mnt/dietpi-sync &> /dev/null
		rm -R /mnt/dietpi_userdata &> /dev/null

		rm -R /etc/dietpi &> /dev/null
		rm -R /var/lib/dietpi &> /dev/null
		rm -R /var/tmp/dietpi &> /dev/null

		rm /root/DietPi-Automation.log &> /dev/null
		rm /boot/Automation_Format_My_Usb_Drive &> /dev/null

	else

		G_DIETPI-NOTIFY 2 'Non-DietPi system'

	fi

	#Recreate dietpi logs dir, used by G_AGx
	mkdir -p /var/tmp/dietpi/logs
	Error_Check


	#------------------------------------------------------------------------------------------------
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	G_DIETPI-NOTIFY 0 'Step 1: Initial prep to allow this script to function:'
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	#------------------------------------------------------------------------------------------------
	G_DIETPI-NOTIFY 2 'Updating APT:'

	apt-get clean
	Error_Check

	G_AGUP
	Error_Check

	G_DIETPI-NOTIFY 2 'Installing core packages, required for next stage of this script:'

	G_AGI apt-transport-https wget unzip whiptail
	Error_Check

	#------------------------------------------------------------------------------------------------
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	G_DIETPI-NOTIFY 0 'Step 2: Hardware selection:'
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	#------------------------------------------------------------------------------------------------

	WHIP_TITLE='Hardware selection:'
	WHIP_DESC='Please select the current device this is being installed on:'
	WHIP_DEFAULT_ITEM=0
	WHIP_MENU_ARRAY=(

		'110' 'RoseapplePi'
		'100' 'Asus Tinker Board'
		'90' 'A20-OLinuXino-MICRO'
		'80' 'Cubieboard 3'
		'71' 'Beagle Bone Black'
		'70' 'Sparky SBC'
		'66' 'NanoPi M1 Plus'
		'65' 'NanoPi NEO 2'
		'64' 'NanoPi NEO Air'
		'63' 'NanoPi M1/T1'
		'62' 'NanoPi M3/T3'
		'61' 'NanoPi M2/T2'
		'60' 'NanoPi Neo'
		'51' 'BananaPi Pro (Lemaker)'
		'50' 'BananaPi M2+ (sinovoip)'
		'43' 'Rock64'
		'42' 'Pine A64+ (2048mb)'
		'41' 'Pine A64+ (1024mb)'
		'40' 'Pine A64  (512mb)'
		'38' 'OrangePi PC 2'
		'37' 'OrangePi Prime'
		'36' 'OrangePi Win'
		'35' 'OrangePi Zero Plus 2 (H3/H5)'
		'34' 'OrangePi Plus'
		'33' 'OrangePi Lite'
		'32' 'OrangePi Zero (H2+)'
		'31' 'OrangePi One'
		'30' 'OrangePi PC'
		'21' 'x86_64 Native PC'
		'20' 'x86_64 VMware/VirtualBox'
		'13' 'oDroid U3'
		'12' 'oDroid C2'
		'11' 'oDroid XU3/4'
		'10' 'oDroid C1'
		'3' 'Raspberry Pi 3'
		'2' 'Raspberry Pi 2'
		'1' 'Raspberry Pi 1/Zero (512mb)'
		'0' 'Raspberry Pi 1 (256mb)'

	)

	Run_Whiptail
	G_HW_MODEL=$WHIP_RETURN_VALUE

	G_DIETPI-NOTIFY 2 "Setting G_HW_MODEL index of: $G_HW_MODEL"
	G_DIETPI-NOTIFY 2 "CPU ARCH = $G_HW_ARCH : $G_HW_ARCH_DESCRIPTION"

	echo -e "$G_HW_MODEL" > /etc/.dietpi_hw_model_identifier

	#------------------------------------------------------------------------------------------------
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	G_DIETPI-NOTIFY 0 'Step 3: Distro selection / APT prep:'
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	#------------------------------------------------------------------------------------------------

	WHIP_TITLE='Distro Selection:'
	WHIP_DESC='Please select a distro to install on this system. Selecting a distro that is older than the current installed on system, is not supported.'
	WHIP_DEFAULT_ITEM=$G_DISTRO
	WHIP_MENU_ARRAY=(
		'3' 'Jessie (oldstable, just if you need to avoid upgrade to current release)'
		'4' 'Stretch (current stable release, recommended)'
	)
	if (( $G_HW_MODEL >= 10 )); then

		WHIP_MENU_ARRAY+=('5' 'Buster (testing only, not officially suppoted)')

	fi

	Run_Whiptail
	DISTRO_TARGET=$WHIP_RETURN_VALUE
	if (( $DISTRO_TARGET == 3 )); then

		DISTRO_TARGET_NAME='jessie'

	elif (( $DISTRO_TARGET == 4 )); then

		DISTRO_TARGET_NAME='stretch'

	elif (( $DISTRO_TARGET == 5 )); then

		DISTRO_TARGET_NAME='buster'

	fi

	G_DIETPI-NOTIFY 2 'Removing conflicting apt sources.list.d'
	#	NB: Apt sources will get overwritten during 1st run, via boot script andn dietpi.txt entry

	#rm /etc/apt/sources.list.d/* &> /dev/null #Probably a bad idea
	rm /etc/apt/sources.list.d/deb-multimedia.list &> /dev/null #meveric

	G_DIETPI-NOTIFY 2 "Setting APT sources.list: $DISTRO_TARGET_NAME $DISTRO_TARGET"

	# - Set raspbian
	if (( $G_HW_MODEL < 10 )); then

		cat << _EOF_ > /etc/apt/sources.list
deb https://www.mirrorservice.org/sites/archive.raspbian.org/raspbian $DISTRO_TARGET_NAME main contrib non-free rpi
_EOF_

		cat << _EOF_ > /etc/apt/sources.list.d/raspi.list
deb https://archive.raspberrypi.org/debian/ $DISTRO_TARGET_NAME main ui
_EOF_

	# - Set debian
	else

		cat << _EOF_ > /etc/apt/sources.list
deb https://deb.debian.org/debian/ $DISTRO_TARGET_NAME main contrib non-free
deb https://deb.debian.org/debian/ $DISTRO_TARGET_NAME-updates main contrib non-free
deb https://deb.debian.org/debian-security/ $DISTRO_TARGET_NAME/updates main contrib non-free
deb https://deb.debian.org/debian/ $DISTRO_TARGET_NAME-backports main contrib non-free
_EOF_

		#	Jessie, switch to http: https://github.com/Fourdee/DietPi/issues/1285#issuecomment-351830101
		if (( $DISTRO_TARGET == 3 )); then

			sed -i 's/https/http/g' /etc/apt/sources.list

		#	Buster, remove backports: https://github.com/Fourdee/DietPi/issues/1285#issuecomment-351830101
		elif (( $DISTRO_TARGET == 5 )); then

			sed -i '/backports/d' /etc/apt/sources.list

		fi

	fi

	G_DIETPI-NOTIFY 2 "Updating APT for $DISTRO_TARGET_NAME:"

	apt-get clean
	Error_Check

	G_AGUP
	Error_Check

	# - Distro is now target
	G_DISTRO=$DISTRO_TARGET
	G_DISTRO_NAME=$DISTRO_TARGET_NAME

	# - @MichaIng https://github.com/Fourdee/DietPi/pull/1266/files
	G_DIETPI-NOTIFY 2 "Marking all packages as auto installed first, to allow allow effective autoremove afterwards"

	apt-mark auto $(apt-mark showmanual)
	Error_Check

	# - @MichaIng https://github.com/Fourdee/DietPi/pull/1266/files
	G_DIETPI-NOTIFY 2 "Temporary disable automatic recommends/suggests installation and allow them to be autoremoved:"

	cat << _EOF_ > /etc/apt/apt.conf.d/99dietpi_norecommends
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APT::AutoRemove::RecommendsImportant "false";
APT::AutoRemove::SuggestsImportant "false";
_EOF_
	Error_Check

	G_DIETPI-NOTIFY 2 "Forcing use of existing apt configs if available"

	cat << _EOF_ > /etc/apt/apt.conf.d/99dietpi_forceconf
Dpkg::options {
   "--force-confdef";
   "--force-confold";
}
_EOF_
	Error_Check


	#------------------------------------------------------------------------------------------------
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	G_DIETPI-NOTIFY 0 'Step 4: APT removals:'
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	#------------------------------------------------------------------------------------------------

	# - DietPi list of minimal required packages which must be installed:
	#	dpkg --get-selections | awk '{print $1}' | sed 's/:a....//g' | sed "s/^/'/g" | sed "s/$/'/g"
	aPACKAGES_REQUIRED_INSTALL=(

		'apt-transport-https'	# Allows https sources in ATP
		'apt-utils'		# Allows debconf to preconfigure APT packages before installing
		'bash-completion'	# Auto completes a wide list of bash commands
		'bc'			# Floating point calculation within bash
		'bzip2'			# .bz2 wrapper
		'ca-certificates'	# Adds known ca-certificates, necessary to practically access https sources
		'console-setup'		# DietPi-Config keyboard configuration
		'crda'			# WiFi related
		'cron'			# background job scheduler
		'curl'			# Web address testing, downloading, uploading etc.
		'dbus'			# System message bus
		'debconf'		# APT package configuration, e.g. 'debconf-set-selections'
		'dosfstools' 		# DietPi-Drive_Manager + fat (boot) drive file system check
		'dphys-swapfile'	# Swap file management
		'dropbear'		# DietPi sefault SSH-Client
		'ethtool'		# Ethernet link checking
		'fake-hwclock'		# Hardware clock emulation, to allow correct timestamps during boot before network time sync
		'fbset'			# DietPi-Config display settings
		'firmware-atheros'	# WiFi dongle firmware
		'firmware-brcm80211'	# WiFi dongle firmware
		'firmware-ralink'	# WiFi dongle firmware
		'firmware-realtek'	# WiFi dongle firmware
		'gnupg'			# apt-key add
		'hdparm'		# Drive power management adjustment
		'hfsplus'		# DietPi-Drive_Manager NTS (MacOS) file system support
		'htop'			# System monitor
		'initramfs-tools'	# RAM file system initialization
		'iputils-ping'		# ping command
		'isc-dhcp-client'	# DHCP client
		'iw'			# WiFi related
		'locales'		# Support locales, necessary for DietPi scripts, as we use enGB.UTF8 as default language
		'nano'			# Simple text editor
		'net-tools'		# DietPi-Boot: Network tools, ifconfig, route etc.
		'ntfs-3g'		# DietPi-Drive_Manager NTPS (Windows) file system support
		'ntp'			# Network time syncronization
		'p7zip-full'		# .7z wrapper
		'parted'		# DietPi-Boot + DietPi-Drive_Manager
		'psmisc'		# DietPi-Boot + DietPi-Software: e.g. killall
		'resolvconf'		# System name server updater
		'rfkill' 		# WiFi related: Used by some onboard WiFi chipsets
		'sudo'			# DietPi-Software + general use
		'tzdata'		# Time zone data for system clock, auto summer/winter time adjustment
		'unzip'			# .zip unwrapper
		'usbutils'		# DietPi-Software + DietPi-Bugreport: e.g. lsusb
		'wget'			# download
		'whiptail'		# DietPi dialogs
		'wireless-tools'	# WiFi related
		'wpasupplicant'		# WiFi related
		'wput'			# upload
		'zip'			# .zip wrapper

	)

	# - G_HW_ARCH specific required packages
	#	x86_64
	if (( $G_HW_ARCH == 10 )); then

		aPACKAGES_REQUIRED_INSTALL+=('linux-image-amd64')
		aPACKAGES_REQUIRED_INSTALL+=('intel-microcode')
		aPACKAGES_REQUIRED_INSTALL+=('amd64-microcode')
		aPACKAGES_REQUIRED_INSTALL+=('firmware-linux-nonfree')
		#aPACKAGES_REQUIRED_INSTALL+=('firmware-misc-nonfree')
		#aPACKAGES_REQUIRED_INSTALL+=('dmidecode')
		if (( $(dpkg --get-selections | grep -ci -m1 '^grub2[[:space:]]') )); then

			aPACKAGES_REQUIRED_INSTALL+=('grub2')

		elif (( $(dpkg --get-selections | grep -ci -m1 '^grub-efi-amd64[[:space:]]') )); then

			aPACKAGES_REQUIRED_INSTALL+=('grub-efi-amd64')

		else

			[ -d /boot/efi ] && aPACKAGES_REQUIRED_INSTALL+=('grub-efi-amd64') || aPACKAGES_REQUIRED_INSTALL+=('grub2')

  		fi

	fi

	# - G_HW_MODEL specific required packages
	#	RPi
	if (( $G_HW_MODEL < 10 )); then

		aPACKAGES_REQUIRED_INSTALL+=('libraspberrypi-bin')
		aPACKAGES_REQUIRED_INSTALL+=('libraspberrypi0')
		aPACKAGES_REQUIRED_INSTALL+=('raspberrypi-bootloader')
		aPACKAGES_REQUIRED_INSTALL+=('raspberrypi-kernel')
		aPACKAGES_REQUIRED_INSTALL+=('raspberrypi-sys-mods')
		aPACKAGES_REQUIRED_INSTALL+=('raspi-copies-and-fills')

	#	Odroid C2
	elif (( $G_HW_MODEL == 12 )); then

		aPACKAGES_REQUIRED_INSTALL+=('linux-image-arm64-odroid-c2')

	#	Odroid XU3/4
	elif (( $G_HW_MODEL == 11 )); then

		#aPACKAGES_REQUIRED_INSTALL+=('linux-image-4.9-armhf-odroid-xu3')
		aPACKAGES_REQUIRED_INSTALL+=('linux-image-armhf-odroid-xu3')

	#	Odroid C1
	elif (( $G_HW_MODEL == 10 )); then

		aPACKAGES_REQUIRED_INSTALL+=('linux-image-armhf-odroid-c1')

	#	Rock64
	elif (( $G_HW_MODEL == 43 )); then

		aPACKAGES_REQUIRED_INSTALL+=('linux-rock64-package')

	#	BBB
	elif (( $G_HW_MODEL == 71 )); then

		aPACKAGES_REQUIRED_INSTALL+=('device-tree-compiler') #Kern

	fi

	G_DIETPI-NOTIFY 2 "Generating list of minimal packages, required for DietPi installation:"

	INSTALL_PACKAGES=''
	for ((i=0; i<${#aPACKAGES_REQUIRED_INSTALL[@]}; i++))
	do

		#	One line INSTALL_PACKAGES so we can use it later.
		INSTALL_PACKAGES+="${aPACKAGES_REQUIRED_INSTALL[$i]} "

	done

	# - delete[]
	unset aPACKAGES_REQUIRED_INSTALL

	G_DIETPI-NOTIFY 2 "Marking required packages as manually installed:"

	apt-mark manual $INSTALL_PACKAGES
	Error_Check

	G_DIETPI-NOTIFY 2 "Purging APT with autoremoval:"

	G_AGA
	Error_Check


	#------------------------------------------------------------------------------------------------
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	G_DIETPI-NOTIFY 0 'Step 5: APT Installations:'
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	#------------------------------------------------------------------------------------------------

	G_DIETPI-NOTIFY 2 "Upgrading existing APT installed packages:"

	G_AGDUG
	Error_Check

	G_DIETPI-NOTIFY 2 "Disabling swapfile generation for dphys-swapfile during install"

	echo -e "CONF_SWAPSIZE=0" > /etc/dphys-swapfile
	Error_Check


	G_DIETPI-NOTIFY 2 "Installing core DietPi pre-req APT packages"

	G_AGI $INSTALL_PACKAGES
	Error_Check

	G_DIETPI-NOTIFY 2 "Onboard Bluetooth selection"

	WHIP_TITLE='Bluetooth Required?'
	WHIP_DESC='Please select an option'
	WHIP_DEFAULT_ITEM=0
	WHIP_MENU_ARRAY=(

		'0' "I don't require Bluetooth, do not install."
		'1' 'Device has onboard Bluetooth and/or I require Bluetooth functionality.'

	)

	Run_Whiptail
	if (( $WHIP_RETURN_VALUE == 1 )); then

		G_DIETPI-NOTIFY 2 "Installing Bluetooth packages"

		G_AGI bluetooth bluez-firmware
		Error_Check

		if (( $G_HW_MODEL < 10 )); then

			G_DIETPI-NOTIFY 2 "Installing Bluetooth packages specific to RPi"

			G_AGI pi-bluetooth
			Error_Check

		fi

	fi

	# - @MichaIng https://github.com/Fourdee/DietPi/pull/1266/files
	G_DIETPI-NOTIFY 2 "Returning installation of recommends back to default"

	rm /etc/apt/apt-conf.d/99dietpi_norecommends &> /dev/null

	G_DIETPI-NOTIFY 2 "Purging APT with autoremoval (in case of DISTRO upgrade/downgrade):"

	G_AGA
	Error_Check


	#------------------------------------------------------------------------------------------------
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	G_DIETPI-NOTIFY 0 'Step 6: Downloading and installing DietPi sourcecode'
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	#------------------------------------------------------------------------------------------------

	INTERNET_ADDRESS="https://github.com/Fourdee/DietPi/archive/$GIT_BRANCH.zip" #NB: testing until this is stable in master
	G_DIETPI-NOTIFY 2 "Checking connection to $INTERNET_ADDRESS"
	G_CHECK_URL "$INTERNET_ADDRESS"
	Error_Check

	wget "$INTERNET_ADDRESS" -O package.zip
	Error_Check

	G_DIETPI-NOTIFY 2 "Extracting DietPi sourcecode"

	unzip package.zip
	Error_Check

	rm package.zip

	G_DIETPI-NOTIFY 2 "Removing files not required"

	#	Remove files we do not require, or want to overwrite in /boot
	rm DietPi-*/CHANGELOG.txt
	rm DietPi-*/PREP_SYSTEM_FOR_DIETPI.sh
	rm DietPi-*/TESTING-BRANCH.md
	rm DietPi-*/uEnv.txt # Pine 64, use existing on system.

	G_DIETPI-NOTIFY 2 "Creating /boot"

	mkdir -p /boot
	Error_Check

	G_DIETPI-NOTIFY 2 "Moving to /boot"

	# - HW specific boot.ini uenv.txt
	if (( $G_HW_MODEL == 10 )); then

		mv DietPi-*/boot_c1.ini /boot/boot.ini
		Error_Check

	elif (( $G_HW_MODEL == 11 )); then

		mv DietPi-*/boot_xu4.ini /boot/boot.ini
		Error_Check

	elif (( $G_HW_MODEL == 12 )); then

		mv DietPi-*/boot_c2.ini /boot/boot.ini
		Error_Check

	fi
	rm DietPi-*/*.ini

	cp -R DietPi-*/* /boot/
	Error_Check

	G_DIETPI-NOTIFY 2 "Cleaning up extracted files"

	rm -R DietPi-*
	Error_Check

	G_DIETPI-NOTIFY 2 "Setting execute permissions for /boot/dietpi"

	chmod -R +x /boot/dietpi
	Error_Check

	#------------------------------------------------------------------------------------------------
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	G_DIETPI-NOTIFY 0 "Step 7: Prep system for DietPi ENV:"
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	#------------------------------------------------------------------------------------------------

	G_DIETPI-NOTIFY 2 "Deleting list of known users, not required by DietPi"

	userdel -f pi &> /dev/null
	userdel -f test &> /dev/null #armbian
	userdel -f odroid &> /dev/null
	userdel -f rock64 &> /dev/null
	userdel -f linaro &> /dev/null #ASUS TB
	userdel -f dietpi &> /dev/null
	userdel -f debian &> /dev/null #BBB

	G_DIETPI-NOTIFY 2 "Removing misc files/folders/services, not required by DietPi"

	rm -R /home &> /dev/null
	rm -R /media &> /dev/null

	rm -R /selinux &> /dev/null

	# - sourcecode (linux-headers etc)
	rm -R /usr/src/* &> /dev/null

	# - root
	rm -R /root/.cache/* &> /dev/null
	rm -R /root/.local/* &> /dev/null
	rm -R /root/.config/* &> /dev/null

	# - documentation folders
	rm -R /usr/share/man &> /dev/null
	rm -R /usr/share/doc &> /dev/null
	rm -R /usr/share/doc-base &> /dev/null
	rm -R /usr/share/calendar &> /dev/null

	# - Previous debconfs
	rm /var/cache/debconf/*-old &> /dev/null

	# - Fonts
	rm -R /usr/share/fonts/* &> /dev/null
	rm -R /usr/share/icons/* &> /dev/null

	#rm /etc/apt/sources.list.d/armbian.list
	rm /etc/init.d/resize2fs &> /dev/null
	rm /etc/update-motd.d/* &> /dev/null # ARMbian

	systemctl disable firstrun  &> /dev/null
	rm /etc/init.d/firstrun  &> /dev/null # ARMbian

	# - Disable ARMbian's log2ram: https://github.com/Fourdee/DietPi/issues/781
	systemctl disable log2ram.service &> /dev/null
	systemctl stop log2ram.service &> /dev/null
	rm /usr/local/sbin/log2ram &> /dev/null
	rm /etc/systemd/system/log2ram.service &> /dev/null
	systemctl daemon-reload &> /dev/null
	rm /etc/cron.hourly/log2ram &> /dev/null

	rm /etc/init.d/cpu_governor &> /dev/null# Meveric
	rm /etc/systemd/system/cpu_governor.service &> /dev/null# Meveric

	# - Disable ARMbian's resize service (not automatically removed by ARMbian scripts...)
	systemctl disable resize2fs &> /dev/null
	rm /etc/systemd/system/resize2fs.service &> /dev/null

	# - ARMbian-config
	rm /etc/profile.d/check_first_login_reboot.sh &> /dev/null

	G_DIETPI-NOTIFY 2 "Creating DietPi core environment"

	/boot/dietpi/func/dietpi-set_core_environment
	Error_Check

	echo -e "Samba client can be installed and setup by DietPi-Config.\nSimply run: dietpi-config and select the Networking option: NAS/Misc menu" > /mnt/samba/readme.txt
	echo -e "FTP client mount can be installed and setup by DietPi-Config.\nSimply run: dietpi-config and select the Networking option: NAS/Misc menu" > /mnt/ftp_client/readme.txt
	echo -e "NFS client can be installed and setup by DietPi-Config.\nSimply run: dietpi-config and select the Networking option: NAS/Misc menu" > /mnt/nfs_client/readme.txt

	G_DIETPI-NOTIFY 2 "Deleting all log files /var/log"

	/boot/dietpi/dietpi-logclear 2 &> /dev/null # As this will report missing vars, however, its fine, does not break functionality.

	G_DIETPI-NOTIFY 2 "Generating DietPi /etc/fstab"

	/boot/dietpi/dietpi-drive_manager 4
	Error_Check

	# - HW Specific:
	#	RPi requires PARTUUID for USB write: https://github.com/Fourdee/DietPi/issues/970
	if (( $G_HW_MODEL < 10 )); then

		PARTUUID_CURRENT=$(blkid /dev/mmcblk0p1 -s PARTUUID -o value)
		UUID_CURRENT=$(blkid /dev/mmcblk0p1 -s UUID -o value)
		sed -i "s#^UUID=$UUID_CURRENT#PARTUUID=$PARTUUID_CURRENT#g" /etc/fstab

		PARTUUID_CURRENT=$(blkid /dev/mmcblk0p2 -s PARTUUID -o value)
		UUID_CURRENT=$(blkid /dev/mmcblk0p2 -s UUID -o value)
		sed -i "s#^UUID=$UUID_CURRENT#PARTUUID=$PARTUUID_CURRENT#g" /etc/fstab

		systemctl daemon-reload

	fi

	G_DIETPI-NOTIFY 2 "Starting DietPi-RAMdisk service"

	systemctl start dietpi-ramdisk.service
	Error_Check

	G_DIETPI-NOTIFY 2 "Starting DietPi-RAMlog service"

	systemctl start dietpi-ramlog.service
	Error_Check

	G_DIETPI-NOTIFY 2 'Updating DietPi HW_INFO'

	/DietPi/dietpi/dietpi-obtain_hw_model

	G_DIETPI-NOTIFY 2 "Configuring Network:"

	# - x86_64 Check for non-standard ethX naming. Rename now (also done via net.iframes=0 in grub for future reboots.
	if (( $G_HW_ARCH == 10 )); then


		G_DIETPI-NOTIFY 2 'Setting adapter name to standard ethX'

		CURRENT_ADAPTER_NAME=$(ip r | grep -m1 'default' | awk '{print $NF}')
		if [ ! -n "$CURRENT_ADAPTER_NAME" ]; then

			G_DIETPI-NOTIFY 1 'Error: Unable to find active ethernet adapater. Aborting...'
			exit 1

		fi

		ifconfig $CURRENT_ADAPTER_NAME down
		ip link set $CURRENT_ADAPTER_NAME name eth0
		ifconfig eth0 up

	fi

	rm -R /etc/network/interfaces &> /dev/null # armbian symlink for bulky network-manager
	cp /boot/dietpi/conf/network_interfaces /etc/network/interfaces
	/DietPi/dietpi/func/obtain_network_details
	Error_Check

	# - enable allow-hotplug eth0 after copying.
	sed -i "/allow-hotplug eth/c\allow-hotplug eth$(sed -n 1p /DietPi/dietpi/.network)" /etc/network/interfaces
	# - Remove all predefined eth*/wlan* adapter rules
	rm /etc/udev/rules.d/70-persistent-net.rules &> /dev/null
	rm /etc/udev/rules.d/70-persistant-net.rules &> /dev/null

	# - Add pre-up lines for wifi on OrangePi Zero
	if (( $G_HW_MODEL == 32 )); then

		sed -i '/iface wlan0 inet dhcp/apre-up modprobe xradio_wlan\npre-up iwconfig wlan0 power on' /etc/network/interfaces

	fi

	G_DIETPI-NOTIFY 2 "Tweaking DHCP timeout:"

	# - Reduce DHCP request retry count and timeouts: https://github.com/Fourdee/DietPi/issues/711
	sed -i '/^#timeout /d' /etc/dhcp/dhclient.conf
	sed -i '/^#retry /d' /etc/dhcp/dhclient.conf
	sed -i '/^timeout /d' /etc/dhcp/dhclient.conf
	sed -i '/^retry /d' /etc/dhcp/dhclient.conf
	cat << _EOF_ >> /etc/dhcp/dhclient.conf
timeout 10;
retry 4;
_EOF_

	G_DIETPI-NOTIFY 2 "Configuring Hosts:"

	cat << _EOF_ > /etc/hosts
127.0.0.1    localhost
127.0.1.1    DietPi
::1          localhost ip6-localhost ip6-loopback
ff02::1      ip6-allnodes
ff02::2      ip6-allrouters
_EOF_
	Error_Check

	cat << _EOF_ > /etc/hostname
DietPi
_EOF_
	Error_Check

	G_DIETPI-NOTIFY 2 "Configuring htop:"

	mkdir -p /root/.config/htop
	cp /DietPi/dietpi/conf/htoprc /root/.config/htop/htoprc

	G_DIETPI-NOTIFY 2 "Configuring hdparm:"

	cat << _EOF_ >> /etc/hdparm.conf

#DietPi external USB drive. Power management settings.
/dev/sda {
        #10 mins
        spindown_time = 120

        #
        apm = 254
}
_EOF_
	Error_Check

	G_DIETPI-NOTIFY 2 "Configuring fakehwclock:"

	# - allow times in the past
	sed -i "/FORCE=/c\FORCE=force" /etc/default/fake-hwclock

	G_DIETPI-NOTIFY 2 "Configuring serial consoles:"

	# - Disable serial console
	/DietPi/dietpi/func/dietpi-set_hardware serialconsole disable

	G_DIETPI-NOTIFY 2 "Configuring ntpd:"

	systemctl disable systemd-timesyncd
	rm /etc/init.d/ntp &> /dev/null

	G_DIETPI-NOTIFY 2 "Configuring regional settings (TZ/Locale/Keyboard):"

	#TODO: automate these...
	dpkg-reconfigure tzdata #Europe > London
	dpkg-reconfigure keyboard-configuration #Keyboard must be plugged in for this to work!
	dpkg-reconfigure locales # en_GB.UTF8 as default and only installed locale


	# - Pump default locale into sys env: https://github.com/Fourdee/DietPi/issues/825
	cat << _EOF_ > /etc/environment
LC_ALL=en_GB.UTF-8
LANG=en_GB.UTF-8
_EOF_
	Error_Check

	#G_HW_ARCH specific
	G_DIETPI-NOTIFY 2 "Applying G_HW_ARCH specific tweaks:"

	if (( $G_HW_ARCH == 10 )); then

		# - i386 APT support
		dpkg --add-architecture i386
		G_AGUP

		# - Disable nouveau: https://github.com/Fourdee/DietPi/issues/1244 // http://dietpi.com/phpbb/viewtopic.php?f=11&t=2462&p=9688#p9688
		cat << _EOF_ > /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
_EOF_
		echo -e "options nouveau modeset=0" > /etc/modprobe.d/nouveau-kms.conf
		update-initramfs -u

	fi

	#G_HW_MODEL specific
	G_DIETPI-NOTIFY 2 "Appling G_HW_MODEL specific tweaks:"

	# - ARMbian OPi Zero 2: https://github.com/Fourdee/DietPi/issues/876#issuecomment-294350580
	if (( $G_HW_MODEL == 35 )); then

		echo -e "blacklist bmp085" > /etc/modprobe.d/bmp085.conf

	# - Sparky SBC ONLY: Blacklist GPU and touch screen modules: https://github.com/Fourdee/DietPi/issues/699#issuecomment-271362441
	elif (( $G_HW_MODEL == 70 )); then

		cat << _EOF_ > /etc/modprobe.d/disable_sparkysbc_touchscreen.conf
blacklist owl_camera
blacklist gsensor_stk8313
blacklist ctp_ft5x06
blacklist ctp_gsl3680
blacklist gsensor_bma222
blacklist gsensor_mir3da
_EOF_

		cat << _EOF_ > /etc/modprobe.d/disable_sparkysbc_gpu.conf
blacklist pvrsrvkm
blacklist drm
blacklist videobuf2_vmalloc
blacklist bc_example
_EOF_

	# - RPI: Scroll lock fix for RPi by Midwan: https://github.com/Fourdee/DietPi/issues/474#issuecomment-243215674
	elif (( $G_HW_MODEL < 10 )); then

		cat << _EOF_ > /etc/udev/rules.d/50-leds.rules
ACTION=="add", SUBSYSTEM=="leds", ENV{DEVPATH}=="*/input*::scrolllock", ATTR{trigger}="kbd-scrollock"
_EOF_

	# - PINE64 (and possibily others): Cursor fix for FB
	elif (( $G_HW_MODEL >= 40 && $G_HW_MODEL <= 42 )); then

		cat << _EOF_ >> "$HOME"/.bashrc
infocmp > terminfo.txt
sed -i -e 's/?0c/?112c/g' -e 's/?8c/?48;0;64c/g' terminfo.txt
tic terminfo.txt
tput cnorm
_EOF_

	# - XU4 FFMPEG fix. Prefer debian.org over Meveric for backports: https://github.com/Fourdee/DietPi/issues/1273
	elif (( $G_HW_MODEL == 11 )); then

		cat << _EOF_ > /etc/apt/preferences.d/backports
Package: *
Pin: release a=jessie-backports
Pin: origin "fuzon.co.uk"
Pin-Priority: 99
_EOF_

	fi

	# - ARMbian increase console verbose
	sed -i '/verbosity=/c\verbosity=7' /boot/armbianEnv.txt &> /dev/null


	#------------------------------------------------------------------------------------------------
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	G_DIETPI-NOTIFY 0 "Step 8: Finalise system for first run of DietPi:"
	G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
	#------------------------------------------------------------------------------------------------

	G_DIETPI-NOTIFY 2 'Installing Dropbear by default'

	G_AGI dropbear
	#	set to start on next boot
	sed -i '/NO_START=1/c\NO_START=0' /etc/default/dropbear

	G_DIETPI-NOTIFY 2 'Configuring Services'

	/DietPi/dietpi/dietpi-services stop
	/DietPi/dietpi/dietpi-services dietpi_controlled

	G_DIETPI-NOTIFY 2 'Clearing APT cache'

	apt-get clean
	rm -R /var/lib/apt/lists/* -vf #lists cache: remove partial folder also, automatically gets regenerated on G_AGUP
	#rm /var/lib/dpkg/info/* #issue...
	#dpkg: warning: files list file for package 'libdbus-1-3:armhf' missing; assuming      package has no files currently installed

	G_DIETPI-NOTIFY 2 'Running general cleanup of misc files'

	# - general folders
	rm -R /tmp/* &> /dev/null

	# - Remove Bash History file
	rm ~/.bash_history &> /dev/null

	# - Nano histroy file
	rm ~/.nano_history &> /dev/null

	G_DIETPI-NOTIFY 2 'Disabling swapfile'

	/DietPi/dietpi/func/dietpi-set_dphys-swapfile 0 /var/swap
	# - Reset config
	echo -e "CONF_SWAPSIZE=0" > /etc/dphys-swapfile
	echo -e "CONF_SWAPFILE=/var/swap" >> /etc/dphys-swapfile

	#	BBB disable swapfile gen
	if (( $G_HW_MODEL == 71 )); then

		sed -i '/Swapfile_Size=/c\Swapfile_Size=0' /DietPi/dietpi.txt

	fi

	G_DIETPI-NOTIFY 2 'Resetting boot.ini, config.txt, cmdline.txt etc'

	# - PineA64 - delete ethaddr from uEnv.txt file
	if (( $G_HW_MODEL >= 40 && $G_HW_MODEL <= 42 )); then

		sed -i '/^ethaddr/ d' /boot/uEnv.txt

	fi

	# - Set Pi cmdline.txt back to normal
	[ -f /boot/cmdline.txt ] && sed -i "s/ rootdelay=10//g" /boot/cmdline.txt

	G_DIETPI-NOTIFY 2 'Generating default wpa_supplicant.conf'

	/DietPi/dietpi/func/dietpi-set_hardware wificreds set

	G_DIETPI-NOTIFY 2 'Disabling generic WiFi/BT by default'

	/DietPi/dietpi/func/dietpi-set_hardware bluetooth disable
	/DietPi/dietpi/func/dietpi-set_hardware wifimodules disable

	G_DIETPI-NOTIFY 2 'Enabling onboard WiFi modules by default'

	/DietPi/dietpi/func/dietpi-set_hardware wifimodules onboard_enable

	G_DIETPI-NOTIFY 2 'Configuring IP version preferences'

	/DietPi/dietpi/func/dietpi-set_hardware preferipversion auto

	G_DIETPI-NOTIFY 2 'Configuring kernels'

	# - Disable installed flags
	rm /etc/dietpi/.*

	# - RPi install DietPi kernel by default
	if (( $G_HW_MODEL < 10 )); then

		rm -R /lib/modules/* # Remove all modules from all kernels, ensures our kernel is installed.
		/DietPi/dietpi/func/dietpi-set_hardware kernel dietpi_rpi_forced #forced, incase of kernel version match which would prevent install

	fi

	G_DIETPI-NOTIFY 2 'Disabling soundcards by default'

	/DietPi/dietpi/func/dietpi-set_hardware soundcard none

	G_DIETPI-NOTIFY 2 'Setting default CPU gov'

	/DietPi/dietpi/dietpi-cpu_set

	G_DIETPI-NOTIFY 2 'Clearing log files'

	/DietPi/dietpi/dietpi-logclear 2

	G_DIETPI-NOTIFY 2 'Deleting DietPi-RAMlog storage'

	rm -R /etc/dietpi/dietpi-ramlog/storage &> /dev/null

	G_DIETPI-NOTIFY 2 'Deleting NTP drift file'

	rm /var/lib/ntp/ntp.drift &> /dev/null

	G_DIETPI-NOTIFY 2 'Resetting DietPi generated globals/files'

	rm /DietPi/dietpi/.*

	G_DIETPI-NOTIFY 2 'Storing current image version /etc/.dietpi_image_version'

	echo -e "$IMAGE_VERSION" > /etc/.dietpi_image_version

	G_DIETPI-NOTIFY 2 'Setting DietPi-Autostart to console'

	echo 0 > /DietPi/dietpi/.dietpi-autostart_index

	G_DIETPI-NOTIFY 2 'Creating our update file (used on 1st run to check for DietPi updates)'

	echo -1 > /DietPi/dietpi/.update_stage

	G_DIETPI-NOTIFY 2 'Set Init .install_stage to -1 (first boot)'

	echo -1 > /DietPi/dietpi/.install_stage

	G_DIETPI-NOTIFY 2 'Remove server_version / patch_file (downloads fresh from dietpi-update)'

	rm /DietPi/dietpi/patch_file &> /dev/null
	rm /DietPi/dietpi/server_version &> /dev/null

	# - HW Specific
	#	RPi remove saved G_HW_MODEL , allowing obtain-hw_model to auto detect RPi model
	if (( $G_HW_MODEL < 10 )); then

		rm /etc/.dietpi_hw_model_identifier

	fi

	G_DIETPI-NOTIFY 2 'Generating dietpi-fs_partition_resize for first boot'

	#??? BBB skip this???
	cat << _EOF_ > /etc/systemd/system/dietpi-fs_partition_resize.service
[Unit]
Description=dietpi-fs_partition_resize
Before=dietpi-ramdisk.service

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=/bin/bash -c '/etc/dietpi/fs_partition_resize.sh | tee /var/tmp/dietpi/logs/fs_partition_resize.log'
StandardOutput=tty

[Install]
WantedBy=local-fs.target
_EOF_
	systemctl daemon-reload
	systemctl enable dietpi-fs_partition_resize.service
	Error_Check

	cat << _EOF_ > /etc/dietpi/fs_partition_resize.sh
#!/bin/bash

systemctl disable dietpi-fs_partition_resize.service
systemctl daemon-reload

TARGET_PARTITION=0
TARGET_DEV=\$(findmnt / -o source -n)

# - MMCBLK[0-9]p[0-9] scrape
if [[ "\$TARGET_DEV" = *"mmcblk"* ]]; then

    TARGET_DEV=\$(findmnt / -o source -n | sed 's/p[0-9]\$//')
	TARGET_PARTITION=\$(findmnt / -o source -n | sed 's/.*p//')

# - Everything else scrape (eg: /dev/sdX[0-9])
else

    TARGET_DEV=\$(findmnt / -o source -n | sed 's/[0-9]\$//')
	TARGET_PARTITION=\$(findmnt / -o source -n | sed 's|/dev/sd.||')

fi

cat << _EOF_1 | fdisk \$TARGET_DEV
p
d
\$TARGET_PARTITION
n
p
\$TARGET_PARTITION
\$(parted \$TARGET_DEV -ms unit s p | grep ':ext4::;' | sed 's/:/ /g' | sed 's/s//g' | awk '{ print \$2 }')

p
w

_EOF_1

reboot

_EOF_
	Error_Check
	chmod +x /etc/dietpi/fs_partition_resize.sh
	Error_Check

	G_DIETPI-NOTIFY 2 'Generating dietpi-fs_partition_expand for subsequent boot'

	cat << _EOF_ > /etc/systemd/system/dietpi-fs_expand.service
[Unit]
Description=dietpi-fs_expand
Before=dietpi-ramdisk.service

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=/bin/bash -c "resize2fs \$(findmnt / -o source -n) | tee /var/tmp/dietpi/logs/fs_expand.log; systemctl disable dietpi-fs_expand.service; systemctl daemon-reload"
StandardOutput=tty

[Install]
WantedBy=local-fs.target
_EOF_
	systemctl daemon-reload
	systemctl enable dietpi-fs_expand.service
	Error_Check

	# #debug
	# systemctl start dietpi-fs_partition_resize.service
	# systemctl status dietpi-fs_partition_resize.service -l
	# cat /var/tmp/dietpi/logs/fs_partition_resize.log


	G_DIETPI-NOTIFY 2 'Sync changes to disk and TRIM rootFS. Please wait, this may take some time...'

	systemctl stop dietpi-ramlog
	Error_Check
	systemctl stop dietpi-ramdisk
	Error_Check

	sync
	fstrim -v /
	sync

	G_DIETPI-NOTIFY 2 'Please check and delete all non-required folders in /root/.xxxxxx'
	G_DIETPI-NOTIFY 2 'Please delete outdated modules'
	ls -lha /lib/modules

	G_DIETPI-NOTIFY 0 "Completed, disk can now be saved to .img for later use, or, reboot system to start first run of DietPi:"

	#Power off system

	#Read image

	#Resize rootfs parition to mininum size +50MB

}
