#!/bin/bash
{
	#------------------------------------------------------------------------------------------------
	# Optimise current Debian install and prepare for DietPi installation
	#------------------------------------------------------------------------------------------------
	# REQUIREMENTS
	# - Currently running Debian, ideally minimal, eg: Raspbian Lite-ish =))
	# - systemd as system/init/service manager
	# - Either Ethernet connection or local (non-SSH) terminal access
	#------------------------------------------------------------------------------------------------
	# Dev notes:
	# Following items must be exported or assigned to DietPi scripts, if used, until dietpi-obtain_hw_model is executed:
	# - G_HW_MODEL
	# - G_HW_ARCH
	# - G_DISTRO
	# - G_DISTRO_NAME
	# - G_RASPBIAN
	#
	# The following environment variables can be set to automate this script (adjust example values to your needs):
	# - GITOWNER='MichaIng'			(optional, defaults to 'MichaIng')
	# - GITBRANCH='master'			(must be one of 'master', 'beta' or 'dev')
	# - IMAGE_CREATOR='Mr. Tux'
	# - PREIMAGE_INFO='Some GNU/Linux'
	# - HW_MODEL=0				(must match one of the supported IDs below)
	# - WIFI_REQUIRED=0			[01]
	# - DISTRO_TARGET=5			[456] (Stretch: 4, Buster: 5, Bullseye: 6)
	#------------------------------------------------------------------------------------------------

	# Core globals
	G_PROGRAM_NAME='DietPi-PREP'

	#------------------------------------------------------------------------------------------------
	# Critical checks and requirements to run this script
	#------------------------------------------------------------------------------------------------
	# Exit path for non-root executions
	if (( $UID )); then

		echo -e '[FAILED] Root privileges required, please run this script with "sudo"\nIn case install the "sudo" package with root privileges:\n\t# apt install sudo\n'
		exit 1

	fi

	# Set $PATH variable to include all expected default binary locations, since we don't know the current system setup: https://github.com/MichaIng/DietPi/issues/3206
	export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

	# Work inside /tmp as usually tmpfs to reduce disk I/O and speed up download and unpacking
	# - Save full script path, beforehand: https://github.com/MichaIng/DietPi/pull/2341#discussion_r241784962
	FP_PREP_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
	cd /tmp

	# APT: Prefer IPv4 by default to avoid hanging access attempts in some cases
	# - NB: This needs to match the method in: /DietPi/dietpi/func/dietpi-set_hardware preferipv4 enable
	echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99-dietpi-force-ipv4

	# Allow PDiffs on RPi since the "slow implementation" argument is outdated and PDiffs allow lower download size and less disk I/O
	[[ -f '/etc/apt/apt.conf.d/50raspi' ]] && rm /etc/apt/apt.conf.d/50raspi

	# Disable package state translation downloads
	echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/98-dietpi-no_translations

	# Removing conflicting /etc/apt/sources.list.d entries
	# - Meveric: https://github.com/MichaIng/DietPi/issues/1285#issuecomment-355759321
	[[ -f '/etc/apt/sources.list.d/deb-multimedia.list' ]] && rm /etc/apt/sources.list.d/deb-multimedia.list
	[[ -f '/etc/apt/preferences.d/deb-multimedia-pin-99' ]] && rm /etc/apt/preferences.d/deb-multimedia-pin-99
	[[ -f '/etc/apt/preferences.d/backports' ]] && rm /etc/apt/preferences.d/backports
	# - OMV: https://dietpi.com/phpbb/viewtopic.php?f=11&t=2772
	[[ -f '/etc/apt/sources.list.d/openmediavault.list' ]] && rm /etc/apt/sources.list.d/openmediavault.list

	# Fixing sources.list as Debian dropped Jessie support: https://github.com/MichaIng/DietPi/issues/2665
	if grep -q 'jessie' /etc/os-release && ! grep -qi 'raspbian' /etc/os-release; then

		if [[ $(uname -m) == 'aarch64' ]]; then

			echo 'deb http://archive.debian.org/debian/ main contrib non-free' > /etc/apt/sources.list

		else

			sed -Ei '/jessie-(backports|updates)/d' /etc/apt/sources.list

		fi

	fi

	apt-get clean
	apt-get update

	# Check for/Install APT packages required for this script to:
	aAPT_PREREQS=(

		'wget' # Download DietPi-Globals...
		'ca-certificates' # ...via HTTPS
		'locales' # Set C.UTF-8 locale
		'whiptail' # G_WHIP

	)
	# - Pre-Buster: Support HTTPS sources for APT
	grep -qE '(jessie|stretch)' /etc/os-release && aAPT_PREREQS+=('apt-transport-https')

	for i in "${aAPT_PREREQS[@]}"
	do

		if ! dpkg-query -s $i &> /dev/null && ! apt-get -y --no-install-recommends install $i; then

			echo -e "[FAILED] Unable to install $i, please try to install it manually:\n\t # apt install $i\n"
			exit 1

		fi

	done
	unset aAPT_PREREQS

	# Wget: Prefer IPv4 by default to avoid hanging access attempts in some cases
	# - NB: This needs to match the method in: /boot/dietpi/func/dietpi-set_hardware preferipv4 enable
	if grep -q '^[[:blank:]]*prefer-family[[:blank:]]*=' /etc/wgetrc; then

 		sed -i '/^[[:blank:]]*prefer-family[[:blank:]]*=/c\prefer-family = IPv4' /etc/wgetrc

 	elif grep -q '^[[:blank:]#;]*prefer-family[[:blank:]]*=' /etc/wgetrc; then

 		sed -i '/^[[:blank:]#;]*prefer-family[[:blank:]]*=/c\prefer-family = IPv4' /etc/wgetrc

 	else

 		echo 'prefer-family = IPv4' >> /etc/wgetrc

 	fi

	# Setup locale
	# - Remove existing settings that could break dpkg-reconfigure locales
	> /etc/environment
	[[ -f '/etc/default/locale' ]] && rm /etc/default/locale

	# - NB: DEV, any changes here must be also rolled into function '/boot/dietpi/func/dietpi-set_software locale', for future script use
	echo 'C.UTF-8 UTF-8' > /etc/locale.gen
	# - dpkg-reconfigure includes:
	#	- "locale-gen": Generate locale(s) based on "/etc/locale.gen" or interactive selection.
	#	- "update-locale": Add $LANG to "/etc/default/locale" based on generated locale(s) or interactive default language selection.
	if ! dpkg-reconfigure -f noninteractive locales; then

		echo -e '[FAILED] Locale generation failed. Aborting...\n'
		exit 1

	fi

	# - Export locale vars to assure the following whiptail being beautiful
	export LC_ALL='C.UTF-8' LANG='C.UTF-8'

	# - Update /etc/default/locales with new values (not effective until next load of bash session, eg: logout/in)
	update-locale 'LC_ALL=C.UTF-8'

	# Set Git owner
	GITOWNER=${GITOWNER:-MichaIng}

	# Select Git branch
	if ! [[ $GITBRANCH =~ ^(master|beta|dev)$ ]]; then

		aWHIP_BRANCH=(

			'master' ': Stable release branch (recommended)'
			'beta' ': Public beta testing branch'
			'dev' ': Unstable development branch'

		)

		if ! GITBRANCH=$(whiptail --title "$G_PROGRAM_NAME" --menu 'Please select the Git branch the installer should use:' --default-item 'master' --ok-button 'Ok' --cancel-button 'Exit' --backtitle "$G_PROGRAM_NAME" 12 80 3 "${aWHIP_BRANCH[@]}" 3>&1 1>&2 2>&3-); then

			echo -e '[ INFO ] No choice detected. Aborting...\n'
			exit 0

		fi
		unset aWHIP_BRANCH

	fi

	echo "[ INFO ] Selected Git branch: $GITOWNER/$GITBRANCH"

	#------------------------------------------------------------------------------------------------
	# DietPi-Globals
	#------------------------------------------------------------------------------------------------
	# NB: We have to manually handle errors, until DietPi-Globals are successfully loaded.
	# Download
	if ! wget "https://raw.githubusercontent.com/$GITOWNER/DietPi/$GITBRANCH/dietpi/func/dietpi-globals" -O dietpi-globals; then

		echo -e '[FAILED] Unable to download dietpi-globals. Aborting...\n'
		exit 1

	fi

	# Assure no obsolete .hw_model is loaded
	rm -fv /boot/dietpi/.hw_model

	# Load
	if ! . ./dietpi-globals; then

		echo -e '[FAILED] Unable to load dietpi-globals. Aborting...\n'
		exit 1

	fi
	rm dietpi-globals

	# Reset G_PROGRAM_NAME, which was set to empty string by sourcing dietpi-globals
	G_PROGRAM_NAME='DietPi-PREP'
	G_INIT

	# Apply Git info
	G_GITOWNER=$GITOWNER; unset GITOWNER
	G_GITBRANCH=$GITBRANCH; unset GITBRANCH

	# Detect the Debian version of this operating system
	if grep -q 'jessie' /etc/os-release; then

		G_DISTRO=3
		G_DISTRO_NAME='jessie'

	elif grep -q 'stretch' /etc/os-release; then

		G_DISTRO=4
		G_DISTRO_NAME='stretch'

	elif grep -q 'buster' /etc/os-release; then

		G_DISTRO=5
		G_DISTRO_NAME='buster'

	elif grep -q 'bullseye' /etc/os-release; then

		G_DISTRO=6
		G_DISTRO_NAME='bullseye'

	else

		G_DIETPI-NOTIFY 1 "Unknown or unsupported distribution version: $(sed -n '/^PRETTY_NAME=/{s/^PRETTY_NAME=//p;q}' /etc/os-release 2>&1). Aborting...\n"
		exit 1

	fi

	# Detect the hardware architecture of this operating system
	G_HW_ARCH_NAME=$(uname -m)
	if [[ $G_HW_ARCH_NAME == 'armv6l' ]]; then

		G_HW_ARCH=1

	elif [[ $G_HW_ARCH_NAME == 'armv7l' ]]; then

		G_HW_ARCH=2

	elif [[ $G_HW_ARCH_NAME == 'aarch64' ]]; then

		G_HW_ARCH=3

	elif [[ $G_HW_ARCH_NAME == 'x86_64' ]]; then

		G_HW_ARCH=10

	else

		G_DIETPI-NOTIFY 1 "Unknown or unsupported CPU architecture: \"$G_HW_ARCH_NAME\". Aborting...\n"
		exit 1

	fi

	Main(){

		# Setup step, current (used in info)
		SETUP_STEP=0

		#------------------------------------------------------------------------------------------------
		echo
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP: Detecting existing DietPi system"; ((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------
		if [[ -d '/DietPi' || -d '/boot/dietpi' ]]; then

			G_DIETPI-NOTIFY 2 'DietPi system found, uninstalling old instance...'

			# Stop services: RAMdisk includes (Pre|Post)Boot due to dependencies
			[[ -f '/boot/dietpi/dietpi-services' ]] && /boot/dietpi/dietpi-services stop
			[[ -f '/etc/systemd/system/dietpi-ramlog.service' ]] && systemctl stop dietpi-ramlog
			[[ -f '/etc/systemd/system/dietpi-ramdisk.service' ]] && systemctl stop dietpi-ramdisk

			# Disable DietPi services
			for i in /etc/systemd/system/dietpi-*
			do

				[[ -f $i ]] && systemctl disable --now ${i##*/}
				rm -Rfv $i

			done

			# Delete any previous existing data
			# - /DietPi mount point: Pre-v6.29
			findmnt /DietPi &> /dev/null && umount /DietPi
			[[ -d '/DietPi' ]] && rm -R /DietPi
			rm -Rfv /{boot,mnt,etc,var/lib,var/tmp,run}/*dietpi*
			rm -fv /etc{,/cron.*,/{bashrc,profile,sysctl,network/if-up,udev/rules}.d}/{,.}*dietpi*

			[[ -f '/root/DietPi-Automation.log' ]] && rm -v /root/DietPi-Automation.log
			[[ -f '/boot/Automation_Format_My_Usb_Drive' ]] && rm -v /boot/Automation_Format_My_Usb_Drive

		else

			G_DIETPI-NOTIFY 2 'No DietPi system found, skipping old instance uninstall...'

		fi

		#------------------------------------------------------------------------------------------------
		echo
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP: Target system inputs"; ((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------

		# Image creator
		while :
		do
			if [[ $IMAGE_CREATOR ]]; then

				G_WHIP_RETURNED_VALUE=$IMAGE_CREATOR
				# unset to force interactive input if disallowed name is detected
				unset IMAGE_CREATOR

			else

				G_WHIP_INPUTBOX 'Please enter your name. This will be used to identify the image creator within credits banner.\n\nYou can add your contact information as well for end users.\n\nNB: An entry is required.'

			fi

			if [[ $G_WHIP_RETURNED_VALUE ]]; then

				# Disallowed?
				DISALLOWED_NAME=0
				aDISALLOWED_NAMES=(

					'official'
					'fourdee'
					'daniel knight'
					'dan knight'
					'michaing'
					'diet'

				)

				for i in "${aDISALLOWED_NAMES[@]}"
				do

					if [[ ${G_WHIP_RETURNED_VALUE,,} =~ $i ]]; then

						DISALLOWED_NAME=1
						break

					fi

				done
				unset aDISALLOWED_NAMES

				if (( $DISALLOWED_NAME )); then

					G_WHIP_MSG "\"$G_WHIP_RETURNED_VALUE\" is reserved and cannot be used. Please try again."

				else

					IMAGE_CREATOR=$G_WHIP_RETURNED_VALUE
					break

				fi

			fi

		done

		G_DIETPI-NOTIFY 2 "Entered image creator: $IMAGE_CREATOR"

		# Pre-image used/name
		until [[ $PREIMAGE_INFO ]]
		do

			G_WHIP_INPUTBOX 'Please enter the name or URL of the pre-image you installed on this system, prior to running this script. This will be used to identify the pre-image credits.\n\nEG: Debian, Raspbian Lite, Meveric, FriendlyARM, or "forum.odroid.com/viewtopic.php?f=ABC&t=XYZ" etc.\n\nNB: An entry is required.'
			PREIMAGE_INFO=$G_WHIP_RETURNED_VALUE

		done

		G_DIETPI-NOTIFY 2 "Entered pre-image info: $PREIMAGE_INFO"

		# Hardware selection
		#	NB: PLEASE ENSURE HW_MODEL INDEX ENTRIES MATCH dietpi-obtain_hw_model and dietpi-survey_report
		#	NBB: DO NOT REORDER INDICES. These are now fixed and will never change (due to survey results etc)
		G_WHIP_BUTTON_CANCEL_TEXT='Exit'
		G_WHIP_DEFAULT_ITEM=0
		G_WHIP_MENU_ARRAY=(

			'' '●─ ARM ─ Core devices with GPU support '
			'0' ': Raspberry Pi (All models)'
			#'0' ': Raspberry Pi 1 (256 MiB)
			#'1' ': Raspberry Pi 1/Zero (512 MiB)'
			#'2' ': Raspberry Pi 2'
			#'3' ': Raspberry Pi 3/3+'
			#'4' ': Raspberry Pi 4'
			'11' ': Odroid XU3/XU4/MC1/HC1/HC2'
			'12' ': Odroid C2'
			'15' ': Odroid N2'
			'44' ': Pinebook'
			'' '●─ x86_64 '
			'21' ': x86_64 Native PC'
			'20' ': x86_64 Virtual Machine'
			'' '●─ ARM ─ Limited support devices without GPU support '
			'10' ': Odroid C1'
			'13' ': Odroid U3'
			'14' ': Odroid N1'
			'16' ': Odroid C4'
			'70' ': Sparky SBC'
			'52' ': ASUS Tinker Board'
			'40' ': PINE A64'
			'43' ': ROCK64'
			'42' ': ROCKPro64'
			'45' ': PINE H64'
			'59' ': ZeroPi'
			'60' ': NanoPi NEO'
			'65' ': NanoPi NEO2'
			'57' ': NanoPi NEO Plus2'
			'64' ': NanoPi NEO Air'
			'63' ': NanoPi M1/T1'
			'66' ': NanoPi M1 Plus'
			'67' ': NanoPi K1 Plus'
			'61' ': NanoPi M2/T2'
			'62' ': NanoPi M3/T3/Fire3'
			'68' ': NanoPi M4/T4/NEO4'
			'58' ': NanoPi M4V2'
			'72' ': ROCK Pi 4'
			'73' ': ROCK Pi S'
			'69' ': Firefly RK3399'
			'38' ': OrangePi PC 2'
			'37' ': OrangePi Prime'
			'36' ': OrangePi Win'
			'35' ': OrangePi Zero Plus 2 (H3/H5)'
			'34' ': OrangePi Plus'
			'33' ': OrangePi Lite'
			'32' ': OrangePi Zero (H2+)'
			'31' ': OrangePi One'
			'30' ': OrangePi PC'
			'41' ': OrangePi PC Plus'
			'53' ': BananaPi (sinovoip)'
			'51' ': BananaPi Pro (Lemaker)'
			'50' ': BananaPi M2+ (sinovoip)'
			'71' ': BeagleBone Black'
			'39' ': LeMaker Guitar'
			'' '●─ Other '
			'22' ': Generic Device'

		)

		while :
		do

			# Check for valid entry, e.g. when set via environment variabe
			if disable_error=1 G_CHECK_VALIDINT "$HW_MODEL" 0; then

				for i in "${G_WHIP_MENU_ARRAY[@]}"
				do

					[[ $HW_MODEL == $i ]] && break 2

				done

			fi

			if ! G_WHIP_MENU 'Please select the current device this is being installed on:\n - NB: Select "Generic device" if not listed.\n - "Core devices": Are fully supported by DietPi, offering full GPU + Kodi support.\n - "Limited support devices": No GPU support, supported limited to DietPi specific issues only (eg: excludes Kernel/GPU/VPU related items).'; then

				G_DIETPI-NOTIFY 1 'No choice detected. Aborting...\n'
				exit 0

			elif [[ $G_WHIP_RETURNED_VALUE ]]; then

				HW_MODEL=$G_WHIP_RETURNED_VALUE
				break

			fi

		done
		G_HW_MODEL=$HW_MODEL
		unset HW_MODEL

		# RPi: Detect Debian vs Raspbian and 64 vs 32 bit image
		if (( $G_HW_MODEL < 10 )); then

			if grep -q '^ID=debian' /etc/os-release; then

				G_RASPBIAN=0
				[[ $(mawk 'NR==1' /var/lib/dpkg/arch) == 'arm64' ]] && G_HW_ARCH=3 || G_HW_ARCH=2

			else

				G_RASPBIAN=1 G_HW_ARCH=1

			fi

		fi

		G_DIETPI-NOTIFY 2 "Selected hardware model ID: $G_HW_MODEL"
		G_DIETPI-NOTIFY 2 "Detected target CPU architecture: $G_HW_ARCH_NAME (ID: $G_HW_ARCH)"

		# WiFi selection
		if [[ $WIFI_REQUIRED != [01] ]]; then

			G_WHIP_MENU_ARRAY=(

				'0' ': I do not require WiFi functionality, skip related package install.'
				'1' ': I require WiFi functionality, install related packages.'

			)

			(( $G_HW_MODEL == 20 )) && G_WHIP_DEFAULT_ITEM=0 || G_WHIP_DEFAULT_ITEM=1
			if G_WHIP_MENU 'Please select an option:'; then

				WIFI_REQUIRED=$G_WHIP_RETURNED_VALUE

			else

				G_DIETPI-NOTIFY 1 'No choice detected. Aborting...\n'
				exit 0

			fi

		fi

		(( $WIFI_REQUIRED )) && G_DIETPI-NOTIFY 2 'Marking WiFi as required' || G_DIETPI-NOTIFY 2 'Marking WiFi as NOT required'

		# Distro Selection
		DISTRO_LIST_ARRAY=(

			'4' ': Stretch (oldstable, if SBC firmware is not yet Buster-compatible)'
			'5' ': Buster (current stable release, recommended)'
			'6' ': Bullseye (testing, if you want to live on bleeding edge)'

		)

		# - Enable/list available options based on criteria
		#	NB: Whiptail uses 2 array indices per entry: value + description
		G_WHIP_MENU_ARRAY=()
		for ((i=0; i<${#DISTRO_LIST_ARRAY[@]}; i+=2))
		do

			# Disable downgrades
			if (( ${DISTRO_LIST_ARRAY[$i]} < $G_DISTRO )); then

				G_DIETPI-NOTIFY 2 "Disabled distro downgrade to${DISTRO_LIST_ARRAY[$i+1]%% (*}"

			# Enable option
			else

				G_WHIP_MENU_ARRAY+=( "${DISTRO_LIST_ARRAY[$i]}" "${DISTRO_LIST_ARRAY[$i+1]}" )

			fi

		done
		unset DISTRO_LIST_ARRAY

		if (( ! ${#G_WHIP_MENU_ARRAY[@]} )); then

			G_DIETPI-NOTIFY 1 'No available distro versions found for this system. Aborting...\n'
			exit 1

		fi

		while :
		do

			if disable_error=1 G_CHECK_VALIDINT "$DISTRO_TARGET" 0; then

				for i in "${G_WHIP_MENU_ARRAY[@]}"
				do

					[[ $DISTRO_TARGET == $i ]] && break 2

				done

			fi

			G_WHIP_DEFAULT_ITEM=${G_WHIP_MENU_ARRAY[0]} # Downgrades disabled, so first item matches current/lowest supported distro version
			G_WHIP_BUTTON_CANCEL_TEXT='Exit'
			if G_WHIP_MENU "Please select a Debian version to install on this system.\n
Currently installed: $G_DISTRO_NAME (ID: $G_DISTRO)"; then

				DISTRO_TARGET=$G_WHIP_RETURNED_VALUE
				break

			else

				G_DIETPI-NOTIFY 1 'No choice detected. Aborting...\n'
				exit 0

			fi

		done

		if (( $DISTRO_TARGET == 4 )); then

			DISTRO_TARGET_NAME='stretch'

		elif (( $DISTRO_TARGET == 5 )); then

			DISTRO_TARGET_NAME='buster'

		elif (( $DISTRO_TARGET == 6 )); then

			DISTRO_TARGET_NAME='bullseye'

		else

			G_DIETPI-NOTIFY 1 'Invalid choice detected. Aborting...\n'
			exit 1

		fi

		G_DIETPI-NOTIFY 2 "Selected Debian version: $DISTRO_TARGET_NAME (ID: $DISTRO_TARGET)"

		#------------------------------------------------------------------------------------------------
		echo
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP: Downloading and installing DietPi source code"; ((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------

		local url="https://github.com/$G_GITOWNER/DietPi/archive/$G_GITBRANCH.tar.gz"
		G_CHECK_URL_TIMEOUT=10 G_CHECK_URL_ATTEMPTS=2 G_CHECK_URL "$url"
		G_EXEC_DESC='Downloading DietPi sourcecode' G_EXEC curl -sSfL "$url" -o package.tar.gz

		[[ -d DietPi-$G_GITBRANCH ]] && G_EXEC_DESC='Cleaning previously extracted files' G_EXEC rm -R "DietPi-$G_GITBRANCH"
		G_EXEC_DESC='Extracting DietPi sourcecode' G_EXEC tar xf package.tar.gz
		rm package.tar.gz

		[[ -d '/boot' ]] || G_EXEC_DESC='Creating /boot' G_EXEC mkdir /boot

		G_DIETPI-NOTIFY 2 'Moving kernel and boot configuration to /boot'

		# HW specific config.txt, boot.ini uEnv.txt
		if (( $G_HW_MODEL < 10 )); then

			G_EXEC mv "DietPi-$G_GITBRANCH/config.txt" /boot/
			# Boot in 64-bit mode if this is a 64-bit image
			[[ $G_HW_ARCH == 3 ]] && G_CONFIG_INJECT 'arm_64bit=' 'arm_64bit=1' /boot/config.txt

		elif (( $G_HW_MODEL == 11 )); then

			G_EXEC mv "DietPi-$G_GITBRANCH/boot_xu4.ini" /boot/boot.ini

		elif (( $G_HW_MODEL == 12 )); then

			G_EXEC mv "DietPi-$G_GITBRANCH/boot_c2.ini" /boot/boot.ini

		fi

		G_EXEC mv "DietPi-$G_GITBRANCH/dietpi.txt" /boot/
		G_EXEC mv "DietPi-$G_GITBRANCH/README.md" /boot/dietpi-README.md
		G_EXEC mv "DietPi-$G_GITBRANCH/LICENSE" /boot/dietpi-LICENSE.txt
		G_EXEC mv "DietPi-$G_GITBRANCH/CHANGELOG.txt" /boot/dietpi-CHANGELOG.txt

		# Reading version string for later use
		G_DIETPI_VERSION_CORE=$(mawk 'NR==1' "DietPi-$G_GITBRANCH/dietpi/server_version-6")
		G_DIETPI_VERSION_SUB=$(mawk 'NR==2' "DietPi-$G_GITBRANCH/dietpi/server_version-6")
		G_DIETPI_VERSION_RC=$(mawk 'NR==3' "DietPi-$G_GITBRANCH/dietpi/server_version-6")

		# Remove server_version* / (pre-)patch_file (downloads fresh from dietpi-update)
		rm "DietPi-$G_GITBRANCH/dietpi/server_version"*
		rm "DietPi-$G_GITBRANCH/dietpi/pre-patch_file"
		rm "DietPi-$G_GITBRANCH/dietpi/patch_file"

		G_EXEC_DESC='Copy DietPi scripts to /boot/dietpi' G_EXEC cp -Rf "DietPi-$G_GITBRANCH/dietpi" /boot/
		G_EXEC_DESC='Copy DietPi system files in place' G_EXEC cp -Rf "DietPi-$G_GITBRANCH/rootfs"/. /
		G_EXEC_DESC='Clean download location' G_EXEC rm -R "DietPi-$G_GITBRANCH"
		G_EXEC_DESC='Set execute permissions for DietPi scripts' G_EXEC chmod -R +x /boot/dietpi /var/lib/dietpi/services /etc/cron.*/dietpi

		G_EXEC systemctl daemon-reload

		#------------------------------------------------------------------------------------------------
		echo
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP: APT configuration"; ((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------

		G_DIETPI-NOTIFY 2 "Setting APT sources.list: $DISTRO_TARGET_NAME $DISTRO_TARGET"

		# We need to forward $DISTRO_TARGET* to dietpi-set_software, as well as $G_HW_MODEL + $G_RASPBIAN for Debian vs Raspbian decision.
		G_DISTRO=$DISTRO_TARGET G_DISTRO_NAME=$DISTRO_TARGET_NAME G_HW_MODEL=$G_HW_MODEL G_RASPBIAN=$G_RASPBIAN G_EXEC /boot/dietpi/func/dietpi-set_software apt-mirror default

		# Meveric, update repo to use our EU mirror: https://github.com/MichaIng/DietPi/issues/1519#issuecomment-368234302
		sed -Ei 's@https?://oph\.mdrjr\.net@http://fuzon.co.uk@' /etc/apt/sources.list.d/meveric* &> /dev/null

		# (Re)create DietPi runtime and logs dir, used by G_AGx
		G_EXEC mkdir -p /run/dietpi /var/tmp/dietpi/logs

		G_AGUP

		# @MichaIng https://github.com/MichaIng/DietPi/pull/1266/files
		G_DIETPI-NOTIFY 2 'Marking all packages as auto-installed first, to allow effective autoremove afterwards'
		G_EXEC apt-mark auto $(dpkg --get-selections | mawk '{print $1}')

		G_EXEC_DESC='Disable automatic recommends/suggests install and allow them to be autoremoved'
		# Remove existing/conflicting files first
		rm -fv /etc/apt/apt.conf.d/*recommends*
		G_EXEC eval 'cat << _EOF_ > /etc/apt/apt.conf.d/99-dietpi-norecommends
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APT::AutoRemove::RecommendsImportant "false";
APT::AutoRemove::SuggestsImportant "false";
_EOF_'

		G_DIETPI-NOTIFY 2 'Disable package state translation downloads'
		echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/98-dietpi-no_translations

		G_EXEC_DESC='Preserve modified config files on APT update'
		G_EXEC eval 'cat << _EOF_ > /etc/apt/apt.conf.d/99-dietpi-forceconf
Dpkg::options {
   "--force-confdef";
   "--force-confold";
}
_EOF_'

		# DietPi list of minimal required packages, which must be installed:
		aPACKAGES_REQUIRED_INSTALL=(

			'apt-utils'		# Allows "debconf" to pre-configure APT packages for non-interactive install
			'bash-completion'	# Auto completes a wide list of bash commands and options via <tab>
			'bc'			# Bash calculator, e.g. for floating point calculation
			'bzip2'			# (.tar).bz2 wrapper
			'ca-certificates'	# Adds known ca-certificates, necessary to practically access HTTPS sources
			'console-setup'		# DietPi-Config keyboard configuration + console fonts
			'cron'			# Background job scheduler
			'curl'			# Web address testing, downloading, uploading etc.
			'debconf'		# APT package pre-configuration, e.g. "debconf-set-selections" for non-interactive install
			'dirmngr'		# GNU key management required for some APT installs via additional repos
			'ethtool'		# Force Ethernet link speed
			'fake-hwclock'		# Hardware clock emulation, to allow correct timestamps during boot before network time sync
			'gnupg'			# apt-key add
			'htop'			# System monitor
			'ifupdown'		# Network interface configuration
			'iputils-ping'		# "ping" command
			'isc-dhcp-client'	# DHCP client
			'kmod'			# "modprobe", "lsmod", used by several DietPi scripts
			'locales'		# Support locales, necessary for DietPi scripts, as we use C.UTF-8 as default
			'nano'			# Simple text editor
			'p7zip'			# .7z wrapper
			'parted'		# partprobe + drive partitioning, required by DietPi-Drive_Manager
			'procps'		# "kill", "ps", "pgrep", "sysctl", used by several DietPi scripts
			'psmisc'		# "killall", used by several DietPi scripts
			'sudo'			# Root permission wrapper for users within /etc/sudoers(.d/)
			'systemd-sysv'		# Includes systemd and additional commands: "poweroff", "shutdown" etc.
			'tzdata'		# Time zone data for system clock, auto summer/winter time adjustment
			'udev'			# /dev/ and hotplug management daemon
			'unzip'			# .zip unpacker
			'usbutils'		# "lsusb", used by DietPi-Software + DietPi-Bugreport
			'wget'			# Download tool
			'whiptail'		# DietPi dialogs
			#'xz-utils'		# (.tar).xz wrapper

		)

		# G_DISTRO specific
		# - Dropbear: DietPi default SSH-Client
		#   On Buster-, "dropbear" pulls in "dropbear-initramfs", which we don't need: https://packages.debian.org/dropbear
		# - apt-transport-https: Allows HTTPS sources for ATP
		#   On Buster+, it is included in "apt" package: https://packages.debian.org/apt-transport-https
		if (( $G_DISTRO > 5 )); then

			aPACKAGES_REQUIRED_INSTALL+=('dropbear')

		else

			aPACKAGES_REQUIRED_INSTALL+=('dropbear-run')
			(( $G_DISTRO < 5 )) && aPACKAGES_REQUIRED_INSTALL+=('apt-transport-https')

		fi
		# - systemd-timesyncd: Network time sync daemon
		#   Available as dedicated package since Bullseye: https://packages.debian.org/systemd-timesyncd
		#   While the above needs to be checked against current distro to not break SSH or APT before distro upgrade, this one should be checked against target distro version.
		(( $DISTRO_TARGET > 5 )) && aPACKAGES_REQUIRED_INSTALL+=('systemd-timesyncd')

		# - fdisk: Partitioning tool used by DietPi-FS_partition_resize and DietPi-Imager
		#   This has become an own package since Debian Buster: https://packages.debian.org/fdisk
		(( $DISTRO_TARGET > 4 )) && aPACKAGES_REQUIRED_INSTALL+=('fdisk')

		# G_HW_MODEL specific
		# - initramfs: Required for generic bootloader, but not required/used by RPi bootloader, on VM install tiny-initramfs with limited features but sufficient and much smaller + faster
		if (( $G_HW_MODEL == 20 )); then

			aPACKAGES_REQUIRED_INSTALL+=('tiny-initramfs')

		elif (( $G_HW_MODEL > 9 )); then

			aPACKAGES_REQUIRED_INSTALL+=('initramfs-tools')

		fi
		# - Entropy daemon: Use modern rng-tools5 on all devices where it has been proven to work, on RPi rng-tools (default on Raspbian), else haveged: https://github.com/MichaIng/DietPi/issues/2806
		if [[ $G_HW_MODEL =~ ^(11|14|16|42|58|68|69|72)$ ]]; then # Odroid XU4, RK3399, Odroid C4

			aPACKAGES_REQUIRED_INSTALL+=('rng-tools5')

		elif (( $G_HW_MODEL > 9 )); then

			aPACKAGES_REQUIRED_INSTALL+=('haveged')

		else

			aPACKAGES_REQUIRED_INSTALL+=('rng-tools')

		fi

		# WiFi related
		if (( $WIFI_REQUIRED )); then

			aPACKAGES_REQUIRED_INSTALL+=('iw')			# Tools to configure WiFi adapters
			aPACKAGES_REQUIRED_INSTALL+=('wireless-tools')		# Same as "iw", deprecated but still required for non-nl80211 adapters
			aPACKAGES_REQUIRED_INSTALL+=('crda')			# Set WiFi frequencies according to local regulations, based on WiFi country code
			aPACKAGES_REQUIRED_INSTALL+=('rfkill')	 		# Block/unblock wireless adapters, including WiFi and Bluetooth
			aPACKAGES_REQUIRED_INSTALL+=('wpasupplicant')		# Support for WPA-protected WiFi network connection

		fi

		# G_HW_MODEL specific
		(( $G_HW_MODEL == 20 )) || aPACKAGES_REQUIRED_INSTALL+=('hdparm') # Drive power management adjustments

		# Install gdisk if root file system is on a GPT partition, used by DietPi-FS_partition_resize
		[[ $(parted -s "$(lsblk -npo PKNAME "$(findmnt -no SOURCE /)")" print) == *'Partition Table: gpt'* ]] && aPACKAGES_REQUIRED_INSTALL+=('gdisk')

		# Install required filesystem packages
		if [[ $(blkid -s TYPE -o value) =~ (^|[[:space:]]|v)'fat' ]]; then

			aPACKAGES_REQUIRED_INSTALL+=('dosfstools')		# DietPi-Drive_Manager + fat (boot) drive file system check and creation tools

		fi

		# Kernel/bootloader/firmware
		# - We need to install those directly to allow G_AGA() autoremove possible older packages later: https://github.com/MichaIng/DietPi/issues/1285#issuecomment-354602594
		# - Jessie workaround: https://github.com/MichaIng/DietPi/issues/3462
		(( $G_DISTRO < 4 )) && G_EXEC_PRE_FUNC(){ acommand[2]='--force-yes'; }
		# - G_HW_ARCH specific
		#	x86_64
		if (( $G_HW_ARCH == 10 )); then

			local packages='linux-image-amd64 os-prober'

			# Grub EFI
			if dpkg-query -s 'grub-efi-amd64' &> /dev/null || [[ -d '/boot/efi' ]]; then

				packages+=' grub-efi-amd64'
				# On Buster+ enable secure boot compatibility: https://packages.debian.org/buster/grub-efi-amd64-signed
				(( $DISTRO_TARGET > 4 )) && packages+=' grub-efi-amd64-signed shim-signed'

			# Grub BIOS
			else

				packages+=' grub-pc'

			fi

			G_AGI $packages

		# - G_HW_MODEL specific required firmware/kernel/bootloader packages
		#	ARMbian grab currently installed packages
		elif dpkg --get-selections | grep -q 'armbian'; then

			systemctl stop armbian-*

			local apackages=(

				'linux-dtb-'
				'linux-u-'
				'linux-image-'
				"linux-$DISTRO_TARGET_NAME-"
				'sunxi-tools'

			)

			for i in "${apackages[@]}"
			do

				while read -r line
				do

					aPACKAGES_REQUIRED_INSTALL+=("$line")
					G_DIETPI-NOTIFY 2 "ARMbian package detected and added: $line"

				done <<< "$(dpkg --get-selections | mawk -v pat="^$i" '$0~pat {print $1}')"

			done

			unset apackages

		#	RPi
		elif (( $G_HW_MODEL < 10 )); then

			# Add raspi-copies-and-fills for 32-bit images only
			[[ $G_HW_ARCH == 3 ]] && arm_mem= || arm_mem='raspi-copies-and-fills'
			G_AGI libraspberrypi-bin libraspberrypi0 raspberrypi-bootloader raspberrypi-kernel raspberrypi-sys-mods $arm_mem

		#	Odroid C4
		elif (( $G_HW_MODEL == 16 )); then

			G_AGI linux-image-arm64-odroid-c4 meveric-keyring
			G_EXEC_NOHALT=1 G_EXEC apt-mark manual u-boot # Workaround until C4 u-boot package has been added to repo

		#	Odroid N2
		elif (( $G_HW_MODEL == 15 )); then

			G_AGI linux-image-arm64-odroid-n2 meveric-keyring

		#	Odroid N1
		elif (( $G_HW_MODEL == 14 )); then

			G_AGI linux-image-arm64-odroid-n1 meveric-keyring

		#	Odroid C2
		elif (( $G_HW_MODEL == 12 )); then

			G_AGI linux-image-arm64-odroid-c2 meveric-keyring

		#	Odroid XU3/4/HC1/HC2
		elif (( $G_HW_MODEL == 11 )); then

			G_AGI linux-image-4.14-armhf-odroid-xu4 meveric-keyring

		#	ROCK Pi S (official Radxa Debian image)
		elif (( $G_HW_MODEL == 73 )) && grep -q 'apt\.radxa\.com' /etc/apt/sources.list.d/*.list; then

			G_AGI rockpis-rk-u-boot-latest linux-4.4-rockpis-latest rockchip-overlay

		# - Auto detect kernel package incl. ARMbian/others DTB
		else

			AUTO_DETECT_KERN_PKG=$(dpkg --get-selections | mawk '/^linux-(image|dtb)/{print $1}')
			if [[ $AUTO_DETECT_KERN_PKG ]]; then

				G_AGI $AUTO_DETECT_KERN_PKG

			else

				G_DIETPI-NOTIFY 2 'Unable to find kernel packages for installation. Assuming non-APT/.deb kernel installation.'

			fi

		fi

		# - Unset Jessie workaround
		unset -f G_EXEC_PRE_FUNC

		# - Firmware
		if dpkg --get-selections | grep -q '^armbian-firmware'; then

			aPACKAGES_REQUIRED_INSTALL+=('armbian-firmware')

		else

			#	Usually no firmware should be necessary for VMs. If user manually passes though some USB device, user might need to install the firmware then.
			if (( $G_HW_MODEL != 20 )); then

				aPACKAGES_REQUIRED_INSTALL+=('firmware-realtek')		# Realtek Eth+WiFi+BT dongle firmware
				if (( $G_HW_ARCH == 10 )); then

					aPACKAGES_REQUIRED_INSTALL+=('firmware-linux')		# Misc free+nonfree firmware

				else

					aPACKAGES_REQUIRED_INSTALL+=('firmware-linux-free')	# Misc free firmware
					aPACKAGES_REQUIRED_INSTALL+=('firmware-misc-nonfree')	# Misc nonfree firmware + Ralink WiFi

				fi

			fi

			if (( $WIFI_REQUIRED )); then

				aPACKAGES_REQUIRED_INSTALL+=('firmware-atheros')		# Qualcomm/Atheros WiFi+BT dongle firmware
				aPACKAGES_REQUIRED_INSTALL+=('firmware-brcm80211')		# Breadcom WiFi dongle firmware
				aPACKAGES_REQUIRED_INSTALL+=('firmware-iwlwifi')		# Intel WiFi dongle+PCIe firmware
				if (( $G_HW_MODEL == 20 )); then

					aPACKAGES_REQUIRED_INSTALL+=('firmware-realtek')	# Realtek Eth+WiFi+BT dongle firmware
					aPACKAGES_REQUIRED_INSTALL+=('firmware-misc-nonfree')	# Misc nonfree firmware + Ralink WiFi

				fi

			fi

		fi

		G_DIETPI-NOTIFY 2 'Generating list of minimal packages, required for DietPi installation'

		local packages=$(dpkg --get-selections ${aPACKAGES_REQUIRED_INSTALL[@]} 2> /dev/null | mawk '{print $1}')
		[[ $packages ]] && G_EXEC_DESC='Marking required packages as manually installed' G_EXEC apt-mark manual $packages

		# Purging additional packages, that (in some cases) do not get autoremoved:
		# - dbus: Not required for headless images, but sometimes marked as "important", thus not autoremoved.
		#	+ Workaround for "The following packages have unmet dependencies: glib-networking libgtk-3-0"
		# - dhcpcd5: https://github.com/MichaIng/DietPi/issues/1560#issuecomment-370136642
		# - mountall: https://github.com/MichaIng/DietPi/issues/2613
		# - initscripts: Pre-installed on Jessie systems (?), superseded and masked by systemd, but never autoremoved
		#	Jessie workaround: https://github.com/MichaIng/DietPi/issues/3462
		(( $G_DISTRO < 4 )) && G_EXEC_PRE_FUNC(){ acommand[2]='--force-yes'; }
		G_AGP dbus dhcpcd5 mountall initscripts '*office*' '*xfce*' '*qt5*' '*xserver*' '*xorg*' glib-networking libgtk-3-0
		# Remove any autoremove prevention
		rm -f /etc/apt/apt.conf.d/01autoremove*
		G_AGA

		#------------------------------------------------------------------------------------------------
		echo
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP: APT installations"; ((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------

		# - Jessie workaround: https://github.com/MichaIng/DietPi/issues/3462
		(( $G_DISTRO < 4 )) && G_EXEC_PRE_FUNC(){ acommand[2]='--force-yes'; }
		G_AGDUG

		# Distro is now target (for APT purposes and G_AGX support due to installed binary, its here, instead of after G_AGUP)
		G_DISTRO=$DISTRO_TARGET
		G_DISTRO_NAME=$DISTRO_TARGET_NAME
		unset DISTRO_TARGET DISTRO_TARGET_NAME

		G_DIETPI-NOTIFY 2 'Installing core DietPi pre-req APT packages'

		G_AGI ${aPACKAGES_REQUIRED_INSTALL[@]}
		unset aPACKAGES_REQUIRED_INSTALL

		G_AGA

		#------------------------------------------------------------------------------------------------
		echo
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP: Prep system for DietPi ENV"; ((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------

		G_DIETPI-NOTIFY 2 'Deleting list of known users and groups, not required by DietPi'

		getent passwd pi &> /dev/null && userdel -f pi
		getent passwd test &> /dev/null && userdel -f test # @fourdee
		getent passwd odroid &> /dev/null && userdel -f odroid
		getent passwd rock64 &> /dev/null && userdel -f rock64
		getent passwd rock &> /dev/null && userdel -f rock # Radxa images
		getent passwd linaro &> /dev/null && userdel -f linaro # ASUS TB
		getent passwd dietpi &> /dev/null && userdel -f dietpi # recreated below
		getent passwd debian &> /dev/null && userdel -f debian # BBB
		getent passwd openmediavault-webgui &> /dev/null && userdel -f openmediavault-webgui # OMV (NanoPi NEO2)
		getent passwd admin &> /dev/null && userdel -f admin # OMV (NanoPi NEO2)
		getent passwd fa &> /dev/null && userdel -f fa # OMV (NanoPi NEO2)
		getent passwd colord &> /dev/null && userdel -f colord # OMV (NanoPi NEO2)
		getent passwd saned &> /dev/null && userdel -f saned # OMV (NanoPi NEO2)
		getent group openmediavault-config &> /dev/null && groupdel openmediavault-config # OMV (NanoPi NEO2)
		getent group openmediavault-engined &> /dev/null && groupdel openmediavault-engined # OMV (NanoPi NEO2)
		getent group openmediavault-webgui &> /dev/null && groupdel openmediavault-webgui # OMV (NanoPi NEO2)

		G_DIETPI-NOTIFY 2 'Removing misc files/folders/services, not required by DietPi'

		[[ -d '/home' ]] && rm -Rfv /home/{,.??,.[^.]}* || mkdir /home
		[[ -d '/media' ]] && rm -Rfv /media/{,.??,.[^.]}* || mkdir /media
		[[ -d '/selinux' ]] && rm -Rv /selinux
		[[ -d '/var/cache/apparmor' ]] && rm -Rv /var/cache/apparmor
		rm -Rfv /var/lib/dhcp/{,.??,.[^.]}*
		rm -Rfv /var/backups/{,.??,.[^.]}*

		# - www
		[[ -d '/var/www' ]] && rm -vRf /var/www/{,.??,.[^.]}*

		# - Sourcecode (linux-headers etc)
		[[ -d '/usr/src' ]] && rm -vRf /usr/src/{,.??,.[^.]}*

		# - Documentation dirs: https://github.com/MichaIng/DietPi/issues/3259
		#[[ -d '/usr/share/man' ]] && rm -vR /usr/share/man
		#[[ -d '/usr/share/doc' ]] && rm -vR /usr/share/doc
		#[[ -d '/usr/share/doc-base' ]] && rm -vR /usr/share/doc-base
		[[ -d '/usr/share/calendar' ]] && rm -vR /usr/share/calendar

		# - Previous debconfs
		rm -fv /var/cache/debconf/*-old
		rm -fv /var/lib/dpkg/*-old

		# - Fonts
		[[ -d '/usr/share/fonts' ]] && rm -vR /usr/share/fonts
		[[ -d '/usr/share/icons' ]] && rm -vR /usr/share/icons

		# - Stop, disable and remove not required 3rd party services
		local aservices=(

			# ARMbian
			'firstrun'
			'resize2fs'
			'log2ram'
			'*armbian*'
			'tinker-bluetooth'
			'rk3399-bluetooth'
			# Meveric
			'cpu_governor'
			# RPi
			'sshswitch'

		)

		for i in ${aservices[@]}
		do

			# Loop through known service locations
			for j in /etc/init.d/$i /{etc,lib,usr/lib}/systemd/system/$i.service{,.d}
			do

				[[ -e $j ]] || continue
				[[ -f $j ]] && systemctl disable --now ${j##*/}
				# Remove if not attached to any APT package, else mask
				if dpkg -S $j &> /dev/null; then

					systemctl mask ${j##*/}

				else
					rm -vR $j

				fi

			done

		done

		# - Remove obsolete sysvinit service entries
		aservices=(

			fake-hwclock
			haveged
			hwclock.sh
			networking
			udev
			cron
			console-setup.sh
			sudo
			cpu_governor
			keyboard-setup.sh
			kmod
			procps

		)

		for i in ${aservices[@]}
		do

			G_EXEC update-rc.d -f $i remove

		done

		# - ARMbian specific
		[[ -f '/boot/armbian_first_run.txt.template' ]] && rm -v /boot/armbian_first_run.txt.template
		[[ -f '/usr/bin/armbianmonitor' ]] && rm -v /usr/bin/armbianmonitor
		[[ -d '/etc/armbianmonitor' ]] && rm -Rv /etc/armbianmonitor
		[[ -d '/var/lib/apt-xapian-index' ]] && rm  -Rv /var/lib/apt-xapian-index
		[[ -f '/usr/local/sbin/log2ram' ]] && rm -v /usr/local/sbin/log2ram
		umount /var/log.hdd 2> /dev/null
		[[ -d '/var/log.hdd' ]] && rm -R /var/log.hdd
		[[ -f '/root/.not_logged_in_yet' ]] && rm -v /root/.not_logged_in_yet
		[[ -f '/root/.desktop_autologin' ]] && rm -v /root/.desktop_autologin
		rm -vf /etc/X11/xorg.conf.d/*armbian*
		#rm -vf /etc/armbian* armbian-release # Required for kernel/bootloader package upgrade (initramfs postinst)
		rm -vf /lib/systemd/system/*armbian*
		rm -vf /etc/systemd/system/logrotate.service # Override to support Armbian zRAM log
		rm -vf /etc/apt/apt.conf.d/*armbian*
		rm -vf /etc/cron.*/*armbian*
		#rm -vf /etc/default/*armbian* # Required for ARMbian root package upgrade
		rm -vf /etc/update-motd.d/*armbian*
		rm -vf /etc/profile.d/*armbian*
		#[[ -d '/usr/lib/armbian' ]] && rm -vR /usr/lib/armbian # Required for ARMbian root package upgrade
		#[[ -d '/usr/share/armbian' ]] && rm -vR /usr/share/armbian # Required for ARMbian root package upgrade
		# Place DPKG exclude file, especially to skip cron jobs, which are doomed to fail and an unnecessary overhead + syslog spam on DietPi
		[[ -f '/etc/armbian-release' ]] && cat << _EOF_ > /etc/dpkg/dpkg.cfg.d/dietpi-no_armbian
# Exclude conflicting ARMbian files
path-exclude /lib/systemd/system/*armbian*
path-exclude /etc/systemd/system/logrotate.service
path-exclude /etc/apt/apt.conf.d/*armbian*
path-exclude /etc/cron.*/*armbian*
#path-exclude /etc/default/*armbian* # Required for ARMbian root package upgrade
path-exclude /etc/update-motd.d/*armbian*
path-exclude /etc/profile.d/*armbian*
#path-exclude /usr/lib/armbian # Required for ARMbian root package upgrade
#path-exclude /usr/share/armbian # Required for ARMbian root package upgrade
_EOF_

		# - OMV: https://github.com/MichaIng/DietPi/issues/2994
		[[ -d '/etc/openmediavault' ]] && rm -vR /etc/openmediavault
		rm -vf /etc/cron.*/openmediavault*
		rm -vf /usr/sbin/omv-*

		# - Meveric specific
		[[ -f '/usr/local/sbin/setup-odroid' ]] && rm -v /usr/local/sbin/setup-odroid
		[[ -d '/root/scripts' ]] && rm -R /root/scripts
		[[ -f '/root/resize--log.txt' ]] && rm /root/resize--log.txt
		rm -fv /installed-packages*.txt

		# - RPi specific: https://github.com/MichaIng/DietPi/issues/1631#issuecomment-373965406
		[[ -f '/etc/profile.d/wifi-country.sh' ]] && rm -v /etc/profile.d/wifi-country.sh
		[[ -f '/etc/sudoers.d/010_pi-nopasswd' ]] && rm -v /etc/sudoers.d/010_pi-nopasswd
		[[ -d '/etc/systemd/system/dhcpcd.service.d' ]] && rm -vR /etc/systemd/system/dhcpcd.service.d # https://github.com/RPi-Distro/pi-gen/blob/master/stage3/01-tweaks/00-run.sh
		#	Do not ship rc.local anymore. On DietPi /var/lib/dietpi/postboot.d should be used.
		#	WIP: Mask rc-local.service and create symlink postboot.d/rc.local => /etc/rc.local for backwards compatibility?
		[[ -f '/etc/rc.local' ]] && rm -v /etc/rc.local # https://github.com/RPi-Distro/pi-gen/blob/master/stage2/01-sys-tweaks/files/rc.local
		#	Below required if DietPi-PREP is executed from chroot/container, so RPi firstrun scripts are not executed
		[[ -f '/etc/init.d/resize2fs_once' ]] && rm -v /etc/init.d/resize2fs_once # https://github.com/RPi-Distro/pi-gen/blob/master/stage2/01-sys-tweaks/files/resize2fs_once
		[[ -f '/boot/cmdline.txt' ]] && sed -i 's| init=/usr/lib/raspi-config/init_resize\.sh||' /boot/cmdline.txt # https://github.com/RPi-Distro/pi-gen/blob/master/stage2/01-sys-tweaks/00-patches/07-resize-init.diff
		# - Remove all autologin configs for all TTYs: https://github.com/MichaIng/DietPi/issues/3570#issuecomment-648988475, https://github.com/MichaIng/DietPi/issues/3628#issuecomment-653693758
		rm -fv /etc/systemd/system/*getty@*.service.d/*autologin*.conf

		# - make_nas_processes_faster cron job on ROCK64 + NanoPi + PINE A64(?) images
		[[ -f '/etc/cron.d/make_nas_processes_faster' ]] && rm /etc/cron.d/make_nas_processes_faster

		#-----------------------------------------------------------------------------------
		# https://www.debian.org/doc/debian-policy/ch-opersys.html#site-specific-programs
		G_DIETPI-NOTIFY 2 'Setting modern /usr/local permissions'
		[[ -f '/etc/staff-group-for-usr-local' ]] && rm -v /etc/staff-group-for-usr-local
		chown -R root:root /usr/local
		chmod -R 0755 /usr/local

		#-----------------------------------------------------------------------------------
		# Boot Logo
		[[ -f '/boot/boot.bmp' ]] && G_EXEC wget https://github.com/$G_GITOWNER/DietPi/raw/$G_GITBRANCH/.meta/images/dietpi-logo_boot.bmp -O /boot/boot.bmp

		#-----------------------------------------------------------------------------------
		# Bash Profiles

		# - Pre v6.9 cleaning:
		[[ -f '/root/.bashrc' ]] && sed -i '/\/DietPi/d' /root/.bashrc
		[[ -f '/home/dietpi/.bashrc' ]] && sed -i '/\/DietPi/d' /home/dietpi/.bashrc
		rm -vf /etc/profile.d/99-dietpi*

		# - Enable /etc/bashrc.d/ support for custom interactive non-login shell scripts:
		sed -i '\#/etc/bashrc\.d/#d' /etc/bash.bashrc
		echo 'for i in /etc/bashrc.d/*.sh /etc/bashrc.d/*.bash; do [ -r "$i" ] && . $i; done; unset i' >> /etc/bash.bashrc

		# - Enable bash-completion for non-login shells:
		#	- NB: It is called twice on login shells then, but breaks directly if called already once.
		ln -sfv /etc/profile.d/bash_completion.sh /etc/bashrc.d/dietpi-bash_completion.sh

		#-----------------------------------------------------------------------------------
		# DietPi user
		G_EXEC_DESC='Creating DietPi user account' G_EXEC /boot/dietpi/func/dietpi-set_software useradd dietpi

		#-----------------------------------------------------------------------------------
		# UID bit for sudo: https://github.com/MichaIng/DietPi/issues/794
		G_DIETPI-NOTIFY 2 'Setting sudo UID bit'
		chmod 4755 $(command -v sudo)

		#-----------------------------------------------------------------------------------
		# Dirs
		G_DIETPI-NOTIFY 2 'Generating DietPi Directories'
		mkdir -pv /var/lib/dietpi/{postboot.d,dietpi-software/installed}
		mkdir -pv /var/tmp/dietpi/logs/dietpi-ramlog_store
		mkdir -pv $G_FP_DIETPI_USERDATA /mnt/{samba,ftp_client,nfs_client}
		chown -R dietpi:dietpi /var/{lib,tmp}/dietpi $G_FP_DIETPI_USERDATA /mnt/{samba,ftp_client,nfs_client}
		chmod -R 775 $(find /var/{lib,tmp}/dietpi $G_FP_DIETPI_USERDATA /mnt/{samba,ftp_client,nfs_client} -type d)

		#-----------------------------------------------------------------------------------
		# Services
		G_DIETPI-NOTIFY 2 'Enabling DietPi services'
		G_EXEC systemctl enable dietpi-ramlog
		G_EXEC systemctl enable dietpi-preboot
		G_EXEC systemctl enable dietpi-boot
		G_EXEC systemctl enable dietpi-postboot
		G_EXEC systemctl enable dietpi-kill_ssh

		#-----------------------------------------------------------------------------------
		# Install vmtouch to lock DietPi scripts and config in file system cache
		G_EXEC wget https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/vmtouch_$G_HW_ARCH_NAME.deb
		G_EXEC dpkg --force-hold,confnew -i vmtouch_$G_HW_ARCH_NAME.deb
		rm vmtouch_$G_HW_ARCH_NAME.deb

		#-----------------------------------------------------------------------------------
		# Cron jobs
		G_EXEC_DESC='Configuring Cron'
		G_EXEC eval 'cat << _EOF_ > /etc/crontab
# Please use dietpi-cron to change cron start times
SHELL=/bin/dash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=""

# m h dom mon dow user command
#*/0 * * * * root cd / && run-parts --report /etc/cron.minutely
17 * * * * root cd / && run-parts --report /etc/cron.hourly
25 1 * * * root test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.daily; }
47 1 * * 7 root test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.weekly; }
52 1 1 * * root test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.monthly; }
_EOF_'

		#-----------------------------------------------------------------------------------
		# Network
		G_DIETPI-NOTIFY 2 'Configuring wlan/eth naming to be preferred for networked devices:'
		ln -sfv /dev/null /etc/systemd/network/99-default.link
		ln -sfv /dev/null /etc/udev/rules.d/80-net-setup-link.rules
		# - RPi: Add cmdline entry, which was required on my Raspbian Bullseye system since last few APT updates
		if [[ -f '/boot/cmdline.txt' ]]; then

			sed -i 's/net.ifnames=[^[:blank:]]*[[:blank:]]*//g;w /dev/stdout' /boot/cmdline.txt
			sed -i '/root=/s/[[:blank:]]*$/ net.ifnames=0/;w /dev/stdout' /boot/cmdline.txt

		fi
		[[ -f '/etc/udev/rules.d/70-persistent-net.rules' ]] && rm -v /etc/udev/rules.d/70-persistent-net.rules # Jessie pre-image

		G_DIETPI-NOTIFY 2 'Resetting and adding dietpi.com SSH pub host key for DietPi-Survey/Bugreport uploads:'
		mkdir -pv /root/.ssh
		echo 'ssh.dietpi.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDE6aw3r6aOEqendNu376iiCHr9tGBIWPgfrLkzjXjEsHGyVSUFNnZt6pftrDeK7UX+qX4FxOwQlugG4fymOHbimRCFiv6cf7VpYg1Ednquq9TLb7/cIIbX8a6AuRmX4fjdGuqwmBq3OG7ZksFcYEFKt5U4mAJIaL8hXiM2iXjgY02LqiQY/QWATsHI4ie9ZOnwrQE+Rr6mASN1BVFuIgyHIbwX54jsFSnZ/7CdBMkuAd9B8JkxppWVYpYIFHE9oWNfjh/epdK8yv9Oo6r0w5Rb+4qaAc5g+RAaknHeV6Gp75d2lxBdCm5XknKKbGma2+/DfoE8WZTSgzXrYcRlStYN' > /root/.ssh/known_hosts

		G_DIETPI-NOTIFY 2 'Configuring DNS nameserver:'
		# Failsafe: Assure that /etc/resolv.conf is not a symlink and disable systemd-resolved
		systemctl disable --now systemd-resolved
		rm -fv /etc/resolv.conf
		echo 'nameserver 9.9.9.9' > /etc/resolv.conf # Apply generic functional DNS nameserver, updated on next service start

		# ifupdown starts the daemon outside of systemd, the enabled systemd unit just thows an error on boot due to missing dbus and with dbus might interfere with ifupdown
		systemctl disable wpa_supplicant 2> /dev/null && G_DIETPI-NOTIFY 2 'Disabled non-required wpa_supplicant systemd unit'

		[[ -L '/etc/network/interfaces' ]] && rm -v /etc/network/interfaces # ARMbian symlink for bulky network-manager
		G_EXEC_DESC='Configuring network interfaces'
		G_EXEC eval 'cat << _EOF_ > /etc/network/interfaces
