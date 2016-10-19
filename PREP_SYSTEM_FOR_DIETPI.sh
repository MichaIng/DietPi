
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

#Jessie , unified apt sources.
rm /etc/apt/sources.list.d/deb-multimedia.list

#  - C2
# cat << _EOF_ > /etc/apt/sources.list
# deb http://ftp.debian.org/debian jessie main contrib non-free
# deb http://ftp.debian.org/debian jessie-updates main contrib non-free
# deb http://security.debian.org jessie/updates main contrib non-free
# deb http://ftp.debian.org/debian jessie-backports main contrib non-free
# deb http://ftp.debian.org/debian jessie-proposed-updates contrib non-free main
# _EOF_

# 	C2	stretch
# cat << _EOF_ > /etc/apt/sources.list
# deb http://ftp.debian.org/debian stretch main contrib non-free
# deb http://ftp.debian.org/debian stretch-updates main contrib non-free
# deb http://security.debian.org stretch/updates main contrib non-free
# deb http://ftp.debian.org/debian stretch-backports main contrib non-free
# deb http://ftp.debian.org/debian stretch-proposed-updates contrib non-free main
# _EOF_
# apt-get update
# apt-get install busybox-static
# apt-get upgrade -y
# apt-get dist-upgrade -y
# apt-get autoremove --purge -y

# rpi stretch
# cat << _EOF_ > /etc/apt/sources.list
# deb http://archive.raspbian.org/raspbian stretch main contrib non-free rpi
# _EOF_
# apt-get update
# apt-get upgrade -y
# apt-get dist-upgrade -y
# apt-get autoremove --purge -y


# deb-src http://ftp.debian.org/debian jessie main contrib non-free
# deb-src http://ftp.debian.org/debian jessie-updates main contrib non-free
# deb-src http://security.debian.org jessie/updates main contrib non-free
# deb-src http://ftp.debian.org/debian jessie-backports main contrib non-free
# deb-src http://ftp.debian.org/debian jessie-proposed-updates contrib non-free main


#NOTE:
#Apt mirror will get overwritten by: /DietPi/dietpi/func/dietpi-set_software apt-mirror default : during finalize.

# - Everything else (excluding RPi!)
cat << _EOF_ > /etc/apt/sources.list
deb http://ftp.debian.org/debian jessie main contrib non-free
deb http://ftp.debian.org/debian jessie-updates main contrib non-free
deb http://security.debian.org jessie/updates main contrib non-free
deb http://ftp.debian.org/debian jessie-backports main contrib non-free
_EOF_

# RPI UK mirror director is slow, unstable and unreliable -------------------------
cat << _EOF_ > /etc/apt/sources.list
deb http://mirror.ox.ac.uk/sites/archive.raspbian.org/archive/raspbian jessie main contrib non-free rpi
_EOF_

#Stretch
# cat << _EOF_ > /etc/apt/sources.list
# deb http://mirror.ox.ac.uk/sites/archive.raspbian.org/archive/raspbian stretch main contrib non-free rpi
# _EOF_
# RPI UK mirror director is slow, unstable and unreliable -------------------------


#Remove following Jessie
apt-get clean
apt-get update
apt-get purge libpng* cpp-* cpp ntpdate bluez bluetooth rsync dialog dhcpcd5 libsqlite* libxapian22 lua5.1 netcat-* make makedev ncdu plymouth openresolv shared-mime-in* tcpd strace tasksel* wireless-* xdg-user-dirs triggerhappy python* v4l-utils traceroute xz-utils ucf xauth zlib1g-dev xml-core aptitude* avahi-daemon rsyslog logrotate man-db manpages vim vim-common vim-runtime vim-tiny mc mc-data

#+Desktop images (Mostly desktop packages, but apply to non-desktop images also):
apt-get purge libpod-* libpeas-* isc-dhcp-server gnome-* fonts-dejavu* eject dnsmasq* dns-root-data colord-data libturbojpeg1 libjasper* libjson* libwbclient* libwayland* golang-* libavahi* libtext* libweb* libpcsclite1 libxau6* libvpx1 libxc* dictionaries-* libgtk* miscfiles minicom lrzsz lxmenu-* x11-* zenity* yelp-*

#+armbian
apt-get purge toilet toilet-fonts w-scan vlan weather-util* sysbench stress apt-transport-* cmake cmake-data device-tree-co* fping hddtemp haveged hostapd i2c-tools iperf ir-keytable libasound2* libmtp* libusb-dev lirc lsof ncurses-term pkg-config unicode-data rfkill pv mtp-tools m4 screen alsa-utils armbian-* autotools-dev bind9-host btrfs-tools bridge-utils cpufrequtils dvb-apps dtv-scan-table* evtest f3 figlet gcc gcc-4.8-* git git-man iozone3 ifenslave
apt-get purge -y linux-jessie-root-*

