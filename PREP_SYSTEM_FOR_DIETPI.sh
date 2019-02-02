#!/bin/bash
{
	#------------------------------------------------------------------------------------------------
	# Optimize current Debian installation and prep for DietPi installation.
	#------------------------------------------------------------------------------------------------
	# REQUIREMENTS
	# - Currently running Debian (ideally minimal, eg: Raspbian Lite-ish =)) )
	# - systemd as system/init/service manager
	# - Either eth0 connection or local (non-SSH) terminal access
	#------------------------------------------------------------------------------------------------
	# Dev notes:
	# Following items must be exported or assigned to DietPi scripts, if used, until dietpi-obtain_hw_model is executed.
	# - G_HW_MODEL
	# - G_HW_ARCH
	# - G_DISTRO
	# - G_DISTRO_NAME
	#------------------------------------------------------------------------------------------------

	#Core globals
	G_PROGRAM_NAME='DietPi-PREP'
	GITOWNER=${GITOWNER:-Fourdee}

	#------------------------------------------------------------------------------------------------
	# Critical checks and pre-reqs, with exit, prior to initial run of script
	#------------------------------------------------------------------------------------------------
	#Exit path for non-root logins
	if (( $UID )); then

		echo -e 'ERROR: Root privileges required, please run the script with "sudo"\nIn case install the "sudo" package with root privileges:\n\t# apt-get install -y sudo\n'
		exit 1

	fi

	#Work inside /tmp as usually ramfs to reduce disk I/O and speed up download and unpacking
	# - Save full script path, beforehand: https://github.com/Fourdee/DietPi/pull/2341#discussion_r241784962
	FP_PREP_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
	cd /tmp

	#Prefer IPv4 by default, to avoid hanging access attempts in some cases
	# - NB: This needs to match the method in: /DietPi/dietpi/func/dietpi-set_hardware preferipv4 enable
	# - APT
	echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99-dietpi-force-ipv4
	# - Wget
	if grep -q '^[[:blank:]]*prefer-family[[:blank:]]*=' /etc/wgetrc; then

 		sed -i '/^[[:blank:]]*prefer-family[[:blank:]]*=/c\prefer-family = IPv4' /etc/wgetrc

 	elif grep -q '^[[:blank:]#;]*prefer-family[[:blank:]]*=' /etc/wgetrc; then

 		sed -i '/^[[:blank:]#;]*prefer-family[[:blank:]]*=/c\prefer-family = IPv4' /etc/wgetrc

 	else

 		echo 'prefer-family = IPv4' >> /etc/wgetrc

 	fi

	#Check/install minimal APT Pre-Reqs
	a_MIN_APT_PREREQS=(

		'apt-transport-https' # Allows HTTPS sources for APT
		'wget' # Download DietPi-Globals...
		'ca-certificates' # ...via HTTPS
		'unzip' # Unzip DietPi code
		'locales' # Allow ensuring en_GB.UTF-8
		'whiptail' # G_WHIP...
		'ncurses-bin' # ...using tput

	)

	#Removing conflicting /etc/apt/sources.list.d entries
	# - Meveric: https://github.com/Fourdee/DietPi/issues/1285#issuecomment-355759321
	[[ -f /etc/apt/sources.list.d/deb-multimedia.list ]] && rm /etc/apt/sources.list.d/deb-multimedia.list
	# - OMV: https://dietpi.com/phpbb/viewtopic.php?f=11&t=2772&p=10646#p10594
	[[ -f /etc/apt/sources.list.d/openmediavault.list ]] && rm /etc/apt/sources.list.d/openmediavault.list

	apt-get clean
	apt-get update
	for i in "${a_MIN_APT_PREREQS[@]}"
	do

		if ! dpkg-query -s $i &> /dev/null && ! apt-get install -y $i; then

			echo -e "[FAILED] Unable to install $i, please try to install it manually:\n\t # apt-get install -y $i\n"
			exit 1

		fi

	done

	unset a_MIN_APT_PREREQS

	#Setup locale
	# - Remove existing settings that could break dpkg-reconfigure locales
	> /etc/environment
	[[ -f /etc/default/locale ]] && rm /etc/default/locale

	# - NB: DEV, any changes here must be also rolled into function '/DietPi/dietpi/func/dietpi-set_software locale', for future script use
	echo 'en_GB.UTF-8 UTF-8' > /etc/locale.gen
	# - dpkg-reconfigure includes:
	#	- "locale-gen": Generate locale(s) based on "/etc/locale.gen" or interactive selection.
	#	- "update-locale": Add $LANG to "/etc/default/locale" based on generated locale(s) or interactive default language selection.
	if ! dpkg-reconfigure -f noninteractive locales; then

		echo -e '[FAILED] Locale generation failed. Aborting...\n'
		exit 1

	fi

	# - Update /etc/default/locales with new values (not effective until next load of bash session, eg: logout/in)
	update-locale LANG=en_GB.UTF-8
	update-locale LC_CTYPE=en_GB.UTF-8
	update-locale LC_TIME=en_GB.UTF-8
	update-locale LC_ALL=en_GB.UTF-8

	# - Export locale vars to assure the following whiptail being beautiful
	export LANG=en_GB.UTF8
	export LC_ALL=en_GB.UTF8

	#Select gitbranch
	aWHIP_BRANCH=(

		'master' ': Stable release (recommended)'
		'beta' ': Public beta testing branch'
		'dev' ': Unstable dev branch'

	)

	if WHIP_RETURN=$(whiptail --title "$G_PROGRAM_NAME" --menu 'Please select a Git branch:' --default-item 'master' --ok-button 'Ok' --cancel-button 'Exit' --backtitle "$G_PROGRAM_NAME" 12 80 3 "${aWHIP_BRANCH[@]}" 3>&1 1>&2 2>&3); then

		GITBRANCH=$WHIP_RETURN

	else

		echo -e '[ INFO ] No choice detected. Aborting...\n'
		exit 0

	fi

	unset aWHIP_BRANCH WHIP_RETURN

	echo "[ INFO ] Selected Git branch: $GITOWNER/$GITBRANCH"

	#------------------------------------------------------------------------------------------------
	# DietPi-Globals
	#------------------------------------------------------------------------------------------------
	# - Download
	# - NB: We'll have to manually handle errors, until DietPi-Globals are sucessfully loaded.
	if ! wget "https://raw.githubusercontent.com/$GITOWNER/DietPi/$GITBRANCH/dietpi/func/dietpi-globals" -O dietpi-globals; then

		echo -e '[FAILED] Unable to download dietpi-globals. Aborting...\n'
		exit 1

	fi

	# - Load
	if ! . ./dietpi-globals; then

		echo -e '[FAILED] Unable to load dietpi-globals. Aborting...\n'
		exit 1

	fi
	rm dietpi-globals

	# - Reset G_PROGRAM_NAME, which was set to empty string by sourcing dietpi-globals
	G_PROGRAM_NAME='DietPi-PREP'
	G_INIT

	DISTRO_TARGET=0
	DISTRO_TARGET_NAME=''
	if grep -q 'jessie' /etc/os-release; then

		G_DISTRO=3
		G_DISTRO_NAME='jessie'

	elif grep -q 'stretch' /etc/os-release; then

		G_DISTRO=4
		G_DISTRO_NAME='stretch'

	elif grep -q 'buster' /etc/os-release; then

		G_DISTRO=5
		G_DISTRO_NAME='buster'

	else

		G_DIETPI-NOTIFY 1 'Unknown or unsupported distribution version. Aborting...\n'
		exit 1

	fi

	G_HW_ARCH_DESCRIPTION=$(uname -m)
	if [[ $G_HW_ARCH_DESCRIPTION == 'armv6l' ]]; then

		G_HW_ARCH=1

	elif [[ $G_HW_ARCH_DESCRIPTION == 'armv7l' ]]; then

		G_HW_ARCH=2

	elif [[ $G_HW_ARCH_DESCRIPTION == 'aarch64' ]]; then

		G_HW_ARCH=3

	elif [[ $G_HW_ARCH_DESCRIPTION == 'x86_64' ]]; then

		G_HW_ARCH=10

	else

		G_DIETPI-NOTIFY 1 "Unknown or unsupported CPU architecture: \"$G_HW_ARCH_DESCRIPTION\". Aborting...\n"
		exit 1

	fi

	#WiFi install flag
	WIFI_REQUIRED=0

	#Image creator flags
	IMAGE_CREATOR=''
	PREIMAGE_INFO=''

	#Setup step, current (used in info)
	SETUP_STEP=0

	#URL connection test var holder
	INTERNET_ADDRESS=''

	Main(){

		#------------------------------------------------------------------------------------------------
		echo ''
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP: Detecting existing DietPi system:"
		((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------
		if [[ -d /DietPi/dietpi || -d /boot/dietpi ]]; then

			G_DIETPI-NOTIFY 2 'DietPi system found, running pre-prep'

			# - Stop services
			[[ -f /DietPi/dietpi/dietpi-services ]] && /DietPi/dietpi/dietpi-services stop
			[[ -f /etc/systemd/system/dietpi-ramdisk.service ]] && systemctl stop dietpi-ramdisk
			[[ -f /etc/systemd/system/dietpi-ramlog.service ]] && systemctl stop dietpi-ramlog

			# - Delete any previous existing data
			#	Failsafe
			umount /DietPi
			[[ -d /DietPi ]] && rm -R /DietPi
			[[ -d /boot/dietpi ]] && rm -R /boot/dietpi

			[[ -d /mnt/dietpi-backup ]] && rm -R /mnt/dietpi-backup
			[[ -d /mnt/dietpi-sync ]] && rm -R /mnt/dietpi-sync
			[[ -d /mnt/dietpi_userdata ]] && rm -R /mnt/dietpi_userdata

			[[ -d /etc/dietpi ]] && rm -R /etc/dietpi # Pre v160
			[[ -d /var/lib/dietpi ]] && rm -R /var/lib/dietpi
			[[ -d /var/tmp/dietpi ]] && rm -R /var/tmp/dietpi

			[[ -f /root/DietPi-Automation.log ]] && rm /root/DietPi-Automation.log
			[[ -f /boot/Automation_Format_My_Usb_Drive ]] && rm /boot/Automation_Format_My_Usb_Drive

		else

			G_DIETPI-NOTIFY 2 'Non-DietPi system found, skipping pre-prep'

		fi

		#------------------------------------------------------------------------------------------------
		echo ''
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP (inputs): Image info / Hardware / WiFi / Distro:"
		((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------

		#Image creator
		while :
		do

			G_WHIP_INPUTBOX 'Please enter your name. This will be used to identify the image creator within credits banner.\n\nYou can add your contact information as well for end users.\n\nNB: An entry is required.'
			if (( ! $? )) && [[ $G_WHIP_RETURNED_VALUE ]]; then

				#Disallowed:
				DISALLOWED_NAME=0
				aDISALLOWED_NAMES=(

					'official'
					'fourdee'
					'daniel knight'
					'dan knight'
					'michaing'
					'k-plan'
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
					G_DIETPI-NOTIFY 2 "Entered image creator: $IMAGE_CREATOR"
					break

				fi

			fi

		done

		#Pre-image used/name
		while :
		do

			G_WHIP_INPUTBOX 'Please enter the name or URL of the pre-image you installed on this system, prior to running this script. This will be used to identify the pre-image credits.\n\nEG: Debian, Raspbian Lite, Meveric, FriendlyARM, or "forum.odroid.com/viewtopic.php?f=ABC&t=XYZ" etc.\n\nNB: An entry is required.'
			if (( ! $? )) && [[ $G_WHIP_RETURNED_VALUE ]]; then

				PREIMAGE_INFO=$G_WHIP_RETURNED_VALUE
				G_DIETPI-NOTIFY 2 "Entered pre-image info: $PREIMAGE_INFO"
				break

			fi

		done

		#Hardware selection
		#	NB: PLEASE ENSURE HW_MODEL INDEX ENTRIES MATCH : PREP, dietpi-obtain_hw_model, dietpi-survey_results,
		#	NBB: DO NOT REORDER INDEX's. These are now fixed and will never change (due to survey results etc)
		G_WHIP_DEFAULT_ITEM=22
		G_WHIP_BUTTON_CANCEL_TEXT='Exit'
		G_WHIP_MENU_ARRAY=(

			'' '●─ Other '
			'22' ': Generic device (unknown to DietPi)'
			'' '●─ SBC─(Core devices, with GPU support) '
			'52' ': ASUS Tinker Board'
			'10' ': Odroid C1'
			'12' ': Odroid C2'
			'11' ': Odroid XU3/XU4/HC1/HC2'
			'44' ': Pinebook 1080p'
			'0' ': Raspberry Pi (All models)'
			# '1' ': Raspberry Pi 1/Zero (512mb)'
			# '2' ': Raspberry Pi 2'
			# '3' ': Raspberry Pi 3/3+'
			'' '●─ PC '
			'21' ': x86_64 Native PC'
			'20' ': x86_64 VMware/VirtualBox'
			'' '●─ SBC─(Limited support devices, no GPU support) '
			'53' ': BananaPi (sinovoip)'
			'51' ': BananaPi Pro (Lemaker)'
			'50' ': BananaPi M2+ (sinovoip)'
			'71' ': Beagle Bone Black'
			'69' ': Firefly RK3399'
			'39' ': LeMaker Guitar'
			'60' ': NanoPi NEO'
			'65' ': NanoPi NEO 2'
			'64' ': NanoPi NEO Air'
			'63' ': NanoPi M1/T1'
			'66' ': NanoPi M1 Plus'
			'61' ': NanoPi M2/T2'
			'62' ': NanoPi M3/T3/F3'
			'68' ': NanoPC T4'
			'67' ': NanoPi K1 Plus'
			'14' ': Odroid N1'
			'13' ': Odroid U3'
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
			'40' ': Pine A64'
			'43' ': Rock64'
			'42' ': RockPro64'
			'70' ': Sparky SBC'

		)

		G_WHIP_MENU 'Please select the current device this is being installed on:\n - NB: Select "Generic device" if not listed.\n - "Core devices": Are fully supported by DietPi, offering full GPU + Kodi support.\n - "Limited support devices": No GPU support, supported limited to DietPi specific issues only (eg: excludes Kernel/GPU/VPU related items).'
		if (( $? )) || [[ -z $G_WHIP_RETURNED_VALUE ]]; then

			G_DIETPI-NOTIFY 1 'No choice detected. Aborting...\n'
			exit 0

		fi

		# + Set for future scripts
		G_HW_MODEL=$G_WHIP_RETURNED_VALUE
		echo $G_HW_MODEL > /etc/.dietpi_hw_model_identifier

		G_DIETPI-NOTIFY 2 "Selected hardware model ID: $G_HW_MODEL"
		G_DIETPI-NOTIFY 2 "Detected CPU architecture: $G_HW_ARCH_DESCRIPTION (ID: $G_HW_ARCH)"

		G_WHIP_MENU_ARRAY=(

			'0' ': I do not require WiFi functionality, skip related package install.'
			'1' ': I require WiFi functionality, install related packages.'

		)

		G_WHIP_DEFAULT_ITEM=1
		(( $G_HW_MODEL == 20 )) && G_WHIP_DEFAULT_ITEM=0

		if G_WHIP_MENU 'Please select an option:' && (( $G_WHIP_RETURNED_VALUE )); then

			G_DIETPI-NOTIFY 2 'Marking WiFi as required'
			WIFI_REQUIRED=1

		else

			G_DIETPI-NOTIFY 2 'Marking WiFi as NOT required'

		fi

		#Distro Selection
		DISTRO_LIST_ARRAY=(

			'4' ': Stretch (current stable release, recommended)'
			'5' ': Buster (testing only, not officially supported)'

		)

		# - Enable/list available options based on criteria
		#	NB: Whiptail use 2 array indexs per whip displayed entry.
		G_WHIP_MENU_ARRAY=()
		for ((i=0; i<${#DISTRO_LIST_ARRAY[@]}; i+=2))
		do

			# - Disable downgrades
			if (( ${DISTRO_LIST_ARRAY[$i]} < $G_DISTRO )); then

				G_DIETPI-NOTIFY 2 "Disabled distro downgrade to: ${DISTRO_LIST_ARRAY[$i+1]}"

			# - Enable option
			else

				G_WHIP_MENU_ARRAY+=( "${DISTRO_LIST_ARRAY[$i]}" "${DISTRO_LIST_ARRAY[$i+1]}" )

			fi

		done

		unset DISTRO_LIST_ARRAY

		if [[ -z ${G_WHIP_MENU_ARRAY+x} ]]; then

			G_DIETPI-NOTIFY 1 'No available distro versions for this system. Aborting...\n'
			exit 1

		fi

		G_WHIP_DEFAULT_ITEM=${G_WHIP_MENU_ARRAY[0]} # Downgrades disabled, so first item matches current/lowest supported distro version
		G_WHIP_BUTTON_CANCEL_TEXT='Exit'
		G_WHIP_MENU "Please select a distro version to install on this system. Selecting a distro that is older than the current installed on system, is not supported.\n\nCurrently installed:\n - $G_DISTRO $G_DISTRO_NAME"
		if (( $? )) || [[ -z $G_WHIP_RETURNED_VALUE ]]; then

			G_DIETPI-NOTIFY 1 'No choice detected. Aborting...\n'
			exit 0

		fi

		DISTRO_TARGET=$G_WHIP_RETURNED_VALUE
		if (( $DISTRO_TARGET == 4 )); then

			DISTRO_TARGET_NAME='stretch'

		elif (( $DISTRO_TARGET == 5 )); then

			DISTRO_TARGET_NAME='buster'

		else

			G_DIETPI-NOTIFY 1 'Invalid choice detected. Aborting...\n'
			exit 1

		fi

		G_DIETPI-NOTIFY 2 "Selected Debian version: $DISTRO_TARGET_NAME (ID: $DISTRO_TARGET)"

		#------------------------------------------------------------------------------------------------
		echo ''
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP: Downloading and installing DietPi sourcecode:"
		((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------

		INTERNET_ADDRESS="https://github.com/$GITOWNER/DietPi/archive/$GITBRANCH.zip"
		G_CHECK_URL "$INTERNET_ADDRESS"
		G_RUN_CMD wget "$INTERNET_ADDRESS" -O package.zip

		[[ -d DietPi-$GITBRANCH ]] && l_message='Cleaning previously extracted files' G_RUN_CMD rm -R "DietPi-$GITBRANCH"
		l_message='Extracting DietPi sourcecode' G_RUN_CMD unzip package.zip
		rm package.zip

		[[ -d /boot ]] || l_message='Creating /boot' G_RUN_CMD mkdir -p /boot

		G_DIETPI-NOTIFY 2 'Moving kernel and boot configuration to /boot'

		# - HW specific config.txt, boot.ini uEnv.txt
		if (( $G_HW_MODEL < 10 )); then

			G_RUN_CMD mv "DietPi-$GITBRANCH/config.txt" /boot/

		elif (( $G_HW_MODEL == 10 )); then

			G_RUN_CMD mv "DietPi-$GITBRANCH/boot_c1.ini" /boot/boot.ini

		elif (( $G_HW_MODEL == 11 )); then

			G_RUN_CMD mv "DietPi-$GITBRANCH/boot_xu4.ini" /boot/boot.ini

		elif (( $G_HW_MODEL == 12 )); then

			G_RUN_CMD mv "DietPi-$GITBRANCH/boot_c2.ini" /boot/boot.ini

		fi

		G_RUN_CMD mv "DietPi-$GITBRANCH/dietpi.txt" /boot/
		G_RUN_CMD mv "DietPi-$GITBRANCH/README.md" /boot/dietpi-README.md
		G_RUN_CMD mv "DietPi-$GITBRANCH/CHANGELOG.txt" /boot/dietpi-CHANGELOG.txt

		# - Remove server_version* / (pre-)patch_file (downloads fresh from dietpi-update)
		rm "DietPi-$GITBRANCH/dietpi/server_version"*
		rm "DietPi-$GITBRANCH/dietpi/pre-patch_file"
		rm "DietPi-$GITBRANCH/dietpi/patch_file"

		l_message='Copy DietPi core files to /boot/dietpi' G_RUN_CMD cp -Rf "DietPi-$GITBRANCH/dietpi" /boot/
		l_message='Copy DietPi rootfs files in place' G_RUN_CMD cp -Rf "DietPi-$GITBRANCH/rootfs"/. /
		l_message='Clean download location' G_RUN_CMD rm -R "DietPi-$GITBRANCH"
		l_message='Pre-create directories' G_RUN_CMD mkdir -p /DietPi
		l_message='Set execute permissions for DietPi scripts' G_RUN_CMD chmod -R +x /boot/dietpi /var/lib/dietpi/services /etc/cron.*/dietpi

		G_RUN_CMD systemctl daemon-reload
		G_RUN_CMD systemctl enable dietpi-ramdisk

		# - Mount tmpfs
		G_RUN_CMD mount -t tmpfs -o size=10m tmpfs /DietPi
		l_message='Starting DietPi-RAMdisk' G_RUN_CMD systemctl start dietpi-ramdisk

		#------------------------------------------------------------------------------------------------
		echo ''
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP: APT configuration:"
		((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------

		G_DIETPI-NOTIFY 2 "Setting APT sources.list: $DISTRO_TARGET_NAME $DISTRO_TARGET"

		# - We need to forward $DISTRO_TARGET* to dietpi-set_software, as well as $G_HW_MODEL for Debian vs Raspbian decision.
		G_DISTRO=$DISTRO_TARGET G_DISTRO_NAME=$DISTRO_TARGET_NAME G_HW_MODEL=$G_HW_MODEL G_RUN_CMD /DietPi/dietpi/func/dietpi-set_software apt-mirror 'default'

		# - Meveric, update repo to use our EU mirror: https://github.com/Fourdee/DietPi/issues/1519#issuecomment-368234302
		sed -i 's@https://oph.mdrjr.net/meveric@http://fuzon.co.uk/meveric@' /etc/apt/sources.list.d/meveric* &> /dev/null

		# - (Re)create DietPi logs dir, used by G_AGx
		G_RUN_CMD mkdir -p /var/tmp/dietpi/logs

		G_AGUP

		# - @MichaIng https://github.com/Fourdee/DietPi/pull/1266/files
		G_DIETPI-NOTIFY 2 'Marking all packages as auto-installed first, to allow effective autoremove afterwards'

		G_RUN_CMD apt-mark auto $(apt-mark showmanual)

		# - @MichaIng https://github.com/Fourdee/DietPi/pull/1266/files
		G_DIETPI-NOTIFY 2 'Disable automatic recommends/suggests install and allow them to be autoremoved:'

		#	Remove any existing APT recommends settings
		rm -f /etc/apt/apt.conf.d/*recommends*

		G_ERROR_HANDLER_COMMAND='/etc/apt/apt.conf.d/99-dietpi-norecommends'
		cat << _EOF_ > $G_ERROR_HANDLER_COMMAND
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APT::AutoRemove::RecommendsImportant "false";
APT::AutoRemove::SuggestsImportant "false";
_EOF_
		G_ERROR_HANDLER_EXITCODE=$?
		G_ERROR_HANDLER

		G_DIETPI-NOTIFY 2 'Preserve modified config files on APT update:'

		G_ERROR_HANDLER_COMMAND='/etc/apt/apt.conf.d/99-dietpi-forceconf'
		cat << _EOF_ > $G_ERROR_HANDLER_COMMAND
Dpkg::options {
   "--force-confdef";
   "--force-confold";
}
_EOF_
		G_ERROR_HANDLER_EXITCODE=$?
		G_ERROR_HANDLER

		# - DietPi list of minimal required packages, which must be installed:
		aPACKAGES_REQUIRED_INSTALL=(

			'apt-transport-https'	# Allows HTTPS sources for ATP
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
			'ethtool'		# Ethernet link checking
			'fake-hwclock'		# Hardware clock emulation, to allow correct timestamps during boot before network time sync
			'gnupg'			# apt-key add
			'htop'			# System monitor
			'iputils-ping'		# "ping" command
			'isc-dhcp-client'	# DHCP client
			'kmod'			# "modprobe", "lsmod", used by several DietPi scripts
			'locales'		# Support locales, necessary for DietPi scripts, as we use en_GB.UTF8 as default language
			'nano'			# Simple text editor
			'p7zip-full'		# .7z wrapper
			'parted'		# Drive partitioning, required by DietPi-Boot + DietPi-Drive_Manager
			'procps'		# "kill", "ps", "pgrep", "sysctl", used by several DietPi scripts
			'psmisc'		# "killall", used by several DietPi scripts
			'resolvconf'		# Network nameserver handler + depandant for "ifupdown" (network interface handler) => "iproute2" ("ip" command)
			'sudo'			# Root permission wrapper for users within /etc/sudoers(.d/)
			'systemd-sysv'		# Includes systemd and additional commands: "poweroff", "shutdown" etc.
			'tzdata'		# Time zone data for system clock, auto summer/winter time adjustment
			'udev'			# /dev/ and hotplug management daemon
			'unzip'			# .zip unpacker
			'usbutils'		# "lsusb", used by DietPi-Software + DietPi-Bugreport
			'wget'			# Download tool
			'whiptail'		# DietPi dialogs

		)

		# - G_HW_MODEL specific required repo key packages: https://github.com/Fourdee/DietPi/issues/1285#issuecomment-358301273
		if (( $G_HW_MODEL >= 10 )); then

			G_AGI debian-archive-keyring
			aPACKAGES_REQUIRED_INSTALL+=('initramfs-tools')		# RAM file system initialization, required for generic boot loader, but not required/used by RPi bootloader

		else

			G_AGI raspbian-archive-keyring

		fi

		# - WiFi related packages
		if (( $WIFI_REQUIRED )); then

			aPACKAGES_REQUIRED_INSTALL+=('crda')			# WiFi related
			aPACKAGES_REQUIRED_INSTALL+=('iw')			# WiFi related
			aPACKAGES_REQUIRED_INSTALL+=('rfkill')	 		# WiFi related: Used by some onboard WiFi chipsets
			aPACKAGES_REQUIRED_INSTALL+=('wireless-tools')		# WiFi related
			aPACKAGES_REQUIRED_INSTALL+=('wpasupplicant')		# WiFi WPA(2) support

		fi

		# - G_DISTRO specific required packages:
		if (( $G_DISTRO < 4 )); then

			aPACKAGES_REQUIRED_INSTALL+=('dropbear')		# DietPi default SSH-Client

		else

			aPACKAGES_REQUIRED_INSTALL+=('dropbear-run')		# DietPi default SSH-Client (excluding initramfs integration, available since Stretch)

		fi

		# - G_HW_MODEL specific required packages:
		if (( $G_HW_MODEL != 20 )); then

			aPACKAGES_REQUIRED_INSTALL+=('dosfstools')		# DietPi-Drive_Manager + fat (boot) drive file system check and creation tools
			aPACKAGES_REQUIRED_INSTALL+=('hdparm')			# Drive power management adjustments

		fi

		# - Kernel required packages
		# - G_HW_ARCH specific required Kernel packages
		#	As these are kernel, or bootloader packages, we need to install them directly to allow autoremove of in case older kernel packages:
		#	https://github.com/Fourdee/DietPi/issues/1285#issuecomment-354602594
		#	x86_64
		if (( $G_HW_ARCH == 10 )); then

			G_AGI linux-image-amd64 os-prober

			#	Grub EFI
			if dpkg-query -s 'grub-efi-amd64' &> /dev/null ||
				[[ -d '/boot/efi' ]]; then

				G_AGI grub-efi-amd64

			#	Grub BIOS
			else

				G_AGI grub-pc

			fi

		# - G_HW_MODEL specific required Kernel packages
		#	ARMbian grab currently installed packages
		elif dpkg --get-selections | grep -qi armbian; then

			systemctl stop armbian-*

			local apackages=(

				"armbian-tools-$DISTRO_TARGET_NAME"
				"linux-dtb-"
				"linux-u-"
				"linux-image-"
				"linux-$DISTRO_TARGET_NAME"
				'sunxi'

			)

			for i in "${apackages[@]}"
			do

				while read -r line
				do

					if [[ $line ]]; then

						aPACKAGES_REQUIRED_INSTALL+=("$line")
						apt-mark hold $line
						G_DIETPI-NOTIFY 2 "PKG detected and set on hold: $line"

					fi

				done <<< "$(dpkg --get-selections | mawk -v pat="^$i" '$0~pat {print $1}')"

			done

			unset apackages

		#	RPi
		elif (( $G_HW_MODEL < 10 )); then

			apt-mark unhold libraspberrypi-bin libraspberrypi0 raspberrypi-bootloader raspberrypi-kernel raspberrypi-sys-mods raspi-copies-and-fills
			rm -Rf /lib/modules/*
			G_AGI libraspberrypi-bin libraspberrypi0 raspberrypi-bootloader raspberrypi-kernel raspberrypi-sys-mods
			G_AGI --reinstall libraspberrypi-bin libraspberrypi0 raspberrypi-bootloader raspberrypi-kernel
			# Buster systemd-udevd doesn't support the current raspi-copies-and-fills: https://github.com/Fourdee/DietPi/issues/1286
			(( $DISTRO_TARGET < 5 )) && G_AGI raspi-copies-and-fills

		#	Odroid N1
		elif (( $G_HW_MODEL == 14 )); then

			G_AGI linux-image-arm64-odroid-n1
			#G_AGI libdrm-rockchip1 #Not currently on meveric's repo

		#	Odroid C2
		elif (( $G_HW_MODEL == 12 )); then

			G_AGI linux-image-arm64-odroid-c2

		#	Odroid XU3/4/HC1/HC2
		elif (( $G_HW_MODEL == 11 )); then

			#G_AGI linux-image-4.9-armhf-odroid-xu3
			G_AGI $(dpkg --get-selections | mawk '/^linux-image/ {print $1}')
			dpkg --get-selections | grep -q '^linux-image' || G_AGI linux-image-4.14-armhf-odroid-xu4

		#	Odroid C1
		elif (( $G_HW_MODEL == 10 )); then

			G_AGI linux-image-armhf-odroid-c1

		#	BBB
		elif (( $G_HW_MODEL == 71 )); then

			G_AGI device-tree-compiler #Kern

		# - Auto detect kernel package incl. ARMbian/others DTB
		else

			AUTO_DETECT_KERN_PKG=$(dpkg --get-selections | grep -E '^linux-(image|dtb)' | awk '{print $1}')
			if [[ $AUTO_DETECT_KERN_PKG ]]; then

				G_AGI $AUTO_DETECT_KERN_PKG

			else

				G_DIETPI-NOTIFY 2 'Unable to find kernel packages for installation. Assuming non-APT/.deb kernel installation.'

			fi

		fi

		# - Firmware
		if dpkg --get-selections | grep -q '^armbian-firmware'; then

			aPACKAGES_REQUIRED_INSTALL+=('armbian-firmware')

		else

			#	Usually no firmware should be necessary for VMs. If user manually passes though some USB device, user might need to install the firmware then.
			if (( $G_HW_MODEL != 20 )); then

				aPACKAGES_REQUIRED_INSTALL+=('firmware-realtek')	# Eth/WiFi/BT dongle firmware
				aPACKAGES_REQUIRED_INSTALL+=('firmware-linux-nonfree')

			fi

			if (( $WIFI_REQUIRED )); then

				aPACKAGES_REQUIRED_INSTALL+=('firmware-atheros')	# WiFi dongle firmware
				aPACKAGES_REQUIRED_INSTALL+=('firmware-brcm80211')	# WiFi dongle firmware
				aPACKAGES_REQUIRED_INSTALL+=('firmware-iwlwifi')	# Intel WiFi dongle/PCI-e firwmare

				# Intel/Nvidia/WiFi (ralink) dongle firmware: https://github.com/Fourdee/DietPi/issues/1675#issuecomment-377806609
				# On Jessie, firmware-misc-nonfree is not available, firmware-ralink instead as dedicated package.
				if (( $G_DISTRO < 4 )); then

					aPACKAGES_REQUIRED_INSTALL+=('firmware-ralink')

				else

					aPACKAGES_REQUIRED_INSTALL+=('firmware-misc-nonfree')

				fi

			fi

		fi

		G_DIETPI-NOTIFY 2 'Generating list of minimal packages, required for DietPi installation'

		l_message='Marking required packages as manually installed' G_RUN_CMD apt-mark manual ${aPACKAGES_REQUIRED_INSTALL[@]}

		# Purging additional packages, that (in some cases) do not get autoremoved:
		# - dhcpcd5: https://github.com/Fourdee/DietPi/issues/1560#issuecomment-370136642
		# - dbus: Not required for headless images, but sometimes marked as "important", thus not autoremoved.
		G_AGP dbus dhcpcd5
		G_AGA

		#------------------------------------------------------------------------------------------------
		echo ''
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP: APT installations:"
		((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------

		G_AGDUG

		# - Distro is now target (for APT purposes and G_AGX support due to installed binary, its here, instead of after G_AGUP)
		G_DISTRO=$DISTRO_TARGET
		G_DISTRO_NAME=$DISTRO_TARGET_NAME

		G_DIETPI-NOTIFY 2 'Installing core DietPi pre-req APT packages'

		G_AGI ${aPACKAGES_REQUIRED_INSTALL[@]}

		unset aPACKAGES_REQUIRED_INSTALL

		G_AGA

		# Reenable HTTPS for deb.debian.org, since system was dist-upgraded to Stretch+
		(( $G_HW_MODEL > 9 )) && sed -i 's/http:/https:/g' /etc/apt/sources.list

		#------------------------------------------------------------------------------------------------
		echo ''
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP: Prep system for DietPi ENV:"
		((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------

		G_DIETPI-NOTIFY 2 'Deleting list of known users, not required by DietPi'

		getent passwd pi &> /dev/null && userdel -f pi
		getent passwd test &> /dev/null && userdel -f test #@fourdee
		getent passwd odroid &> /dev/null && userdel -f odroid
		getent passwd rock64 &> /dev/null && userdel -f rock64
		getent passwd linaro &> /dev/null && userdel -f linaro #ASUS TB
		getent passwd dietpi &> /dev/null && userdel -f dietpi #recreated below
		getent passwd debian &> /dev/null && userdel -f debian #BBB

		G_DIETPI-NOTIFY 2 'Removing misc files/folders/services, not required by DietPi'

		[[ -d /home ]] && rm -R /home
		[[ -d /media ]] && rm -R /media
		[[ -d /selinux ]] && rm -R /selinux

		# - www
		[[ -d /var/www ]] && rm -Rf /var/www/{,.??,.[^.]}*

		# - sourcecode (linux-headers etc)
		[[ -d /usr/src ]] && rm -Rf /usr/src/{,.??,.[^.]}*

		# - root
		[[ -e /root/.cache ]] && rm -R /root/.cache
		[[ -e /root/.local ]] && rm -R /root/.local
		[[ -e /root/.config ]] && rm -R /root/.config

		# - documentation folders
		[[ -d /usr/share/man ]] && rm -R /usr/share/man
		[[ -d /usr/share/doc ]] && rm -R /usr/share/doc
		[[ -d /usr/share/doc-base ]] && rm -R /usr/share/doc-base
		[[ -d /usr/share/calendar ]] && rm -R /usr/share/calendar

		# - Previous debconfs
		rm -f /var/cache/debconf/*-old

		# - Fonts
		[[ -d /usr/share/fonts ]] && rm -R /usr/share/fonts
		[[ -d /usr/share/icons ]] && rm -R /usr/share/icons

		# - Stop, disable and remove not required services
		local aservices=(

			# - ARMbian
			firstrun
			resize2fs
			log2ram
			armbian*
			# - Meveric
			cpu_governor

		)

		for i in ${aservices[@]}
		do

			# Loop through known service locations
			for j in /etc/init.d/$i /etc/systemd/system/$i.service /etc/systemd/system/$i.service.d /lib/systemd/system/$i.service /lib/systemd/system/$i.service.d
			do

				if [[ -e $j ]]; then

					if [[ -f $j ]]; then

						systemctl stop ${j##*/}
						systemctl disable ${j##*/}

					fi

					rm -R $j

				fi

			done

		done

		systemctl daemon-reload

		# - ARMbian
		[[ -f /usr/local/sbin/log2ram ]] && rm /usr/local/sbin/log2ram
		[[ -f /usr/bin/armbianmonitor ]] && rm /usr/bin/armbianmonitor
		[[ -d /usr/lib/armbian ]] && rm -R /usr/lib/armbian
		[[ -d /usr/share/armbian ]] && rm -R /usr/share/armbian
		rm -f /etc/profile.d/armbian*
		#rm -Rf /etc/armbian* armbian-release required for kernel package update success.
		rm -Rf /etc/default/armbian*
		rm -Rf /etc/update-motd.d/*armbian*
		rm -Rf /etc/X11/xorg.conf.d/*armbian*
		rm -f /etc/cron.*/armbian*
		[[ -f /boot/armbian_first_run.txt.template ]] && rm /boot/armbian_first_run.txt.template
		umount /var/log.hdd 2> /dev/null
		[[ -d /var/log.hdd ]] && rm -R /var/log.hdd

		# - Meveric specific
		[[ -f /usr/local/sbin/setup-odroid ]] && rm /usr/local/sbin/setup-odroid

		# - RPi specific https://github.com/Fourdee/DietPi/issues/1631#issuecomment-373965406
		[[ -f /etc/profile.d/wifi-country.sh ]] && rm /etc/profile.d/wifi-country.sh

		# - make_nas_processes_faster cron job on Rock64 + NanoPi + Pine64(?) images
		[[ -f /etc/cron.d/make_nas_processes_faster ]] && rm /etc/cron.d/make_nas_processes_faster

		#-----------------------------------------------------------------------------------
		#Boot Logo
		[[ -f /boot/boot.bmp ]] && G_RUN_CMD wget https://github.com/$GITOWNER/DietPi/raw/$GITBRANCH/.meta/images/dietpi-logo_boot.bmp -O /boot/boot.bmp

		#-----------------------------------------------------------------------------------
		#Bash Profiles

		# - Pre v6.9 cleaning:
		sed -i '/\/DietPi/d' /root/.bashrc
		sed -i '/\/DietPi/d' /home/dietpi/.bashrc &> /dev/null
		rm -f /etc/profile.d/99-dietpi*

		# - Enable /etc/bashrc.d/ support for custom interactive non-login shell scripts:
		G_CONFIG_INJECT '.*/etc/bashrc\.d/.*' 'for i in /etc/bashrc.d/*.sh; do [ -r "$i" ] && . $i; done' /etc/bash.bashrc

		# - Enable bash-completion for non-login shells:
		#	- NB: It is called twice on login shells then, but breaks directly if called already once.
		ln -sf /etc/profile.d/bash_completion.sh /etc/bashrc.d/dietpi-bash_completion.sh

		#-----------------------------------------------------------------------------------
		#Create_DietPi_User

		l_message='Creating DietPi User Account' G_RUN_CMD /DietPi/dietpi/func/dietpi-set_software useradd dietpi

		#-----------------------------------------------------------------------------------
		#UID bit for sudo: https://github.com/Fourdee/DietPi/issues/794

		G_DIETPI-NOTIFY 2 'Configuring Sudo UID bit'

		chmod 4755 $(which sudo)

		#-----------------------------------------------------------------------------------
		#Dir's

		G_DIETPI-NOTIFY 2 'Configuring DietPi Directories'

		# - /var/lib/dietpi : Core storage for installed non-standard APT software, outside of /mnt/dietpi_userdata
		#mkdir -p /var/lib/dietpi
		mkdir -p /var/lib/dietpi/postboot.d
		#	Storage locations for program specifc additional data
		mkdir -p /var/lib/dietpi/dietpi-autostart
		mkdir -p /var/lib/dietpi/dietpi-config
		#mkdir -p /var/lib/dietpi/dietpi-software
		mkdir -p /var/lib/dietpi/dietpi-software/installed #Additional storage for installed apps, eg: custom scripts and data
		chown dietpi:dietpi /var/lib/dietpi
		chmod 660 /var/lib/dietpi

		# - /var/tmp/dietpi : Temp storage saved during reboots, eg: logs outside of /var/log
		#mkdir -p /var/tmp/dietpi/logs
		mkdir -p /var/tmp/dietpi/logs/dietpi-ramlog_store
		chown dietpi:dietpi /var/tmp/dietpi
		chmod 660 /var/tmp/dietpi

		# - /DietPi RAMdisk
		mkdir -p /DietPi
		chown dietpi:dietpi /DietPi
		chmod 660 /DietPi

		# - /mnt/dietpi_userdata : DietPi userdata
		mkdir -p $G_FP_DIETPI_USERDATA
		chown dietpi:dietpi $G_FP_DIETPI_USERDATA
		chmod -R 775 $G_FP_DIETPI_USERDATA

		# - Networked drives
		mkdir -p /mnt/samba
		mkdir -p /mnt/ftp_client
		mkdir -p /mnt/nfs_client

		#-----------------------------------------------------------------------------------
		#Services

		G_DIETPI-NOTIFY 2 'Configuring DietPi Services:'

		G_RUN_CMD systemctl enable dietpi-ramlog
		G_RUN_CMD systemctl enable dietpi-boot
		G_RUN_CMD systemctl enable dietpi-preboot
		G_RUN_CMD systemctl enable dietpi-postboot
		G_RUN_CMD systemctl enable dietpi-kill_ssh

		#-----------------------------------------------------------------------------------
		#Cron Jobs

		G_DIETPI-NOTIFY 2 'Configuring Cron:'

		G_ERROR_HANDLER_COMMAND='/etc/crontab'
		cat << _EOF_ > $G_ERROR_HANDLER_COMMAND
# Please use dietpi-cron to change cron start times
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# m h dom mon dow user command
#*/0 * * * * root cd / && run-parts --report /etc/cron.minutely
17 * * * * root cd / && run-parts --report /etc/cron.hourly
25 1 * * * root test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.daily; }
47 1 * * 7 root test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.weekly; }
52 1 1 * * root test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.monthly; }
_EOF_
		G_ERROR_HANDLER_EXITCODE=$?
		G_ERROR_HANDLER

		#-----------------------------------------------------------------------------------
		#Network

		G_DIETPI-NOTIFY 2 'Configuring wlan/eth naming to be preferred for networked devices:'
		ln -sfv /dev/null /etc/systemd/network/99-default.link

		G_DIETPI-NOTIFY 2 'Adding dietpi.com SSH pub host key for DietPi-Survey/Bugreport uploads:'
		mkdir -p /root/.ssh
		>> /root/.ssh/known_hosts
		G_CONFIG_INJECT 'ssh.dietpi.com ' 'ssh.dietpi.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDE6aw3r6aOEqendNu376iiCHr9tGBIWPgfrLkzjXjEsHGyVSUFNnZt6pftrDeK7UX+qX4FxOwQlugG4fymOHbimRCFiv6cf7VpYg1Ednquq9TLb7/cIIbX8a6AuRmX4fjdGuqwmBq3OG7ZksFcYEFKt5U4mAJIaL8hXiM2iXjgY02LqiQY/QWATsHI4ie9ZOnwrQE+Rr6mASN1BVFuIgyHIbwX54jsFSnZ/7CdBMkuAd9B8JkxppWVYpYIFHE9oWNfjh/epdK8yv9Oo6r0w5Rb+4qaAc5g+RAaknHeV6Gp75d2lxBdCm5XknKKbGma2+/DfoE8WZTSgzXrYcRlStYN' /root/.ssh/known_hosts

		G_DIETPI-NOTIFY 2 'Recreating symlink for resolv.conf (DNS):'
		echo 'nameserver 8.8.8.8' > /etc/resolvconf/run/resolv.conf # Temp apply, in case was not previously symlink, resets on next ifup.
		ln -sfv /etc/resolvconf/run/resolv.conf /etc/resolv.conf

		#-----------------------------------------------------------------------------------
		#MISC

		G_DIETPI-NOTIFY 2 'Disabling apt-daily services to prevent random APT cache lock'

		for i in apt-daily.service apt-daily.timer apt-daily-upgrade.service apt-daily-upgrade.timer
		do

			systemctl stop $i &> /dev/null
			systemctl disable $i &> /dev/null
			systemctl mask $i &> /dev/null

		done

		local info_use_drive_manager='can be installed and setup by DietPi-Drive_Manager.\nSimply run: dietpi-drive_manager and select Add Network Drive'
		echo -e "Samba client: $info_use_drive_manager" > /mnt/samba/readme.txt
		echo -e "NFS client: $info_use_drive_manager" > /mnt/nfs_client/readme.txt

		l_message='Generating DietPi /etc/fstab' G_RUN_CMD /DietPi/dietpi/dietpi-drive_manager 4
		# Restart DietPi-RAMdisk, as 'dietpi-drive_manager 4' remounts /DietPi.
		G_RUN_CMD systemctl restart dietpi-ramdisk

		# Recreate and navigate to "/tmp/$G_PROGRAM_NAME" working directory
		mkdir -p /tmp/$G_PROGRAM_NAME
		cd /tmp/$G_PROGRAM_NAME

		G_DIETPI-NOTIFY 2 'Deleting all log files /var/log'

		/DietPi/dietpi/func/dietpi-logclear 2 &> /dev/null # As this will report missing vars, however, its fine, does not break functionality.

		l_message='Starting DietPi-RAMlog service' G_RUN_CMD systemctl start dietpi-ramlog

		G_DIETPI-NOTIFY 2 'Updating DietPi HW_INFO'

		/DietPi/dietpi/func/dietpi-obtain_hw_model

		G_DIETPI-NOTIFY 2 'Configuring network interfaces:'

		[[ -f /etc/network/interfaces ]] && rm -R /etc/network/interfaces # ARMbian symlink for bulky network-manager

		G_ERROR_HANDLER_COMMAND='/etc/network/interfaces'
		cat << _EOF_ > $G_ERROR_HANDLER_COMMAND
#/etc/network/interfaces
#Please use DietPi-Config to modify network settings.

# Local
auto lo
iface lo inet loopback

# Ethernet
#allow-hotplug eth0
iface eth0 inet dhcp
address 192.168.0.100
netmask 255.255.255.0
gateway 192.168.0.1
#dns-nameservers 8.8.8.8 8.8.4.4

# Wifi
#allow-hotplug wlan0
iface wlan0 inet dhcp
address 192.168.0.100
netmask 255.255.255.0
gateway 192.168.0.1
wireless-power off
wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
#dns-nameservers 8.8.8.8 8.8.4.4
_EOF_
		G_ERROR_HANDLER_EXITCODE=$?
		G_ERROR_HANDLER

		# - Remove all predefined eth*/wlan* adapter rules
		rm -f /etc/udev/rules.d/70-persist*nt-net.rules

		#	Add pre-up lines for wifi on OrangePi Zero
		if (( $G_HW_MODEL == 32 )); then

			sed -i '/iface wlan0 inet dhcp/apre-up modprobe xradio_wlan\npre-up iwconfig wlan0 power on' /etc/network/interfaces

		#	ASUS TB WiFi: https://github.com/Fourdee/DietPi/issues/1760
		elif (( $G_HW_MODEL == 52 )); then

			G_CONFIG_INJECT '8723bs' '8723bs' /etc/modules

		fi

		#	Fix rare WiFi interface start issue: https://github.com/Fourdee/DietPi/issues/2074
		[[ -f /etc/network/if-pre-up.d/wireless-tools ]] && sed -i '\|^[[:blank:]]ifconfig "$IFACE" up$|c\\t/sbin/ip link set dev "$IFACE" up' /etc/network/if-pre-up.d/wireless-tools

		G_DIETPI-NOTIFY 2 'Tweaking DHCP timeout:'

		# - Reduce DHCP request retry count and timeouts: https://github.com/Fourdee/DietPi/issues/711
		G_CONFIG_INJECT 'timeout[[:blank:]]' 'timeout 10;' /etc/dhcp/dhclient.conf
		G_CONFIG_INJECT 'retry[[:blank:]]' 'retry 4;' /etc/dhcp/dhclient.conf

		G_DIETPI-NOTIFY 2 'Configuring hosts:'

		G_ERROR_HANDLER_COMMAND='/etc/hosts'
		cat << _EOF_ > $G_ERROR_HANDLER_COMMAND
127.0.0.1    localhost
127.0.1.1    DietPi
::1          localhost ip6-localhost ip6-loopback
ff02::1      ip6-allnodes
ff02::2      ip6-allrouters
_EOF_
		G_ERROR_HANDLER_EXITCODE=$?
		G_ERROR_HANDLER

		echo 'DietPi' > /etc/hostname

		G_DIETPI-NOTIFY 2 'Configuring htop:'

		G_ERROR_HANDLER_COMMAND='/etc/htoprc'
		cat << _EOF_ > $G_ERROR_HANDLER_COMMAND
# DietPi default config for htop
# Location: /etc/htoprc
#
# NB: htop will create "~/.config/htop/htoprc" based on this defaults, when opened the first time by per-user.
#     Use setup (F2) within htop GUI or edit "~/.config/htop/htoprc" to change settings for your user.
fields=48 18 46 47 49 1
sort_key=46
sort_direction=1
hide_threads=0
hide_kernel_threads=1
hide_userland_threads=1
shadow_other_users=0
show_thread_names=0
highlight_base_name=1
highlight_megabytes=1
highlight_threads=0
tree_view=0
header_margin=1
detailed_cpu_time=0
cpu_count_from_zero=0
color_scheme=0
delay=15
left_meters=AllCPUs Memory Swap
left_meter_modes=1 1 1
right_meters=Tasks LoadAverage Uptime
right_meter_modes=2 2 2
_EOF_
		G_ERROR_HANDLER_EXITCODE=$?
		G_ERROR_HANDLER

		G_DIETPI-NOTIFY 2 'Configuring fake-hwclock:'

		systemctl stop fake-hwclock

		# - allow times in the past
		G_CONFIG_INJECT 'FORCE=' 'FORCE=force' /etc/default/fake-hwclock

		systemctl restart fake-hwclock #failsafe, apply now if date is way far back...

		G_DIETPI-NOTIFY 2 'Configuring enable serial console:'

		/DietPi/dietpi/func/dietpi-set_hardware serialconsole enable

		G_DIETPI-NOTIFY 2 'Reducing getty count and resource usage:'

		systemctl mask getty-static
		# - logind features disabled by default. Usually not needed and all features besides auto getty creation are not available without libpam-systemd package.
		#	- It will be unmasked/enabled, automatically if libpam-systemd got installed during dietpi-software install, usually with desktops.
		systemctl stop systemd-logind
		systemctl disable systemd-logind &> /dev/null
		systemctl mask systemd-logind

		G_DIETPI-NOTIFY 2 'Configuring regional settings (TZdata):'

		[[ -f /etc/timezone ]] && rm /etc/timezone
		[[ -f /etc/localtime ]] && rm /etc/localtime
		ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
		G_RUN_CMD dpkg-reconfigure -f noninteractive tzdata

		G_DIETPI-NOTIFY 2 'Configuring regional settings (Keyboard):'

		dpkg-reconfigure -f noninteractive keyboard-configuration #Keyboard must be plugged in for this to work!

		#G_DIETPI-NOTIFY 2 "Configuring regional settings (Locale):"

		#Runs at start of script

		#G_HW_ARCH specific
		G_DIETPI-NOTIFY 2 'Applying G_HW_ARCH specific tweaks:'

		if (( $G_HW_ARCH == 10 )); then

			# - i386 APT support
			dpkg --add-architecture i386
			#G_AGUP # Not required here, since this will be done on every update+install

			# - Disable nouveau: https://github.com/Fourdee/DietPi/issues/1244 // https://dietpi.com/phpbb/viewtopic.php?f=11&t=2462&p=9688#p9688
			cat << _EOF_ > /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
_EOF_
			echo 'options nouveau modeset=0' > /etc/modprobe.d/nouveau-kms.conf
			update-initramfs -u

		fi

		#G_HW_MODEL specific
		G_DIETPI-NOTIFY 2 'Appling G_HW_MODEL specific tweaks:'

		if (( $G_HW_MODEL != 20 )); then

			G_DIETPI-NOTIFY 2 'Configuring hdparm:'

			sed -i '/#DietPi/,$d' /etc/hdparm.conf #Prevent dupes
			G_ERROR_HANDLER_COMMAND='/etc/hdparm.conf'
			cat << _EOF_ >> $G_ERROR_HANDLER_COMMAND

#DietPi external USB drive. Power management settings.
/dev/sda {
		#10 mins
		spindown_time = 120

		#
		apm = 127
}
_EOF_
			G_ERROR_HANDLER_EXITCODE=$?
			G_ERROR_HANDLER

		fi

		# - ARMbian OPi Zero 2: https://github.com/Fourdee/DietPi/issues/876#issuecomment-294350580
		if (( $G_HW_MODEL == 35 )); then

			echo 'blacklist bmp085' > /etc/modprobe.d/bmp085.conf

		# - Sparky SBC ONLY:
		elif (( $G_HW_MODEL == 70 )); then

			# 	Install latest kernel
			wget https://raw.githubusercontent.com/sparky-sbc/sparky-test/master/dragon_fly_check/uImage -O /boot/uImage
			wget https://raw.githubusercontent.com/sparky-sbc/sparky-test/master/dragon_fly_check/3.10.38.bz2 -O package.tar
			tar xvf package.tar -C /lib/modules/
			rm package.tar

			#	patches
			G_RUN_CMD wget https://raw.githubusercontent.com/sparky-sbc/sparky-test/master/dsd-marantz/snd-usb-audio.ko -O /lib/modules/3.10.38/kernel/sound/usb/snd-usb-audio.ko
			G_RUN_CMD wget https://raw.githubusercontent.com/sparky-sbc/sparky-test/master/dsd-marantz/snd-usbmidi-lib.ko -O /lib/modules/3.10.38/kernel/sound/usb/snd-usbmidi-lib.ko

			cat << _EOF_ > /DietPi/uEnv.txt
uenvcmd=setenv os_type linux;
bootargs=earlyprintk clk_ignore_unused selinux=0 scandelay console=tty0 loglevel=1 real_rootflag=rw root=/dev/mmcblk0p2 rootwait init=/lib/systemd/systemd aotg.urb_fix=1 aotg.aotg1_speed=0
_EOF_

			cp /DietPi/uEnv.txt /boot/uenv.txt #temp solution

			#	Blacklist GPU and touch screen modules: https://github.com/Fourdee/DietPi/issues/699#issuecomment-271362441
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

			#	Sparky SBC, WiFi rtl8812au driver: https://github.com/sparky-sbc/sparky-test/tree/master/rtl8812au
			G_RUN_CMD wget https://raw.githubusercontent.com/sparky-sbc/sparky-test/master/rtl8812au/rtl8812au_sparky.tar
			mkdir -p rtl8812au_sparky
			tar -xvf rtl8812au_sparky.tar -C rtl8812au_sparky
			chmod -R +x rtl8812au_sparky
			cd rtl8812au_sparky
			G_RUN_CMD ./install.sh
			cd /tmp/$G_PROGRAM_NAME
			rm -R rtl8812au_sparky*

			#	Use performance gov for stability.
			G_CONFIG_INJECT 'CONFIG_CPU_GOVERNOR=' 'CONFIG_CPU_GOVERNOR=performance' /DietPi/dietpi.txt

		# - RPI:
		elif (( $G_HW_MODEL < 10 )); then

			# - Scroll lock fix for RPi by Midwan: https://github.com/Fourdee/DietPi/issues/474#issuecomment-243215674
			cat << _EOF_ > /etc/udev/rules.d/50-leds.rules
ACTION=="add", SUBSYSTEM=="leds", ENV{DEVPATH}=="*/input*::scrolllock", ATTR{trigger}="kbd-scrollock"
_EOF_

		# - PINE64 (and possibily others): Cursor fix for FB
		elif (( $G_HW_MODEL == 40 )); then

			mkdir -p /etc/bashrc.d
			cat << _EOF_ > /etc/bashrc.d/dietpi-pine64-cursorfix.sh
#!/bin/bash

# DietPi: Cursor fix for FB
infocmp > terminfo.txt
sed -i -e 's/?0c/?112c/g' -e 's/?8c/?48;0;64c/g' terminfo.txt
tic terminfo.txt
tput cnorm
_EOF_

			# - Ensure WiFi module pre-exists
			G_CONFIG_INJECT '8723bs' '8723bs' /etc/modules

		#Rock64, remove HW accell config, as its not currently functional: https://github.com/Fourdee/DietPi/issues/2086
		elif (( $G_HW_MODEL == 43 )); then

			[[ -f /etc/X11/xorg.conf.d/20-armsoc.conf ]] && rm /etc/X11/xorg.conf.d/20-armsoc.conf

		# - Odroids FFMPEG fix. Prefer debian.org over Meveric for backports: https://github.com/Fourdee/DietPi/issues/1273 + https://github.com/Fourdee/DietPi/issues/1556#issuecomment-369463910
		elif (( $G_HW_MODEL > 9 && $G_HW_MODEL < 15 )); then

			rm -f /etc/apt/preferences.d/meveric*
			cat << _EOF_ > /etc/apt/preferences.d/dietpi-meveric-backports
Package: *
Pin: release a=jessie-backports
Pin: origin "fuzon.co.uk"
Pin-Priority: 99

Package: *
Pin: release a=jessie-backports
Pin: origin "oph.mdrjr.net"
Pin-Priority: 99
_EOF_

		fi

		# - ARMbian increase console verbose
		[[ -f /boot/armbianEnv.txt ]] && sed -i '/verbosity=/c\verbosity=7' /boot/armbianEnv.txt


		#------------------------------------------------------------------------------------------------
		echo ''
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		G_DIETPI-NOTIFY 0 "Step $SETUP_STEP: Finalise system for first run of DietPi:"
		((SETUP_STEP++))
		G_DIETPI-NOTIFY 2 '-----------------------------------------------------------------------------------'
		#------------------------------------------------------------------------------------------------

		l_message='Enable Dropbear autostart' G_RUN_CMD sed -i '/NO_START=1/c\NO_START=0' /etc/default/dropbear

		G_DIETPI-NOTIFY 2 'Configuring services'

		/DietPi/dietpi/dietpi-services stop
		/DietPi/dietpi/dietpi-services dietpi_controlled

		G_DIETPI-NOTIFY 2 'Mask cron until 1st run setup is completed'

		G_RUN_CMD systemctl mask cron

		G_DIETPI-NOTIFY 2 'Running general cleanup of misc files'

		# - Remove Bash history file
		[[ -f ~/.bash_history ]] && rm ~/.bash_history
		rm -f /home/*/.bash_history

		# - Remove Nano histroy file
		[[ -f ~/.nano_history ]] && rm ~/.nano_history
		rm -f /home/*/.nano_history

		G_DIETPI-NOTIFY 2 'Removing swapfile from image'

		/DietPi/dietpi/func/dietpi-set_dphys-swapfile 0 /var/swap
		[[ -e /var/swap ]] && rm /var/swap # still exists on some images...

		# - re-enable for next run
		G_CONFIG_INJECT 'AUTO_SETUP_SWAPFILE_SIZE=' 'AUTO_SETUP_SWAPFILE_SIZE=1' /DietPi/dietpi.txt

		G_DIETPI-NOTIFY 2 'Resetting boot.ini, config.txt, cmdline.txt etc'

		# - PineA64 - delete ethaddr from uEnv.txt file
		(( $G_HW_MODEL == 40 )) && [[ -f /boot/uEnv.txt ]] && sed -i '/^ethaddr/ d' /boot/uEnv.txt

		# - Set Pi cmdline.txt back to normal
		[[ -f /boot/cmdline.txt ]] && sed -i 's/ rootdelay=10//g' /boot/cmdline.txt

		G_DIETPI-NOTIFY 2 'Generating default wpa_supplicant.conf'

		/DietPi/dietpi/func/dietpi-wifidb 1
		#	move to /boot/ so users can modify as needed for automated
		G_RUN_CMD mv /var/lib/dietpi/dietpi-wifi.db /boot/dietpi-wifi.txt

		G_DIETPI-NOTIFY 2 'Disabling generic BT by default'

		/DietPi/dietpi/func/dietpi-set_hardware bluetooth disable

		# - Set WiFi
		local tmp_info='Disabling'
		local tmp_mode='disable'
		if (( $WIFI_REQUIRED )); then

			tmp_info='Enabling'
			tmp_mode='enable'

		fi

		G_DIETPI-NOTIFY 2 "$tmp_info onboard WiFi modules by default"
		/DietPi/dietpi/func/dietpi-set_hardware wifimodules onboard_$tmp_mode

		G_DIETPI-NOTIFY 2 "$tmp_info generic WiFi by default"
		/DietPi/dietpi/func/dietpi-set_hardware wifimodules $tmp_mode

		#	x86_64: kernel cmd line with GRUB
		if (( $G_HW_ARCH == 10 )); then

			l_message='Detecting additional OS installed on system' G_RUN_CMD os-prober

			# - Native PC/EFI (assume x86_64 only possible)
			if dpkg-query -s 'grub-efi-amd64' &> /dev/null &&
				[[ -d '/boot/efi' ]]; then

				l_message='Recreating GRUB-EFI' G_RUN_CMD grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch_grub --recheck

			fi

			# - Finalise GRUB
			if [[ -f '/etc/default/grub' ]]; then

				G_CONFIG_INJECT 'GRUB_CMDLINE_LINUX_DEFAULT=' 'GRUB_CMDLINE_LINUX_DEFAULT="consoleblank=0 quiet"' /etc/default/grub
				G_CONFIG_INJECT 'GRUB_CMDLINE_LINUX=' 'GRUB_CMDLINE_LINUX="net.ifnames=0"' /etc/default/grub
				G_CONFIG_INJECT 'GRUB_TIMEOUT=' 'GRUB_TIMEOUT=3' /etc/default/grub
				l_message='Finalizing GRUB' G_RUN_CMD update-grub

			fi

		fi

		G_DIETPI-NOTIFY 2 'Disabling soundcards by default'

		/DietPi/dietpi/func/dietpi-set_hardware soundcard none
		#	Alsa-utils is auto installed to reset soundcard settings on some ARM devices. uninstall it afterwards
		#	- The same for firmware-intel-sound (sound over HDMI?) on intel CPU devices
		#	- Purge "os-prober" from previous step as well
		G_AGP alsa-utils firmware-intel-sound os-prober
		G_AGA

		G_DIETPI-NOTIFY 2 'Setting default CPU gov'

		/DietPi/dietpi/func/dietpi-set_cpu

		G_DIETPI-NOTIFY 2 'Clearing log files'

		/DietPi/dietpi/func/dietpi-logclear 2

		G_DIETPI-NOTIFY 2 'Resetting DietPi generated globals/files'

		rm /DietPi/dietpi/.??*

		G_DIETPI-NOTIFY 2 'Set init .install_stage to -1 (first boot)'

		echo -1 > /DietPi/dietpi/.install_stage

		G_DIETPI-NOTIFY 2 'Writing PREP information to file'

		cat << _EOF_ > /DietPi/dietpi/.prep_info
$IMAGE_CREATOR
$PREIMAGE_INFO
_EOF_

		G_DIETPI-NOTIFY 2 'Generating GPL license readme'

		cat << _EOF_ > /var/lib/dietpi/license.txt
-----------------------
DietPi - GPLv2 License:
-----------------------
 - Use arrow keys to scrolll
 - Press 'TAB' then 'ENTER' to continue

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 2 of the License, or any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, please see http://www.gnu.org/licenses/'
_EOF_

		G_DIETPI-NOTIFY 2 'Clearing APT cache'

		G_RUN_CMD apt-get clean
		rm -Rfv /var/lib/apt/lists/* # Clear APT cache, gets regenerated on G_AGUP
		#rm /var/lib/dpkg/info/* #issue...
		#dpkg: warning: files list file for package 'libdbus-1-3:armhf' missing; assuming      package has no files currently installed

		# - HW Specific
		#	RPi remove saved G_HW_MODEL , allowing obtain-hw_model to auto detect RPi model
		(( $G_HW_MODEL < 10 )) && [[ -f /etc/.dietpi_hw_model_identifier ]] && rm /etc/.dietpi_hw_model_identifier

		# - BBB remove fsexpansion: https://github.com/Fourdee/DietPi/issues/931#issuecomment-345451529
		if (( $G_HW_MODEL == 71 )); then

			rm /etc/systemd/system/dietpi-fs_partition_resize.service
			rm /var/lib/dietpi/services/fs_partition_resize.sh
			systemctl daemon-reload

		else

			l_message='Enabling dietpi-fs_partition_resize for first boot' G_RUN_CMD systemctl enable dietpi-fs_partition_resize

		fi

		G_DIETPI-NOTIFY 2 'Storing DietPi version ID'

		G_RUN_CMD wget "https://raw.githubusercontent.com/$GITOWNER/DietPi/$GITBRANCH/dietpi/.version" -O /DietPi/dietpi/.version

		chmod +x /DietPi/dietpi/.version
		. /DietPi/dietpi/.version
		#	Reduce sub_version by 1, allows us to create image, prior to release and patch if needed.
		((G_DIETPI_VERSION_SUB--))

		G_CONFIG_INJECT 'DEV_GITBRANCH=' "DEV_GITBRANCH=$GITBRANCH" /DietPi/dietpi.txt
		G_CONFIG_INJECT 'DEV_GITOWNER=' "DEV_GITOWNER=$GITOWNER" /DietPi/dietpi.txt
		G_VERSIONDB_SAVE

		G_RUN_CMD cp /DietPi/dietpi/.version /var/lib/dietpi/.dietpi_image_version

		G_DIETPI-NOTIFY 2 'Sync changes to disk. Please wait, this may take some time...'

		G_RUN_CMD systemctl stop dietpi-ramlog
		G_RUN_CMD systemctl stop dietpi-ramdisk

		# - Clear DietPi logs, written during PREP
		rm -Rf /var/tmp/dietpi/logs/{,.??,.[^.]}*

		# - Clear items below mount points, e.g. from previous PREP's
		umount /DietPi
		rm -Rf /DietPi/{,.??,.[^.]}*

		umount /var/log
		rm -Rf /var/log/{,.??,.[^.]}*
		mount /var/log # Prevent new log files from being written to disk by background processes

		cd ~
		umount /tmp
		rm -Rf /tmp/{,.??,.[^.]}*
		mount /tmp # Prevent new tmp files from being written to disk by background processes

		# - Remove PREP script
		[[ -f $FP_PREP_SCRIPT ]] && rm $FP_PREP_SCRIPT

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

		#Power off system

		#Read image

		#Resize rootfs parition to mininum size +50MB

	}

	#------------------------------------------------------------------------------------------------
	#Run
	Main
	#------------------------------------------------------------------------------------------------

}