# Location: /etc/network/interfaces
# Please modify network settings via: dietpi-config
# Or create your own drop-ins in: /etc/network/interfaces.d/

# Drop-in configs
source interfaces.d/*

# Loopback
auto lo
iface lo inet loopback

# Ethernet
#allow-hotplug eth0
iface eth0 inet dhcp
address 192.168.0.100
netmask 255.255.255.0
gateway 192.168.0.1
#dns-nameservers 9.9.9.9 149.112.112.112

# WiFi
#allow-hotplug wlan0
iface wlan0 inet dhcp
address 192.168.0.100
netmask 255.255.255.0
gateway 192.168.0.1
wireless-power off
wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
#dns-nameservers 9.9.9.9 149.112.112.112
_EOF_'
		#-----------------------------------------------------------------------------------
		# MISC
		G_DIETPI-NOTIFY 2 'Disabling apt-daily services to prevent random APT cache lock'
		for i in apt-daily{,-upgrade}.{service,timer}
		do

			systemctl disable --now $i 2> /dev/null
			systemctl mask $i 2> /dev/null

		done

		G_DIETPI-NOTIFY 2 'Disabling e2scrub services which are for LVM and require lvm2/lvcreate being installed'
		systemctl disable --now e2scrub_all.timer 2> /dev/null
		systemctl disable --now e2scrub_reap 2> /dev/null

		(( $G_HW_MODEL > 9 )) && echo $G_HW_MODEL > /etc/.dietpi_hw_model_identifier
		G_EXEC_DESC='Generating /boot/dietpi/.hw_model' G_EXEC /boot/dietpi/func/dietpi-obtain_hw_model

		G_EXEC_DESC='Generating /etc/fstab' G_EXEC /boot/dietpi/dietpi-drive_manager 4

		# Create and navigate to "/tmp/$G_PROGRAM_NAME" working directory, now assured to be tmpfs
		mkdir -p /tmp/$G_PROGRAM_NAME
		cd /tmp/$G_PROGRAM_NAME

		local info_use_drive_manager='Can be installed and setup by DietPi-Drive_Manager.\nSimply run "dietpi-drive_manager" and select "Add network drive".'
		echo -e "Samba client: $info_use_drive_manager" > /mnt/samba/readme.txt
		echo -e "NFS client: $info_use_drive_manager" > /mnt/nfs_client/readme.txt

		G_DIETPI-NOTIFY 2 'Restoring original MOTD:'
		rm -fv /etc/motd
		cp -v /usr/share/base-files/motd /etc/motd

		# Add pre-up lines for WiFi on OrangePi Zero
		if (( $G_HW_MODEL == 32 )); then

			sed -i '/iface wlan0 inet dhcp/apre-up modprobe xradio_wlan\npre-up iwconfig wlan0 power on' /etc/network/interfaces

		# ASUS TB WiFi: https://github.com/MichaIng/DietPi/issues/1760
		elif (( $G_HW_MODEL == 52 )); then

			G_CONFIG_INJECT '8723bs' '8723bs' /etc/modules

		fi

		# Fix wireless-tools bug on Stretch: https://bugs.debian.org/908886
		[[ -f '/etc/network/if-pre-up.d/wireless-tools' ]] && sed -i '\|^[[:blank:]]ifconfig "$IFACE" up$|c\\t/sbin/ip link set dev "$IFACE" up' /etc/network/if-pre-up.d/wireless-tools

		G_DIETPI-NOTIFY 2 'Tweaking DHCP timeout:' # https://github.com/MichaIng/DietPi/issues/711
		G_CONFIG_INJECT 'timeout[[:blank:]]' 'timeout 10;' /etc/dhcp/dhclient.conf
		G_CONFIG_INJECT 'retry[[:blank:]]' 'retry 4;' /etc/dhcp/dhclient.conf

		echo 'DietPi' > /etc/hostname
		G_EXEC_DESC='Configuring hostname and hosts'
		G_EXEC eval 'cat << _EOF_ > /etc/hosts
127.0.0.1 localhost
127.0.1.1 DietPi
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
_EOF_'

		G_EXEC_DESC='Configuring htop'
		G_EXEC eval 'cat << _EOF_ > /etc/htoprc
# DietPi default config for htop
# Location: /etc/htoprc
# NB: htop will create "~/.config/htop/htoprc" per-user based on this defaults, when opened the first time.
#     Use setup (F2) within htop GUI or edit "~/.config/htop/htoprc" to change settings according to your needs.
fields=0 48 39 18 46 49 1
sort_key=46
sort_direction=1
hide_threads=0
hide_kernel_threads=1
hide_userland_threads=1
shadow_other_users=0
show_thread_names=0
show_program_path=1
highlight_base_name=1
highlight_megabytes=1
highlight_threads=0
tree_view=1
header_margin=0
detailed_cpu_time=0
cpu_count_from_zero=1
update_process_names=0
account_guest_in_cpu_meter=0
color_scheme=0
delay=15
left_meters=AllCPUs CPU
left_meter_modes=1 1
right_meters=Memory Swap Tasks LoadAverage Uptime
right_meter_modes=1 1 2 2 2
_EOF_'

		G_DIETPI-NOTIFY 2 'Configuring fake-hwclock:'
		systemctl stop fake-hwclock
		# Allow times in the past
		G_CONFIG_INJECT 'FORCE=' 'FORCE=force' /etc/default/fake-hwclock
		systemctl restart fake-hwclock # Failsafe, apply now if date is way far back...

		G_DIETPI-NOTIFY 2 'Configuring serial login consoles:'
		# On virtual machines, serial consoles are not required
		if (( $G_HW_MODEL == 20 )); then

			/boot/dietpi/func/dietpi-set_hardware serialconsole disable

		else

			/boot/dietpi/func/dietpi-set_hardware serialconsole enable
			# On RPi the primary serial console depends on model, use "serial0" which links to the primary console, converts to correct device on first boot
			if (( $G_HW_MODEL < 10 )); then

				/boot/dietpi/func/dietpi-set_hardware serialconsole disable ttyAMA0
				/boot/dietpi/func/dietpi-set_hardware serialconsole disable ttyS0
				/boot/dietpi/func/dietpi-set_hardware serialconsole enable serial0

			fi

		fi

		G_DIETPI-NOTIFY 2 'Reducing getty count and resource usage:'
		systemctl mask getty-static
		# - logind features disabled by default. Usually not needed and all features besides auto getty creation are not available without libpam-systemd package.
		#	- It will be unmasked/enabled, automatically if libpam-systemd got installed during dietpi-software install, usually with desktops.
		systemctl disable --now systemd-logind 2> /dev/null
		systemctl mask systemd-logind

		G_DIETPI-NOTIFY 2 'Configuring regional settings (TZdata):'
		rm -fv /etc/{localtime,timezone}
		ln -sv /usr/share/zoneinfo/UTC /etc/localtime
		G_EXEC dpkg-reconfigure -f noninteractive tzdata

		G_DIETPI-NOTIFY 2 'Configuring regional settings (Keyboard):'
		dpkg-reconfigure -f noninteractive keyboard-configuration # Keyboard must be plugged in for this to work!

		#G_DIETPI-NOTIFY 2 "Configuring regional settings (Locale):" # Runs at start of script

		# G_HW_ARCH specific
		G_DIETPI-NOTIFY 2 'Applying G_HW_ARCH specific tweaks:'
		if (( $G_HW_ARCH == 10 )); then

			G_EXEC_DESC='Removing foreign i386 DPKG architecture' G_EXEC dpkg --remove-architecture i386

			# Disable nouveau: https://github.com/MichaIng/DietPi/issues/1244 // https://dietpi.com/phpbb/viewtopic.php?p=9688#p9688
			rm -f /etc/modprobe.d/*nouveau*
			cat << _EOF_ > /etc/modprobe.d/dietpi-disable_nouveau.conf
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
_EOF_

			# Apply usb-storage quirks to disable UAS for unsupported drives (Seagate ST5000LM000-2AN170): https://github.com/MichaIng/DietPi/issues/2905
			echo 'options usb-storage quirks=0bc2:ab30:u' > /etc/modprobe.d/dietpi-usb-storage_quirks.conf

			# Update initramfs with above changes
			if command -v update-tirfs &> /dev/null; then

				update-tirfs

			else

				update-initramfs -u

			fi

		elif (( $G_HW_ARCH == 3 )); then

			(( $G_HW_MODEL > 9 )) && G_EXEC_DESC='Removing foreign armhf DPKG architecture' G_EXEC dpkg --remove-architecture armhf

		fi

		# G_HW_MODEL specific
		G_DIETPI-NOTIFY 2 'Applying G_HW_MODEL specific tweaks:'
		if (( $G_HW_MODEL != 20 )); then

			G_EXEC_DESC='Configuring hdparm'
			# Since Debian Bullseye, spindown_time is not applied if APM is not supported by the drive. force_spindown_time is required to override that.
			local spindown='spindown_time'
			(( $G_DISTRO > 5 )) && spindown='force_spindown_time'
			G_EXEC eval 'cat << _EOF_ > /etc/hdparm.conf
apm = 127
$spindown = 120
_EOF_'
			unset spindown

		fi

		# - ARMbian OPi Zero 2: https://github.com/MichaIng/DietPi/issues/876#issuecomment-294350580
		if (( $G_HW_MODEL == 35 )); then

			echo 'blacklist bmp085' > /etc/modprobe.d/dietpi-disable_bmp085.conf

		# - Sparky SBC
		elif (( $G_HW_MODEL == 70 )); then

			# Install latest kernel/drivers
			G_EXEC wget https://raw.githubusercontent.com/sparky-sbc/sparky-test/master/dragon_fly_check/uImage -O /boot/uImage
			G_EXEC wget https://raw.githubusercontent.com/sparky-sbc/sparky-test/master/dragon_fly_check/3.10.38.bz2
			G_EXEC tar -xf 3.10.38.bz2 -C /lib/modules/
			rm 3.10.38.bz2
			# - USB audio update
			G_EXEC wget https://raw.githubusercontent.com/sparky-sbc/sparky-test/master/dsd-marantz/snd-usb-audio.ko -O /lib/modules/3.10.38/kernel/sound/usb/snd-usb-audio.ko
			# - Ethernet update
			G_EXEC wget https://raw.githubusercontent.com/sparky-sbc/sparky-test/master/sparky-eth/ethernet.ko -O /lib/modules/3.10.38/kernel/drivers/net/ethernet/acts/ethernet.ko

			# Boot args
			cat << _EOF_ > /boot/uenv.txt
uenvcmd=setenv os_type linux;
bootargs=earlyprintk clk_ignore_unused selinux=0 scandelay console=tty0 loglevel=1 real_rootflag=rw root=/dev/mmcblk0p2 rootwait init=/lib/systemd/systemd aotg.urb_fix=1 aotg.aotg1_speed=0 net.ifnames=0
_EOF_

			# Blacklist GPU and touch screen modules: https://github.com/MichaIng/DietPi/issues/699#issuecomment-271362441
			cat << _EOF_ > /etc/modprobe.d/dietpi-disable_sparkysbc_touchscreen.conf
blacklist owl_camera
blacklist gsensor_stk8313
blacklist ctp_ft5x06
blacklist ctp_gsl3680
blacklist gsensor_bma222
blacklist gsensor_mir3da
_EOF_

			cat << _EOF_ > /etc/modprobe.d/dietpi-disable_sparkysbc_gpu.conf
blacklist pvrsrvkm
blacklist drm
blacklist videobuf2_vmalloc
blacklist bc_example
_EOF_

			# Use performance gov for stability
			G_CONFIG_INJECT 'CONFIG_CPU_GOVERNOR=' 'CONFIG_CPU_GOVERNOR=performance' /boot/dietpi.txt

			# Install script to toggle between USB and onboard Ethernet automatically
			cat << _EOF_ > /var/lib/dietpi/services/dietpi-sparkysbc_ethernet.sh
#!/bin/dash
# Called from: /etc/systemd/system/dietpi-sparkysbc_ethernet.service
# We need to wait until USB Ethernet is established on USB bus, which takes much longer than onboard init.
sleep 20
# Disable onboard Ethernet if USB Ethernet is found
if ip a s eth1 > /dev/null 2>&1; then

	echo 'blacklist ethernet' > /etc/modprobe.d/dietpi-disable_sparkysbc_ethernet.conf
	reboot

# Enable onboard Ethernet if no adapter is found
elif ! ip a s eth0 > /dev/null 2>&1; then

	rm -f /etc/modprobe.d/dietpi-disable_sparkysbc_ethernet.conf
	reboot

fi
_EOF_
			chmod +x /var/lib/dietpi/services/dietpi-sparkysbc_ethernet.sh
			cat << _EOF_ > /etc/systemd/system/dietpi-sparkysbc_ethernet.service
[Unit]
Description=Sparky SBC auto detect and toggle onboard/USB Ethernet
Wants=network-online.target
After=network-online.target

[Service]
RemainAfterExit=yes
ExecStart=/var/lib/dietpi/services/dietpi-sparkysbc_ethernet.sh

[Install]
WantedBy=multi-user.target
_EOF_
			systemctl enable dietpi-sparkysbc_ethernet

		# - RPi
		elif (( $G_HW_MODEL < 10 )); then

			# Scroll lock fix for RPi by Midwan: https://github.com/MichaIng/DietPi/issues/474#issuecomment-243215674
			cat << _EOF_ > /etc/udev/rules.d/50-leds.rules
ACTION=="add", SUBSYSTEM=="leds", ENV{DEVPATH}=="*/input*::scrolllock", ATTR{trigger}="kbd-scrollock"
_EOF_

			# Disable RPi camera to add modules blacklist
			/boot/dietpi/func/dietpi-set_hardware rpi-camera disable

			# Update USBridgeSig Ethernet driver via postinst kernel script, until it has been merged into official RPi kernel: https://github.com/allocom/USBridgeSig/tree/master/ethernet
			cat << _EOF_ > /etc/kernel/postinst.d/dietpi-USBridgeSig