#rm /etc/apt/sources.list.d/armbian.list
rm /etc/init.d/resize2fs
systemctl daemon-reload
rm /etc/update-motd.d/*

#+RPi
apt-get purge libraspberrypi-doc

#+ dev packages
apt-get purge '\-dev$' linux-headers*


apt-get autoremove --purge -y


#install packages
echo -e "CONF_SWAPSIZE=0" > /etc/dphys-swapfile
apt-get install -y ethtool p7zip-full hfsplus iw debconf-utils xz-utils ifmetric fbset wpasupplicant resolvconf bc dbus bzip2 psmisc bash-completion cron whiptail sudo ntp ntfs-3g dosfstools parted hdparm pciutils usbutils zip htop wput wget fake-hwclock dphys-swapfile curl unzip ca-certificates console-setup console-data console-common keyboard-configuration wireless-tools wireless-regdb crda --no-install-recommends

#??? bluetooth if onboard device
apt-get install -y bluetooth

#firmware
apt-get install -y firmware-realtek firmware-ralink firmware-brcm80211 firmware-atheros -y --no-install-recommends

#------------------------------------------------------------------------------------------------
#DIETPI STUFF
#------------------------------------------------------------------------------------------------

#Delete any non-root user (eg: pi)
userdel -f pi
userdel -f test #armbian

#Remove folders
rm -R /home
rm -R /media
rm -R /tmp/*
rm -R /selinux

#Remove files
rm /etc/init.d/cpu_governor # Meveric XU4

#Create DietPi common folders
mkdir /DietPi

mkdir -p /mnt/dietpi_userdata

mkdir -p /mnt/usb_1

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

#setup dietpi service
echo 1 > /boot/dietpi/.install_stage
cp /boot/dietpi/conf/dietpi-service /etc/init.d/dietpi-service
chmod +x /etc/init.d/dietpi-service
update-rc.d dietpi-service defaults 00 80
systemctl daemon-reload
service dietpi-service start

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

#/etc/sysctl.conf | Check for a previous entry before adding this
echo -e "vm.swappiness=1" >> /etc/sysctl.conf

#rc.local
cat << _EOF_ > /etc/rc.local
#!/bin/bash
echo -e "\$(cat /proc/uptime | awk '{print \$1}') Seconds" > /var/log/boottime
if (( \$(cat /DietPi/dietpi/.install_stage) == 1 )); then

    /DietPi/dietpi/dietpi-services start

fi
/DietPi/dietpi/dietpi-banner 0
echo -e " Default Login:\n Username = root\n Password = dietpi\n"
exit 0
_EOF_
chmod +x /etc/rc.local

#login,
#echo -e "\n/DietPi/dietpi/login" >> /root/.bashrc

#Network
cp /boot/dietpi/conf/network_interfaces /etc/network/interfaces
/DietPi/dietpi/func/obtain_network_details
# - enable allow-hotplug eth0 after copying.
sed -i "/allow-hotplug eth/c\allow-hotplug eth$(sed -n 1p /DietPi/dietpi/.network)" /etc/network/interfaces

#Add ipv6 flags DietPi uses to disable IPV6 if set.
cat << _EOF_ >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
_EOF_

#Netplug: Now installed and configured on demand by dietpi-config
# cat << _EOF_ > /etc/netplug/netplugd.conf
# eth*
# wlan*
# _EOF_

#htop cfg
mkdir -p /root/.config/htop
cp /boot/dietpi/conf/htoprc /root/.config/htop/htoprc

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

#wifi dongles
echo -e "options 8192cu rtw_power_mgnt=0" > /etc/modprobe.d/8192cu.conf
echo -e "options 8188eu rtw_power_mgnt=0" > /etc/modprobe.d/8188eu.conf

#Set swapfile size
echo -e "CONF_SWAPSIZE=0" > /etc/dphys-swapfile

#nano /etc/systemd/logind.conf
#NAutoVTs=1

#nano /etc/default/console-setup
#Reduce gettys ACTIVE_CONSOLES="/dev/tty[1-2]"

systemctl disable getty@tty[2-6].service
#systemctl disable serial-getty@ttyS0.service

#NTPd - remove systemd's version
systemctl disable systemd-timesync

#Remove rc.local from /etc/init.d
update-rc.d -f rc.local remove
rm /etc/init.d/rc.local
rm /lib/systemd/system/rc-local.service

cat << _EOF_ > /etc/systemd/system/rc-local.service
[Unit]
Description=/etc/rc.local Compatibility
After=dietpi-service.service

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

#Shutdown SSH/Dropbear before reboot
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


dpkg-reconfigure tzdata #Europe > London
dpkg-reconfigure keyboard-configuration #Keyboard must be plugged in for this to work!
dpkg-reconfigure locales # en_GB.UTF8 as default and only installed locale

#??? RPI ONLY: Scroll lock fix for RPi by Midwan: https://github.com/Fourdee/DietPi/issues/474#issuecomment-243215674
cat << _EOF_ > /etc/udev/rules.d/50-leds.rules
ACTION=="add", SUBSYSTEM=="leds", ENV{DEVPATH}=="*/input*::scrolllock", ATTR{trigger}="kbd-scrollock"
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

#Finalise system
/DietPi/dietpi/finalise

#??? Does this device have a unique HW ID index and file? check /DietPi/dietpi/dietpi-obtain_hw_model
echo ID > /etc/.dietpi_hw_model_identifier

#Power off system

#Read image

#Resize 2nd parition to mininum size +50MB
