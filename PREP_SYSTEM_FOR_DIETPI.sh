
#------------------------------------------------------------------------------------------------
# Setup a Debian installation, for DietPi.
#------------------------------------------------------------------------------------------------
# NOTICE: Images created by non-DietPi staff, will NOT be officially supported by DietPi, unless authorized by DietPi.
# NOTICE: There is no offical support for using these script/notes. However, exceptions may be made.
#------------------------------------------------------------------------------------------------
# Before starting, copy the following files and folders to /boot/ https://github.com/Fourdee/DietPi
#  - /boot/dietpi.txt (file)
#  - /boot/config.txt (file)
#  - /boot/dietpi (folder)
#------------------------------------------------------------------------------------------------
# Legend:
#  - Items that are commented out should not be used.
#  - Sections with '#???', are WHIP_OPTIONal, depending on the device and its specs. (eg: does it need bluetooth?)
#------------------------------------------------------------------------------------------------
#Force en_GB Locale for whole script. Prevents incorrect parsing with non-english locales.
LANG=en_GB.UTF-8

#Ensure we are in users home dir: https://github.com/Fourdee/DietPi/issues/905#issuecomment-298223705
cd "$HOME"

#Exit path for non-root logins.
if (( $UID != 0 )); then

	echo -e 'Error: Root privileges required. Please run the command with "sudo"\n'
	exit

fi

#------------------------------------------------------------------------------------------------
#Globals
#------------------------------------------------------------------------------------------------
#System
DISTRO=4
DISTRO_NAME='stretch'
HW_MODEL=0

#Funcs
INTERNET_ADDRESS=''
Check_Connection(){

	wget -q --spider --timeout=10 --tries=2 "$INTERNET_ADDRESS"

}

Error_Check(){

	#Grab exit code in case of failure
	exit_code=$?
	if (( $exit_code != 0 )); then

		dietpi-notify 1 "($exit_code): Script aborted"
		exit $exit_code

	else

		dietpi-notify 2 "($exit_code): Passed"
	fi

}

#Apt-get
AGI(){

	local string="$@"

	local force_WHIP_OPTIONs='--force-yes'

	if (( $DISTRO >= 4 )); then

		force_WHIP_OPTIONs='--allow-downgrades --allow-remove-essential --allow-change-held-packages --allow-unauthenticated'

	fi

	DEBIAN_FRONTEND=noninteractive $(which apt) install -y $force_WHIP_OPTIONs $string

}

AGP(){

	local string="$@"
	if (( $DISTRO >= 4 )); then

		string+=' --allow-change-held-packages'

	fi

	#DEBUG: Dry run for testing
	string+=' --dry-run'

	$(which apt) purge -y $string

}