#!/bin/bash
# Only apply to ARMv7+ kernel
[[ \$1 == *'-v7+' ]] || exit 0
echo "[ INFO ] Updating asix ax88179 driver for kernel \$1, as provided by allo.com:"
echo '[ INFO ] - https://github.com/allocom/USBridgeSig/tree/master/ethernet'
echo '[ INFO ] Downloading driver...'
wget http://3.230.113.73:9011/Allocom/USBridgeSig/rpi-usbs-\$1/ax88179_178a.ko -O /tmp/ax88179_178a.ko || exit 0
echo '[ INFO ] Installing driver...'
install -vpm 644 /tmp/ax88179_178a.ko /lib/modules/\$1/kernel/drivers/net/usb || exit 0
echo '[ INFO ] Running depmod...'
depmod \$1 || exit 0
echo '[ INFO ] Cleaning up...'
rm -v /tmp/ax88179_178a.ko || exit 0
_EOF_
			chmod +x /etc/kernel/postinst.d/dietpi-USBridgeSig
			# - Update for all installed ARMv7+ kernel versions now
			for i in /lib/modules/*-v7+
			do

				[[ -d $i ]] || continue
				i=${i##*/}
				/etc/kernel/postinst.d/dietpi-USBridgeSig $i

			done

		# - Pine A64 (and possibily others): Cursor fix for FB
		elif (( $G_HW_MODEL == 40 )); then

			cat << _EOF_ > /etc/bashrc.d/dietpi-pine64-cursorfix.sh
