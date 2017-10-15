
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
#  - Sections with '#???', are optional, depending on the device and its specs. (eg: does it need bluetooth?)
#------------------------------------------------------------------------------------------------

#This is not currently a executable script. Please manually run through the commands:
exit 0 #prevent continuation of this script.


#------------------------------------------------------------------------------------------------
#Packages
#------------------------------------------------------------------------------------------------

#NOTE:
#Apt mirror will get overwritten by: /DietPi/dietpi/func/dietpi-set_software apt-mirror default : during finalize.

#??? RPI
DISTRO='stretch'
cat << _EOF_ > /etc/apt/sources.list
deb https://www.mirrorservice.org/sites/archive.raspbian.org/raspbian $DISTRO main contrib non-free rpi
_EOF_

cat << _EOF_ > /etc/apt/sources.list.d/raspi.list
deb https://archive.raspberrypi.org/debian/ $DISTRO main ui
_EOF_

#??? Everything else (excluding RPi!)
DISTRO='stretch'
cat << _EOF_ > /etc/apt/sources.list
deb http://ftp.debian.org/debian/ $DISTRO main contrib non-free
deb http://ftp.debian.org/debian/ $DISTRO-updates main contrib non-free
deb http://security.debian.org $DISTRO/updates main contrib non-free
deb http://ftp.debian.org/debian/ $DISTRO-backports main contrib non-free
_EOF_


#+Meveric images
rm /etc/apt/sources.list.d/deb-multimedia.list

#Remove following All
apt-get clean
apt-get update
apt-get purge -y fonts-* xmms2-client-* pulseaudio* jq xxd iperf3 gdisk gpsd ppp libboost-iostreams* sgml-base xml-core usb-modeswitch* libpng* cpp-* cpp ntpdate bluez bluetooth rsync dialog dhcpcd5 lua5.1 netcat-* make makedev ncdu plymouth openresolv shared-mime-in* tcpd strace tasksel* wireless-* xdg-user-dirs triggerhappy python* v4l-utils traceroute xz-utils ucf xauth zlib1g-dev xml-core aptitude* avahi-daemon rsyslog logrotate man-db manpages vim vim-common vim-runtime vim-tiny mc mc-data

#+Desktop images (Mostly desktop packages, but apply to non-desktop images also):
apt-get purge -y libpod-* libpeas-* isc-dhcp-server gnome-* fonts-dejavu* eject dnsmasq* dns-root-data colord-data libjasper* libjson* libwbclient* libwayland* golang-* libavahi* libtext* libweb* libpcsclite1 libxau6* libxc* dictionaries-* libgtk* miscfiles minicom lrzsz lxmenu-* x11-* zenity* yelp-*

rm -R /usr/share/fonts/*
rm -R /usr/share/icons/*

#+armbian
apt-get purge -y expect tcl-expect toilet toilet-fonts w-scan vlan weather-util* sysbench stress cmake cmake-data device-tree-co* fping hddtemp haveged hostapd i2c-tools iperf ir-keytable libasound2* libmtp* libusb-dev lirc lsof ncurses-term pkg-config unicode-data rfkill pv mtp-tools m4 screen alsa-utils autotools-dev bind9-host btrfs-tools bridge-utils cpufrequtils dvb-apps dtv-scan-table* evtest f3 figlet gcc gcc-4.8-* git git-man ifenslave
#apt-get purge -y linux-jessie-root-*

#+ dev packages
#	On ARMbian DEV branch images, manually do this as triggers '*-dev' image/uboot etc
apt-get purge -y '\-dev$' linux-headers*

#+ Meveric's repo | Renders patch for removal in apt
# apt-get purge setup-odroid # not compat with DietPi

#??? RPI
apt-get purge -y rpi-update libraspberrypi-doc
#??? RPI (remove older version packages marked as manual): https://github.com/Fourdee/DietPi/issues/598#issuecomment-25919922
apt-get purge gcc-4.6-base gcc-4.7-base gcc-4.8-base libsigc++-1.2-5c2



apt-get autoremove --purge -y

#??? ROCK64, reinstall kernel packages:
apt-get install linux-rock64-package

apt-get dist-upgrade -y

#install packages
echo -e "CONF_SWAPSIZE=0" > /etc/dphys-swapfile
apt-get install -y gnupg net-tools cron rfkill ca-certificates locales apt-transport-https ethtool p7zip-full hfsplus iw debconf-utils xz-utils fbset wpasupplicant resolvconf bc dbus bzip2 psmisc bash-completion cron whiptail sudo ntp ntfs-3g dosfstools parted hdparm usbutils zip htop wput wget fake-hwclock dphys-swapfile curl unzip console-setup console-data console-common keyboard-configuration wireless-tools wireless-regdb crda --no-install-recommends

#??? Grub/intel+amd microcode firmware x86_64 native
#	MBR
apt-get install -y grub2
#	UEFI
apt-get install -y grub-common grub-efi-amd64 grub-efi-amd64-bin grub2-common

apt-get install firmware-linux-nonfree -y

#??? bluetooth if onboard device / RPI
apt-get install -y bluetooth bluez-firmware

#??? RPi - bluetooth/firmware for all RPi's
apt-get install -y pi-bluetooth
#??? RPi - common rpi specific binaries (eg: raspistill)
apt-get install -y libraspberrypi-bin

#??? x86 images only: firmware
apt-get install -y firmware-realtek firmware-ralink firmware-brcm80211 firmware-atheros --no-install-recommends

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
echo -e "Samba client can be installed and setup by DietPi-Config.\nSimply run: dietpi-config and select the Networking Options: NAS/Misc menu" > /mnt/samba/readme.txt
echo -e "FTP client mount can be installed and setup by DietPi-Config.\nSimply run: dietpi-config and select the Networking Options: NAS/Misc menu" > /mnt/ftp_client/readme.txt
echo -e "NFS client can be installed and setup by DietPi-Config.\nSimply run: dietpi-config and select the Networking Options: NAS/Misc menu" > /mnt/nfs_client/readme.txt

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
ExecStart=/usr/bin/killall sshd && /usr/bin/killall dropbear

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
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
}
_EOF_

#Disable automatic updates and management of apt cache. Prevents unexpected lock on Apt cache and therefore failed apt installations.
systemctl mask apt-daily.service
systemctl mask apt-daily-upgrade.timer

#/etc/sysctl.conf | Check for a previous entry before adding this
echo -e "vm.swappiness=1" >> /etc/sysctl.conf

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
export \$(cat /etc/default/locale | grep LANG=)
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

#NTPd - remove systemd's version
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


#??? Native PC, add i386 support by default
dpkg --add-architecture i386
apt-get update

#??? ARMbian OPi Zero 2: https://github.com/Fourdee/DietPi/issues/876#issuecomment-294350580
echo -e "blacklist bmp085" > /etc/modprobe.d/bmp085.conf

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

#??? RPI ONLY: Scroll lock fix for RPi by Midwan: https://github.com/Fourdee/DietPi/issues/474#issuecomment-243215674
cat << _EOF_ > /etc/udev/rules.d/50-leds.rules
ACTION=="add", SUBSYSTEM=="leds", ENV{DEVPATH}=="*/input*::scrolllock", ATTR{trigger}="kbd-scrollock"
_EOF_

#??? PINE (and possibily others): Cursor fix for FB
cat << _EOF_ >> "$HOME"/.bashrc
infocmp > terminfo.txt
sed -i -e 's/?0c/?112c/g' -e 's/?8c/?48;0;64c/g' terminfo.txt
tic terminfo.txt
tput cnorm
_EOF_

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