#DietPi-Notify:
dietpi-notify(){

	local ainput_string=("$@")

	local status_text_ok="\e[32mOk\e[0m"
	local status_text_failed="\e[31mFailed:\e[0m"

	local bracket_string_l="\e[90m[\e[0m"
	local bracket_string_r="\e[90m]\e[0m"

	#Funcs

	Print_Ok(){

		echo -ne " $bracket_string_l\e[32mOk\e[0m$bracket_string_r"

	}

	Print_Failed(){

		echo -ne " $bracket_string_l\e[31mFailed\e[0m$bracket_string_r"

	}

	# - Print all input string on same line
	# - $1 = start printing from word number $1
	Print_Input_String(){

		for (( i=$1;i<${#ainput_string[@]} ;i++))
		do
			echo -ne " ${ainput_string[${i}]}"
		done

		echo -e ""

	}

	# Main Loop
	#--------------------------------------------------------------------------------------
	echo -e ""

	if (( $1 == -1 )); then

		if [ "$2" = "0" ]; then

			ainput_string+=("Completed")
			Print_Ok
			Print_Input_String 2
			echo -e ""

		else

			ainput_string+=("An issue has occured")
			Print_Failed
			Print_Input_String 2
			echo -e ""

		fi

	#--------------------------------------------------------------------------------------
	#Status Ok
	#$@ = txt desc
	elif (( $1 == 0 )); then

		Print_Ok
		Print_Input_String 1

	#Status failed
	#$@ = txt desc
	elif (( $1 == 1 )); then

		Print_Failed
		Print_Input_String 1

	#Status Info
	#$@ = txt desc
	elif (( $1 == 2 )); then

		echo -ne " $bracket_string_l\e[0mInfo\e[0m$bracket_string_r"
		echo -ne "\e[90m"
		Print_Input_String 1
		echo -ne "\e[0m"

	fi

	echo -e ""
	#-----------------------------------------------------------------------------------
	unset ainput_string
	#-----------------------------------------------------------------------------------
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

	WHIP_OPTION=$(whiptail --title "$WHIP_TITLE" --menu "$WHIP_DESC" --default-item "$WHIP_DEFAULT_ITEM" --backtitle "$WHIP_BACKTITLE" 30 80 20 "${WHIP_MENU_ARRAY[@]}" 3>&1 1>&2 2>&3)
	WHIP_CHOICE=$?
	if (( $WHIP_CHOICE == 0 )); then

		WHIP_RETURN_VALUE=$WHIP_OPTION

	else

		dietpi-notify 1 'No choices detected, aborting'
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
#Step 1: Initial Critical Prep
#------------------------------------------------------------------------------------------------

###############
dietpi-notify 0 'Updating Apt and installing initial core packages'

apt-get clean
Error_Check

apt-get update
Error_Check

###############
dietpi-notify 0 'Installing Core Packages'
AGI wget unzip whiptail
Error_Check

#------------------------------------------------------------------------------------------------
#Step 2: Hardware selection
#------------------------------------------------------------------------------------------------
###############
dietpi-notify 0 'Hardware selection'

WHIP_TITLE='Hardware selection'
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
	'21' 'x86_64 native (PC)'
	'20' 'VM x64 (VMware VirtualBox)'
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
HW_MODEL=$WHIP_RETURN_VALUE

dietpi-notify 2 "Setting HW_MODEL index of: $HW_MODEL"


#------------------------------------------------------------------------------------------------
#Step 3: Distro Selection + APT prep
#------------------------------------------------------------------------------------------------
###############
dietpi-notify 0 'Distro selection'

WHIP_TITLE='Distro Selection'
WHIP_DESC='Please select a distro to install on this system. Selecting a distro that is older than the current installed on system, is not supported.'
WHIP_DEFAULT_ITEM=4
WHIP_MENU_ARRAY=(
	'1' 'wheezy'
	'3' 'jessie'
	'4' 'stretch'
	'5' 'buster'
)

Run_Whiptail
DISTRO=$WHIP_RETURN_VALUE

if (( $DISTRO == 1 )); then

	DISTRO_NAME='wheezy'

elif (( $DISTRO == 3 )); then

	DISTRO_NAME='jessie'

elif (( $DISTRO == 4 )); then

	DISTRO_NAME='stretch'

elif (( $DISTRO == 5 )); then

	DISTRO_NAME='buster'

fi

###############
dietpi-notify 0 'Removing conflicting apt sources.list.d'

#rm /etc/apt/sources.list.d/* &> /dev/null #Probably a bad idea
rm /etc/apt/sources.list.d/deb-multimedia.list &> /dev/null #meveric
echo 0 #always pass
Error_Check

###############
dietpi-notify 0 "Setting APT sources.list: $DISTRO_NAME $DISTRO"

if (( $HW_MODEL < 10 )); then

	cat << _EOF_ > /etc/apt/sources.list
deb https://www.mirrorservice.org/sites/archive.raspbian.org/raspbian $DISTRO main contrib non-free rpi
_EOF_

	cat << _EOF_ > /etc/apt/sources.list.d/raspi.list
deb https://archive.raspberrypi.org/debian/ $DISTRO main ui
_EOF_

else

	cat << _EOF_ > /etc/apt/sources.list
deb http://ftp.debian.org/debian/ $DISTRO_NAME main contrib non-free
deb http://ftp.debian.org/debian/ $DISTRO_NAME-updates main contrib non-free
deb http://security.debian.org $DISTRO_NAME/updates main contrib non-free
deb http://ftp.debian.org/debian/ $DISTRO_NAME-backports main contrib non-free
_EOF_

fi
Error_Check

#NB: Apt mirror will get overwritten by: /DietPi/dietpi/func/dietpi-set_software apt-mirror default : during finalize.

###############
dietpi-notify 0 "Updating APT for $DISTRO_NAME"

apt-get clean
Error_Check

apt-get update
Error_Check

#------------------------------------------------------------------------------------------------
#Step 4: APT removals
#------------------------------------------------------------------------------------------------

###############
dietpi-notify 0 "Removing Core APT packages not required by DietPi"

AGP libpython* xmms2-client-* pulseaudio* jq xxd iperf3 gdisk gpsd ppp libboost-iostreams* sgml-base xml-core usb-modeswitch* libpng* cpp-* cpp ntpdate bluez bluetooth rsync dialog dhcpcd5 lua5.1 netcat-* make makedev ncdu plymouth openresolv shared-mime-in* tcpd strace tasksel* wireless-* xdg-user-dirs triggerhappy python* v4l-utils traceroute xz-utils ucf xauth zlib1g-dev xml-core aptitude* avahi-daemon rsyslog logrotate man-db manpages vim vim-common vim-runtime vim-tiny mc mc-data
Error_Check

###############
dietpi-notify 0 "Removing webserver APT packages not required by DietPi"

#TD: Add php here
AGP apache2* lighttpd* nginx*
Error_Check

###############
dietpi-notify 0 "Removing Desktop related APT packages not required by DietPi"

AGP gnome-* mate-* lxde lxde-* lxmenu-* fonts-dejavu* libwayland* dictionaries-* libgtk* x11-* zenity* yelp-* fonts-*
Error_Check

###############
dietpi-notify 0 "Removing Misc (Stage 1) APT packages not required by DietPi"

AGP libpod-* libpeas-* isc-dhcp-server eject dnsmasq* dns-root-data colord-data libjasper* libjson* libwbclient* golang-* libavahi* libtext* libweb* libpcsclite1 libxau6* libxc* miscfiles minicom lrzsz
Error_Check

###############
dietpi-notify 0 "Removing Misc (Stage 2) APT packages not required by DietPi"

AGP nodejs memtester expect tcl-expect toilet toilet-fonts w-scan vlan weather-util* sysbench stress cmake cmake-data device-tree-co* fping hddtemp haveged hostapd i2c-tools iperf ir-keytable libasound2* libmtp* libusb-dev lirc lsof ncurses-term pkg-config unicode-data rfkill pv mtp-tools m4 screen alsa-utils autotools-dev bind9-host btrfs-tools bridge-utils cpufrequtils dvb-apps dtv-scan-table* evtest f3 figlet gcc gcc-4.8-* git git-man ifenslave
Error_Check

###############
dietpi-notify 0 "Removing Fonts/Icons not Required by DietPi"

rm -R /usr/share/fonts/*
rm -R /usr/share/icons/*

###############
dietpi-notify 0 "Removing Dev APT packages not required by DietPi"

AGP '\-dev$' linux-headers*
Error_Check

# - Hardware specific
if (( $HW_MODEL == 71 )); then

	###############
	dietpi-notify 0 "Removing BBB APT packages not required by DietPi"

	AGP roboticscape ardupilot-* ti-* bonescript libapr1
	Error_Check

elif (( $HW_MODEL < 10 )); then

	###############
	dietpi-notify 0 "Removing RPi APT packages not required by DietPi"

	AGP rpi-update libraspberrypi-doc gcc-4.6-base gcc-4.7-base gcc-4.8-base libsigc++-1.2-5c2
	Error_Check

fi


###############
dietpi-notify 0 "Purging APT with autoremoval"

apt-get autoremove --purge -y
Error_Check







#??? ROCK64, reinstall kernel packages:
# apt-get install linux-rock64-package
#???

#???: WHIP_OPTIONal Reinstall OpenSSH (for updating dietpi scripts etc). Gets removed during finalise.
# apt-get install openssh-server -y
# echo -e "PermitRootLogin yes" >> /etc/ssh/sshd_config
# systemctl restart ssh
#???


exit








#------------------------------------------------------------------------------------------------
#Packages
#------------------------------------------------------------------------------------------------




#install packages
apt-get dist-upgrade -y
echo -e "CONF_SWAPSIZE=0" > /etc/dphys-swapfile
apt-get install -y gnupg net-tools cron rfkill ca-certificates locales apt-transport-https ethtool p7zip-full hfsplus iw debconf-utils xz-utils fbset wpasupplicant resolvconf bc dbus bzip2 psmisc bash-completion cron whiptail sudo ntp ntfs-3g dosfstools parted hdparm usbutils zip htop wput wget fake-hwclock dphys-swapfile curl unzip console-setup console-data console-common keyboard-configuration wireless-tools wireless-regdb crda --no-install-recommends


#??? Grub/intel+amd microcode firmware x86_64 native
#	MBR
apt-get install -y grub2
#	UEFI
apt-get install -y grub-common grub-efi-amd64 grub-efi-amd64-bin grub2-common
#???

#??? bluetooth if onboard device / RPI
apt-get install -y bluetooth bluez-firmware
#???

#??? RPi - bluetooth/firmware for all RPi's
apt-get install -y pi-bluetooth libraspberrypi-bin
#???

#??? x86 images only: firmware
apt-get install -y firmware-linux-nonfree firmware-realtek firmware-ralink firmware-brcm80211 firmware-atheros --no-install-recommends
#???

#------------------------------------------------------------------------------------------------
#DIETPI STUFF
#------------------------------------------------------------------------------------------------
chmod +x -R /boot

#Delete any non-root user (eg: pi)
userdel -f pi
userdel -f test #armbian
userdel -f odroid
userdel -f rock64
userdel -f linaro #ASUS TB
userdel -f dietpi
userdel -f debian #BBB

#Remove folders (now in finalise script)

#+Remove files
#rm /etc/apt/sources.list.d/armbian.list
rm /etc/init.d/resize2fs
rm /etc/update-motd.d/* # ARMbian

systemctl disable firstrun
rm /etc/init.d/firstrun # ARMbian

#	Disable ARMbian's log2ram: https://github.com/Fourdee/DietPi/issues/781
systemctl disable log2ram.service
systemctl stop log2ram.service
rm /usr/local/sbin/log2ram
rm /etc/systemd/system/log2ram.service
systemctl daemon-reload
rm /etc/cron.hourly/log2ram

rm /etc/init.d/cpu_governor # Meveric
rm /etc/systemd/system/cpu_governor.service # Meveric

#	Disable ARMbian's resize service (not automatically removed by ARMbian scripts...)
systemctl disable resize2fs
rm /etc/systemd/system/resize2fs.service

#	ARMbian-config
rm /etc/profile.d/check_first_login_reboot.sh

#Set UID bit for sudo: https://github.com/Fourdee/DietPi/issues/794
chmod 4755 /usr/bin/sudo

#Create DietPi common folders
mkdir /DietPi

mkdir -p /mnt/dietpi_userdata

mkdir -p /mnt/samba
mkdir -p /mnt/ftp_client
mkdir -p /mnt/nfs_client
echo -e "Samba client can be installed and setup by DietPi-Config.\nSimply run: dietpi-config and select the Networking WHIP_OPTIONs: NAS/Misc menu" > /mnt/samba/readme.txt
echo -e "FTP client mount can be installed and setup by DietPi-Config.\nSimply run: dietpi-config and select the Networking WHIP_OPTIONs: NAS/Misc menu" > /mnt/ftp_client/readme.txt
echo -e "NFS client can be installed and setup by DietPi-Config.\nSimply run: dietpi-config and select the Networking WHIP_OPTIONs: NAS/Misc menu" > /mnt/nfs_client/readme.txt

/boot/dietpi/dietpi-logclear 2

#FSTAB
cp /boot/dietpi/conf/fstab /etc/fstab
systemctl daemon-reload
mount -a

#Setup DietPi services
#	DietPi-Ramdisk
cat << _EOF_ > /etc/systemd/system/dietpi-ramdisk.service
[Unit]
Description=DietPi-RAMdisk
After=local-fs.target

[Service]
Type=forking
RemainAfterExit=yes
ExecStartPre=/bin/mkdir -p /etc/dietpi/logs
ExecStart=/bin/bash -c '/boot/dietpi/dietpi-ramdisk 0'
ExecStop=/bin/bash -c '/DietPi/dietpi/dietpi-ramdisk 1'

[Install]
WantedBy=local-fs.target
_EOF_
systemctl enable dietpi-ramdisk.service
systemctl daemon-reload
systemctl start dietpi-ramdisk.service

#	DietPi-Ramlog
cat << _EOF_ > /etc/systemd/system/dietpi-ramlog.service
[Unit]
Description=DietPi-RAMlog
Before=rsyslog.service syslog.service
After=local-fs.target

[Service]
Type=forking
RemainAfterExit=yes
ExecStart=/bin/bash -c '/boot/dietpi/dietpi-ramlog 0'
ExecStop=/bin/bash -c '/DietPi/dietpi/dietpi-ramlog 1'

[Install]
WantedBy=local-fs.target
_EOF_
systemctl enable dietpi-ramlog.service
systemctl daemon-reload
systemctl start dietpi-ramlog.service

#	Boot
cat << _EOF_ > /etc/systemd/system/dietpi-boot.service
[Unit]
Description=DietPi-Boot
After=network-online.target network.target networking.service dietpi-ramdisk.service dietpi-ramlog.service
Requires=dietpi-ramdisk.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '/DietPi/dietpi/boot'
StandardOutput=tty

[Install]
WantedBy=multi-user.target
_EOF_
systemctl enable dietpi-boot.service
systemctl daemon-reload

#	Remove rc.local from /etc/init.d
update-rc.d -f rc.local remove
rm /etc/init.d/rc.local
rm /lib/systemd/system/rc-local.service

cat << _EOF_ > /etc/systemd/system/rc-local.service
[Unit]
Description=/etc/rc.local Compatibility
After=dietpi-boot.service dietpi-ramdisk.service dietpi-ramlog.service
Requires=dietpi-boot.service dietpi-ramdisk.service

[Service]
Type=idle
ExecStart=/etc/rc.local
StandardOutput=tty
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
_EOF_
systemctl enable rc-local.service
systemctl daemon-reload

cat << _EOF_ > /etc/rc.local
#!/bin/bash
#Precaution: Wait for DietPi Ramdisk to finish
while [ ! -f /DietPi/.ramdisk ]
do

    /DietPi/dietpi/func/dietpi-notify 2 "Waiting for DietPi-RAMDISK to finish mounting DietPi to RAM..."
    sleep 1

done

echo -e "\$(cat /proc/uptime | awk '{print \$1}') Seconds" > /var/log/boottime
if (( \$(cat /DietPi/dietpi/.install_stage) == 1 )); then

    /DietPi/dietpi/dietpi-services start

fi
/DietPi/dietpi/dietpi-banner 0
echo -e " Default Login:\n Username = root\n Password = dietpi\n"
exit 0
_EOF_
chmod +x /etc/rc.local
systemctl daemon-reload

#	Shutdown SSH/Dropbear before reboot
cat << _EOF_ > /etc/systemd/system/kill-ssh-user-sessions-before-network.service
[Unit]
Description=Shutdown all ssh sessions before network
DefaultDependencies=no
Before=network.target shutdown.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'killall sshd &> /dev/null; killall dropbear &> /dev/null'

[Install]
WantedBy=poweroff.target halt.target reboot.target
_EOF_
systemctl enable kill-ssh-user-sessions-before-network
systemctl daemon-reload


#Cron jobs
cp /DietPi/dietpi/conf/cron.daily_dietpi /etc/cron.daily/dietpi
chmod +x /etc/cron.daily/dietpi
cp /DietPi/dietpi/conf/cron.hourly_dietpi /etc/cron.hourly/dietpi
chmod +x /etc/cron.hourly/dietpi

#Crontab
cat << _EOF_ > /etc/crontab
#Please use dietpi-cron to change cron start times
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# m h dom mon dow user  command
17 *    * * *   root    cd / && run-parts --report /etc/cron.hourly
25 1    * * *   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.daily )
47 1    * * 7   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.weekly )
52 1    1 * *   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.monthly )
_EOF_

#ntp
rm /etc/cron.daily/ntp &> /dev/null
rm /etc/init.d/ntp &> /dev/null

#Apt
# - Force use existing installed configs if available, else install new. Also disables end user prompt from dpkg
cat << _EOF_ > /etc/apt/apt.conf.d/local
Dpkg::options {
   "--force-confdef";
   "--force-confold";
}
_EOF_

#Disable automatic updates and management of apt cache. Prevents unexpected lock on Apt cache and therefore failed apt installations.
systemctl mask apt-daily.service
systemctl mask apt-daily-upgrade.timer

#/etc/sysctl.conf | Check for a previous entry before adding this
echo -e "vm.swappiness=1" > /etc/sysctl.d/97-dietpi.conf

#login,
echo -e "\n/DietPi/dietpi/login" >> /root/.bashrc

#Network
rm -R /etc/network/interfaces # armbian symlink for bulky network-manager
cp /boot/dietpi/conf/network_interfaces /etc/network/interfaces
/DietPi/dietpi/func/obtain_network_details
# - enable allow-hotplug eth0 after copying.
sed -i "/allow-hotplug eth/c\allow-hotplug eth$(sed -n 1p /DietPi/dietpi/.network)" /etc/network/interfaces


#Reduce DHCP request retry count and timeouts: https://github.com/Fourdee/DietPi/issues/711
sed -i '/^#timeout /d' /etc/dhcp/dhclient.conf
sed -i '/^#retry /d' /etc/dhcp/dhclient.conf
sed -i '/^timeout /d' /etc/dhcp/dhclient.conf
sed -i '/^retry /d' /etc/dhcp/dhclient.conf
cat << _EOF_ >> /etc/dhcp/dhclient.conf
timeout 10;
retry 4;
_EOF_

#Hosts
cat << _EOF_ > /etc/hosts
127.0.0.1    localhost
127.0.1.1    DietPi
::1          localhost ip6-localhost ip6-loopback
ff02::1      ip6-allnodes
ff02::2      ip6-allrouters
_EOF_

cat << _EOF_ > /etc/hostname
DietPi
_EOF_

#htop cfg
mkdir -p /root/.config/htop
cp /boot/dietpi/conf/htoprc /root/.config/htop/htoprc

#hdparm
cat << _EOF_ >> /etc/hdparm.conf

#DietPi external USB drive. Power management settings.
/dev/sda {
        #10 mins
        spindown_time = 120

        #
        apm = 254
}
_EOF_

cat << _EOF_ >> /etc/bash.bashrc
#LANG
export \$(cat /etc/default/locale | grep LANG=)

#Define a default LD_LIBRARY_PATH for all systems
export LD_LIBRARY_PATH=/lib:/usr/lib:/usr/local/lib:/opt/vc/lib

#DietPi Additions
alias sudo='sudo ' # https://github.com/Fourdee/DietPi/issues/424
alias dietpi-process_tool='/DietPi/dietpi/dietpi-process_tool'
alias dietpi-letsencrypt='/DietPi/dietpi/dietpi-letsencrypt'
alias dietpi-autostart='/DietPi/dietpi/dietpi-autostart'
alias dietpi-cron='/DietPi/dietpi/dietpi-cron'
alias dietpi-launcher='/DietPi/dietpi/dietpi-launcher'
alias dietpi-cleaner='/DietPi/dietpi/dietpi-cleaner'
alias dietpi-morsecode='/DietPi/dietpi/dietpi-morsecode'
alias dietpi-sync='/DietPi/dietpi/dietpi-sync'
alias dietpi-backup='/DietPi/dietpi/dietpi-backup'
alias dietpi-bugreport='/DietPi/dietpi/dietpi-bugreport'
alias dietpi-services='/DietPi/dietpi/dietpi-services'
alias dietpi-config='/DietPi/dietpi/dietpi-config'
alias dietpi-software='/DietPi/dietpi/dietpi-software'
alias dietpi-update='/DietPi/dietpi/dietpi-update'
alias dietpi-drive_manager='/DietPi/dietpi/dietpi-drive_manager'
alias emulationstation='/opt/retropie/supplementary/emulationstation/emulationstation'
alias opentyrian='/usr/local/games/opentyrian/run'

alias cpu='/DietPi/dietpi/dietpi-cpuinfo'
alias dietpi-logclear='/DietPi/dietpi/dietpi-logclear'
treesize()
{
     du -k --max-depth=1 | sort -nr | awk '
     BEGIN {
        split("KB,MB,GB,TB", Units, ",");
     }
     {
        u = 1;
        while (\$1 >= 1024)
        {
           \$1 = \$1 / 1024;
           u += 1;
        }
        \$1 = sprintf("%.1f %s", \$1, Units[u]);
        print \$0;
     }
    '
}
_EOF_


#fakehwclock - allow times in the past
sed -i "/FORCE=/c\FORCE=force" /etc/default/fake-hwclock

#wifi dongles | move to dietpi-set_hardware wifi
# echo -e "options 8192cu rtw_power_mgnt=0" > /etc/modprobe.d/8192cu.conf
# echo -e "options 8188eu rtw_power_mgnt=0" > /etc/modprobe.d/8188eu.conf
# echo -e "options 8189es rtw_power_mgnt=0" > /etc/modprobe.d/8189es.conf


#Set swapfile size
echo -e "CONF_SWAPSIZE=0" > /etc/dphys-swapfile

#nano /etc/systemd/logind.conf
#NAutoVTs=1

#nano /etc/default/console-setup
#Reduce gettys ACTIVE_CONSOLES="/dev/tty[1-2]"

systemctl disable getty@tty[2-6].service
#systemctl disable serial-getty@ttyS0.service

#NTPd default - Disable systemd's version
systemctl disable systemd-timesyncd

#+ARMbian increase console verbose
sed -i '/verbosity=/c\verbosity=7' /boot/armbianEnv.txt


dpkg-reconfigure tzdata #Europe > London
dpkg-reconfigure keyboard-configuration #Keyboard must be plugged in for this to work!
dpkg-reconfigure locales # en_GB.UTF8 as default and only installed locale

#Pump default locale into sys env: https://github.com/Fourdee/DietPi/issues/825
cat << _EOF_ > /etc/environment
LC_ALL=en_GB.UTF-8
LANG=en_GB.UTF-8
_EOF_

#Prefer to use wlan/eth naming for networked devices (eg: stretch)
ln -sf /dev/null /etc/systemd/network/99-default.link
#??? x86_64
#	kernel cmd line with GRUB
#	/etc/default/grub [replace] GRUB_CMDLINE_LINUX="net.ifnames=0"
#								GRUB_TIMEOUT=0
#???

#??? Native PC, add i386 support by default
dpkg --add-architecture i386
apt-get update
#???

#??? ARMbian OPi Zero 2: https://github.com/Fourdee/DietPi/issues/876#issuecomment-294350580
echo -e "blacklist bmp085" > /etc/modprobe.d/bmp085.conf
#???

#??? Sparky SBC ONLY: Blacklist GPU and touch screen modules: https://github.com/Fourdee/DietPi/issues/699#issuecomment-271362441
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
#???

#??? RPI ONLY: Scroll lock fix for RPi by Midwan: https://github.com/Fourdee/DietPi/issues/474#issuecomment-243215674
cat << _EOF_ > /etc/udev/rules.d/50-leds.rules
ACTION=="add", SUBSYSTEM=="leds", ENV{DEVPATH}=="*/input*::scrolllock", ATTR{trigger}="kbd-scrollock"
_EOF_
#???

#??? PINE (and possibily others): Cursor fix for FB
cat << _EOF_ >> "$HOME"/.bashrc
infocmp > terminfo.txt
sed -i -e 's/?0c/?112c/g' -e 's/?8c/?48;0;64c/g' terminfo.txt
tic terminfo.txt
tput cnorm
_EOF_
#???


#??? XU4 FFMPEG fix. Prefer debian.org over Meveric for backports: https://github.com/Fourdee/DietPi/issues/1273
cat << _EOF_ > /etc/apt/preferences.d/backports
Package: *
Pin: release a=jessie-backports
Pin: origin "fuzon.co.uk"
Pin-Priority: 99
_EOF_
#???

#??? x86_64
#	Disable nouveau: https://github.com/Fourdee/DietPi/issues/1244 // http://dietpi.com/phpbb/viewtopic.php?f=11&t=2462&p=9688#p9688
cat << _EOF_ > /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
_EOF_
echo -e "options nouveau modeset=0" > /etc/modprobe.d/nouveau-kms.conf
update-initramfs -u
#???


#------------------------------------------------------------------------------------------------
#A Unique HW_MODEL index will need to be assigned and coded into the DietPi sourcecode.
# If you are not creating a pull request for this, then:
#
# Email:
#	Address='daniel.knight@dietpi.com'
#	Subject title='Unique HW_MODEL Index Request [DEVICENAME]' | Where DEVICENAME could be 'Odroid C3'
#------------------------------------------------------------------------------------------------

#Once you have the updated sourcecode, update the file '/DietPi/dietpi/dietpi-obtain_hw_model'

#??? Does this device have a unique HW ID index and file? check /DietPi/dietpi/dietpi-obtain_hw_model
echo ID > /etc/.dietpi_hw_model_identifier

#Finalise system
/DietPi/dietpi/finalise

#Power off system

#Read image

#Resize 2nd parition to mininum size +50MB