#!/bin/dash
# DietPi: Cursor fix for FB
infocmp > terminfo.txt
sed -i -e 's/?0c/?112c/g' -e 's/?8c/?48;0;64c/g' terminfo.txt
tic terminfo.txt
tput cnorm
_EOF_

			# Ensure WiFi module pre-exists
			G_CONFIG_INJECT '8723bs' '8723bs' /etc/modules

		fi

		# - ARMbian special
		if [[ -f '/boot/armbianEnv.txt' ]]; then

			# Reset default kernel log verbosity, reduced to "1" on most Armbian images
			sed -i '/verbosity=/c\verbosity=4' /boot/armbianEnv.txt

			# Disable Docker optimisations, since this has some performance drawbacks, enable on Docker install instead
			G_CONFIG_INJECT 'docker_optimizations=' 'docker_optimizations=off' /boot/armbianEnv.txt

		fi

		#------------------------------------------------------------------------------------------------
		echo
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP: Finalise system for first run of DietPi"; ((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------

		G_EXEC_DESC='Enable Dropbear autostart' G_EXEC sed -i '/NO_START=1/c\NO_START=0' /etc/default/dropbear
		G_EXEC systemctl unmask dropbear
		G_EXEC systemctl enable dropbear

		G_DIETPI-NOTIFY 2 'Configuring services'
		/boot/dietpi/dietpi-services stop
		/boot/dietpi/dietpi-services dietpi_controlled

		G_DIETPI-NOTIFY 2 'Mask cron until 1st run setup is completed'
		G_EXEC systemctl mask cron

		G_DIETPI-NOTIFY 2 'Removing swapfile from image'
		/boot/dietpi/func/dietpi-set_swapfile 0 /var/swap
		[[ -e '/var/swap' ]] && rm -v /var/swap # still exists on some images...
		# - Re-enable for next run
		G_CONFIG_INJECT 'AUTO_SETUP_SWAPFILE_SIZE=' 'AUTO_SETUP_SWAPFILE_SIZE=1' /boot/dietpi.txt
		# - Reset /tmp size to default (512 MiB)
		sed -i '\|/tmp|s|size=[^,]*,||' /etc/fstab

		G_DIETPI-NOTIFY 2 'Resetting boot.ini, config.txt, cmdline.txt etc'

		# - Set Pi cmdline.txt back to normal
		[[ -f '/boot/cmdline.txt' ]] && sed -i 's/ rootdelay=10//g' /boot/cmdline.txt

		G_DIETPI-NOTIFY 2 'Disabling generic BT by default'
		/boot/dietpi/func/dietpi-set_hardware bluetooth disable

		# - Set WiFi
		local tmp_info='Disabling'
		local tmp_mode='disable'
		if (( $WIFI_REQUIRED )); then

			G_DIETPI-NOTIFY 2 'Generating default wpa_supplicant.conf'
			/boot/dietpi/func/dietpi-wifidb 1
			# Move to /boot/ so users can modify as needed for automated
			G_EXEC mv /var/lib/dietpi/dietpi-wifi.db /boot/dietpi-wifi.txt

			tmp_info='Enabling'
			tmp_mode='enable'

		fi

		G_DIETPI-NOTIFY 2 "$tmp_info onboard WiFi modules by default"
		/boot/dietpi/func/dietpi-set_hardware wifimodules onboard_$tmp_mode

		G_DIETPI-NOTIFY 2 "$tmp_info generic WiFi by default"
		/boot/dietpi/func/dietpi-set_hardware wifimodules $tmp_mode

		# - x86_64: kernel cmd line with GRUB
		if (( $G_HW_ARCH == 10 )); then

			G_EXEC_DESC='Detecting additional OS installed on system' G_EXEC os-prober
			# Purge "os-prober" again
			G_AGP os-prober
			G_AGA

			# - Native PC/EFI (assume x86_64 only possible)
			if [[ -d '/boot/efi' ]] && dpkg-query -s 'grub-efi-amd64' &> /dev/null; then

				G_EXEC_DESC='Recreating GRUB-EFI' G_EXEC grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch_grub --recheck

			fi

			# - Finalise GRUB
			if [[ -f '/etc/default/grub' ]]; then

				G_CONFIG_INJECT 'GRUB_CMDLINE_LINUX_DEFAULT=' 'GRUB_CMDLINE_LINUX_DEFAULT="consoleblank=0 quiet"' /etc/default/grub
				G_CONFIG_INJECT 'GRUB_CMDLINE_LINUX=' 'GRUB_CMDLINE_LINUX="net.ifnames=0"' /etc/default/grub
				G_CONFIG_INJECT 'GRUB_TIMEOUT=' 'GRUB_TIMEOUT=0' /etc/default/grub
				G_EXEC_DESC='Finalising GRUB' G_EXEC update-grub

			fi

		fi

		G_DIETPI-NOTIFY 2 'Disabling soundcards by default'
		/boot/dietpi/func/dietpi-set_hardware soundcard none

		G_DIETPI-NOTIFY 2 'Setting default CPU gov'
		/boot/dietpi/func/dietpi-set_cpu

		G_DIETPI-NOTIFY 2 'Resetting DietPi auto-generated settings and flag files'
		rm -v /boot/dietpi/.??*

		G_DIETPI-NOTIFY 2 'Set init .install_stage to -1 (first boot)'
		echo -1 > /boot/dietpi/.install_stage

		G_DIETPI-NOTIFY 2 'Writing PREP information to file'
		cat << _EOF_ > /boot/dietpi/.prep_info
$IMAGE_CREATOR
$PREIMAGE_INFO
_EOF_

		G_DIETPI-NOTIFY 2 'Generating GPLv2 license readme'
		cat << _EOF_ > /var/lib/dietpi/license.txt
-----------------------
DietPi - GPLv2 License:
-----------------------
 - Use arrow keys to scroll
 - Press 'TAB' then 'ENTER' to continue

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 2 of the License, or any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, please see http://www.gnu.org/licenses/
_EOF_

		G_DIETPI-NOTIFY 2 'Disabling and clearing APT cache'
		/boot/dietpi/func/dietpi-set_software apt-cache cache disable
		/boot/dietpi/func/dietpi-set_software apt-cache clean

		# BBB remove fsexpansion: https://github.com/MichaIng/DietPi/issues/931#issuecomment-345451529
		if (( $G_HW_MODEL == 71 )); then

			systemctl disable dietpi-fs_partition_resize
			rm -v /etc/systemd/system/dietpi-fs_partition_resize.service
			rm -v /var/lib/dietpi/services/fs_partition_resize.sh

		else

			G_EXEC_DESC='Enabling automated partition and file system resize for first boot' G_EXEC systemctl enable dietpi-fs_partition_resize

		fi
		G_EXEC_DESC='Enabling first boot installation process' G_EXEC systemctl enable dietpi-firstboot

		G_DIETPI-NOTIFY 2 'Storing DietPi version info:'
		G_CONFIG_INJECT 'DEV_GITBRANCH=' "DEV_GITBRANCH=$G_GITBRANCH" /boot/dietpi.txt
		G_CONFIG_INJECT 'DEV_GITOWNER=' "DEV_GITOWNER=$G_GITOWNER" /boot/dietpi.txt
		G_VERSIONDB_SAVE
		G_EXEC cp /boot/dietpi/.version /var/lib/dietpi/.dietpi_image_version

		G_DIETPI-NOTIFY 2 'Clearing lost+found'
		rm -Rfv /lost+found/{,.??,.[^.]}*

		G_DIETPI-NOTIFY 2 'Clearing DietPi logs, written during PREP'
		rm -Rfv /var/tmp/dietpi/logs/{,.??,.[^.]}*

		G_DIETPI-NOTIFY 2 'Clearing items below tmpfs mount points'
		G_EXEC mkdir -p /mnt/tmp_root
		G_EXEC mount $(findmnt -no source /) /mnt/tmp_root
		rm -vRf /mnt/tmp_root/{dev,proc,run,sys,tmp,var/log}/{,.??,.[^.]}*
		G_EXEC umount /mnt/tmp_root
		G_EXEC rmdir /mnt/tmp_root

		G_DIETPI-NOTIFY 2 'Running general cleanup of misc files'
		rm -Rfv /{root,home/*}/.{bash_history,nano_history,wget-hsts,cache,local,config,gnupg,viminfo,dbus,gconf,nano,vim}

		# Remove PREP script
		[[ -f $FP_PREP_SCRIPT ]] && rm -v $FP_PREP_SCRIPT

		sync

		G_DIETPI-NOTIFY 2 "The used kernel version is:\n\t - $(uname -a)"
		kernel_apt_packages=$(dpkg -l | grep -E '[[:blank:]]linux-(image|dtb)-[0-9]')
		if [[ $kernel_apt_packages ]]; then

			G_DIETPI-NOTIFY 2 'The following kernel APT packages have been found, please purge outdated ones:'
			echo "$kernel_apt_packages"

		fi

		G_DIETPI-NOTIFY 2 'Please delete outdated non-APT kernel modules:'
		ls -lAh /lib/modules

		G_DIETPI-NOTIFY 2 'Please check and delete all non-required home diretory content:'
		ls -lAh /root /home/*/

		G_DIETPI-NOTIFY 0 'Completed, disk can now be saved to .img for later use, or, reboot system to start first run of DietPi.'

		# Power off system

		# Plug SDcard/drive into external DietPi system

		# Run: bash -c "$(curl -sSL https://github.com/MichaIng/DietPi/blob/dev/.meta/dietpi-imager)"

	}

	#------------------------------------------------------------------------------------------------
	Main
	#------------------------------------------------------------------------------------------------
}
