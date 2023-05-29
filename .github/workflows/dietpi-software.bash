#!/bin/bash
# Created by MichaIng / micha@dietpi.com / dietpi.com
{
##########################################
# Load DietPi-Globals
##########################################
if [[ -f '/boot/dietpi/func/dietpi-globals' ]]
then
	. /boot/dietpi/func/dietpi-globals
else
	curl -sSf "https://raw.githubusercontent.com/${G_GITOWNER:=MichaIng}/DietPi/${G_GITBRANCH:=master}/dietpi/func/dietpi-globals" -o /tmp/dietpi-globals || exit 1
	# shellcheck disable=SC1091
	. /tmp/dietpi-globals
	G_EXEC_NOHALT=1 G_EXEC rm /tmp/dietpi-globals
	export G_GITOWNER G_GITBRANCH G_HW_ARCH_NAME=$(uname -m)
fi
case $G_HW_ARCH_NAME in
	'armv6l') export G_HW_ARCH=1;;
	'armv7l') export G_HW_ARCH=2;;
	'aarch64') export G_HW_ARCH=3;;
	'x86_64') export G_HW_ARCH=10;;
	'riscv64') export G_HW_ARCH=11;;
	*) G_DIETPI-NOTIFY 1 "Unsupported host system architecture \"$G_HW_ARCH_NAME\" detected, aborting..."; exit 1;;
esac
readonly G_PROGRAM_NAME='DietPi-Software_test_setup'
G_CHECK_ROOT_USER
G_CHECK_ROOTFS_RW
readonly FP_ORIGIN=$PWD # Store origin dir
G_INIT
G_EXEC cd "$FP_ORIGIN" # Process everything in origin dir instead of /tmp/$G_PROGRAM_NAME

##########################################
# Process inputs
##########################################
DISTRO=
ARCH=
SOFTWARE=
RPI=
while (( $# ))
do
	case $1 in
		'-d') shift; DISTRO=$1;;
		'-a') shift; ARCH=$1;;
		'-s') shift; SOFTWARE=$1;;
		'-rpi') shift; RPI=$1;;
		*) G_DIETPI-NOTIFY 1 "Invalid input \"$1\", aborting..."; exit 1;;
	esac
	shift
done
[[ $DISTRO =~ ^'buster'|'bullseye'|'bookworm'$ ]] || { G_DIETPI-NOTIFY 1 "Invalid distro \"$DISTRO\" passed, aborting..."; exit 1; }
case $ARCH in
	'armv6l') image="DietPi_Container-ARMv6-${DISTRO^}" arch=1;;
	'armv7l') image="DietPi_Container-ARMv7-${DISTRO^}" arch=2;;
	'aarch64') image="DietPi_Container-ARMv8-${DISTRO^}" arch=3;;
	'x86_64') image="DietPi_Container-x86_64-${DISTRO^}" arch=10;;
	'riscv64') image="DietPi_Container-RISC-V-Sid" arch=11;;
	*) G_DIETPI-NOTIFY 1 "Invalid architecture \"$ARCH\" passed, aborting..."; exit 1;;
esac
[[ $SOFTWARE =~ ^[0-9\ ]+$ ]] || { G_DIETPI-NOTIFY 1 "Invalid software list \"$SOFTWARE\" passed, aborting..."; exit 1; }
[[ $RPI =~ ^|'false'|'true'$ ]] || { G_DIETPI-NOTIFY 1 "Invalid RPi flag \"$RPI\" passed, aborting..."; exit 1; }

##########################################
# Create service and port lists
##########################################
aSERVICES=() aPORTS=() aCOMMANDS=()
Process_Software()
{
	local i
	for i in "$@"
	do
		case $i in
			'webserver') [[ $SOFTWARE =~ (^| )8[345]( |$) ]] || aSERVICES[83]='apache2' aPORTS[80]='tcp';;
			0) aCOMMANDS[i]='ssh -V';;
			1) aCOMMANDS[i]='smbclient -V';;
			2) aSERVICES[i]='fahclient' aPORTS[7396]='tcp';;
			7) aCOMMANDS[i]='ffmpeg -version';;
			9) aCOMMANDS[i]='node -v';;
			16) aSERVICES[i]='microblog-pub' aPORTS[8007]='tcp';;
			17) aCOMMANDS[i]='git -v';;
			28|120) aSERVICES[i]='vncserver' aPORTS[5901]='tcp';;
			29) aSERVICES[i]='xrdp' aPORTS[3389]='tcp';;
			30) aSERVICES[i]='nxserver' aPORTS[4000]='tcp';;
			32) aSERVICES[i]='ympd' aPORTS[1337]='tcp';;
			33) aSERVICES[i]='airsonic' aPORTS[8080]='tcp';;
			35) aSERVICES[i]='logitechmediaserver' aPORTS[9000]='tcp';;
			36) aSERVICES[i]='Squeezelite';; # Random high UDP port
			37) aSERVICES[i]='shairport-sync' aPORTS[5000]='tcp';; # AirPlay 2 would be TCP port 7000
			39) aSERVICES[i]='minidlna' aPORTS[8200]='tcp';;
			41) aSERVICES[i]='emby-server' aPORTS[8096]='tcp';;
			42) aSERVICES[i]='plexmediaserver' aPORTS[32400]='tcp';;
			43) aSERVICES[i]='mumble-server' aPORTS[64738]='tcp';;
			44) aSERVICES[i]='transmission-daemon' aPORTS[9091]='tcp';;
			45) aSERVICES[i]='deluged deluge-web' aPORTS[8112]='tcp' aPORTS[58846]='tcp' aPORTS[6882]='tcp';;
			46) aSERVICES[i]='qbittorrent' aPORTS[1340]='tcp' aPORTS[6881]='tcp';;
			49) aSERVICES[i]='gogs' aPORTS[3000]='tcp';;
			50) aSERVICES[i]='syncthing' aPORTS[8384]='tcp';;
			52) aSERVICES[i]='cuberite' aPORTS[1339]='tcp';;
			53) aSERVICES[i]='mineos' aPORTS[8443]='tcp';;
			58) aSERVICES[i]='tailscale';; # aPORTS[????]='udp';;
			59) aSERVICES[i]='raspimjpeg';;
			#60) aPORTS[53]='udp' aPORTS[68]='udp';; Cannot be installed in CI since a WiFi interface is required
			#61) aSERVICES[i]='tor' aPORTS[9040]='udp';; Cannot be installed in CI since a WiFi interface is required
			65) aSERVICES[i]='netdata' aPORTS[19999]='tcp';;
			66) aSERVICES[i]='rpimonitor' aPORTS[8888]='tcp';;
			71) aSERVICES[i]='webiopi' aPORTS[8002]='tcp';;
			73) aSERVICES[i]='fail2ban';;
			74) aSERVICES[i]='influxdb' aPORTS[8086]='tcp' aPORTS[8088]='tcp';;
			77) aSERVICES[i]='grafana-server' aPORTS[3001]='tcp';;
			80) aSERVICES[i]='ubooquity' aPORTS[2038]='tcp' aPORTS[2039]='tcp';;
			83) aSERVICES[i]='apache2' aPORTS[80]='tcp';;
			84) aSERVICES[i]='lighttpd' aPORTS[80]='tcp';;
			85) aSERVICES[i]='nginx' aPORTS[80]='tcp';;
			86) aSERVICES[i]='roon-extension-manager';;
			88) aSERVICES[i]='mariadb' aPORTS[3306]='tcp';;
			89) case $DISTRO in 'buster') aSERVICES[i]='php7.3-fpm';; 'bullseye') aSERVICES[i]='php7.4-fpm';; *) aSERVICES[i]='php8.2-fpm';; esac;;
			91) aSERVICES[i]='redis-server' aPORTS[6379]='tcp';;
			#93) aSERVICES[i]='pihole-FTL' aPORTS[53]='udp';; # Cannot be installed non-interactively
			94) aSERVICES[i]='proftpd' aPORTS[21]='tcp';;
			95) aSERVICES[i]='vsftpd' aPORTS[21]='tcp';;
			96) aSERVICES[i]='smbd' aPORTS[139]='tcp' aPORTS[445]='tcp';;
			97) aSERVICES[i]='openvpn' aPORTS[1194]='udp';;
			98) aSERVICES[i]='haproxy' aPORTS[80]='tcp';;
			99) aSERVICES[i]='node_exporter' aPORTS[9100]='tcp';;
			100) aSERVICES[i]='pijuice';; # aPORTS[????]='tcp';;
			104) aSERVICES[i]='dropbear' aPORTS[22]='tcp';;
			105) aSERVICES[i]='ssh' aPORTS[22]='tcp';;
			106) aSERVICES[i]='lidarr' aPORTS[8686]='tcp';;
			107) aSERVICES[i]='rtorrent' aPORTS[49164]='tcp' aPORTS[6881]='udp';;
			109) aSERVICES[i]='nfs-kernel-server' aPORTS[2049]='tcp';;
			111) aSERVICES[i]='urbackupsrv' aPORTS[55414]='tcp';;
			115) aSERVICES[i]='webmin' aPORTS[10000]='tcp';;
			116) aSERVICES[i]='medusa' aPORTS[8081]='tcp';;
			#117) :;; # ToDo: Implement automated install via /boot/unattended_pivpn.conf
			118) aSERVICES[i]='mopidy' aPORTS[6680]='tcp';;
			121) aSERVICES[i]='roonbridge' aPORTS[9003]='udp';;
			122) aSERVICES[i]='node-red' aPORTS[1880]='tcp';;
			123) aSERVICES[i]='mosquitto' aPORTS[1883]='tcp';;
			124) aSERVICES[i]='networkaudiod';; # aPORTS[????]='tcp';;
			125) aSERVICES[i]='synapse' aPORTS[8008]='tcp';;
			126) aSERVICES[i]='adguardhome' aPORTS[53]='udp' aPORTS[8083]='tcp'; [[ ${aSERVICES[182]} ]] && aPORTS[5353]='udp';; # Unbound uses port 5353 if AdGuard Home is installed
			128) aSERVICES[i]='mpd' aPORTS[6600]='tcp';;
			131) aSERVICES[i]='blynkserver' aPORTS[9443]='tcp';;
			132) aSERVICES[i]='aria2' aPORTS[6800]='tcp';; # aPORTS[6881-6999]='tcp';; # Listens on random port
			133) aSERVICES[i]='yacy' aPORTS[8090]='tcp';;
			135) aSERVICES[i]='icecast2 darkice' aPORTS[8000]='tcp';;
			136) aSERVICES[i]='motioneye' aPORTS[8765]='tcp';;
			137) aSERVICES[i]='mjpg-streamer' aPORTS[8082]='tcp';;
			138) aSERVICES[i]='virtualhere' aPORTS[7575]='tcp';;
			139) aSERVICES[i]='sabnzbd' aPORTS[8080]='tcp';; # ToDo: Solve conflict with Airsonic
			140) aSERVICES[i]='domoticz' aPORTS[8124]='tcp' aPORTS[8424]='tcp';;
			141) aSERVICES[i]='spotify-connect-web' aPORTS[4000]='tcp';;
			142) aSERVICES[i]='snapd';;
			143) aSERVICES[i]='koel' aPORTS[8003]='tcp';;
			144) aSERVICES[i]='sonarr' aPORTS[8989]='tcp';;
			145) aSERVICES[i]='radarr' aPORTS[7878]='tcp';;
			146) aSERVICES[i]='tautulli' aPORTS[8181]='tcp';;
			147) aSERVICES[i]='jackett' aPORTS[9117]='tcp';;
			148) aSERVICES[i]='mympd' aPORTS[1333]='tcp';;
			149) aSERVICES[i]='nzbget' aPORTS[6789]='tcp';;
			151) aSERVICES[i]='prowlarr' aPORTS[9696]='tcp';;
			152) aSERVICES[i]='avahi-daemon' aPORTS[5353]='udp';;
			153) aSERVICES[i]='octoprint' aPORTS[5001]='tcp';;
			154) aSERVICES[i]='roonserver';; # Listens on a variety of different port ranges
			155) aSERVICES[i]='htpc-manager' aPORTS[8085]='tcp';;
			157) aSERVICES[i]='home-assistant' aPORTS[8123]='tcp';;
			158) aSERVICES[i]='minio' aPORTS[9000]='tcp';; # ToDo: Solve port conflict with LMS
			161) aSERVICES[i]='bdd' aPORTS[80]='tcp' aPORTS[443]='tcp';;
			162) aSERVICES[i]='docker';;
			163) aSERVICES[i]='gmediarender';; # DLNA => UPnP high range of ports
			164) aSERVICES[i]='nukkit' aPORTS[19132]='udp';;
			165) aSERVICES[i]='gitea' aPORTS[3000]='tcp';;
			166) aSERVICES[i]='pi-spc';;
			167) aSERVICES[i]='raspotify';;
			169) aSERVICES[i]='voice-recognizer';;
			#171) aSERVICES[i]='frps frpc' aPORTS[7000]='tcp' aPORTS[7500]='tcp' aPORTS[7400]='tcp';; # Cannot be installed non-interactively, ports on chosen type
			#172) aSERVICES[i]='wg-quick@wg0' aPORTS[51820]='udp';; # cannot be installed non-interactively
			176) aSERVICES[i]='mycroft';;
			177) aSERVICES[i]='firefox-sync' aPORTS[5002]='tcp';;
			178) aSERVICES[i]='jellyfin' aPORTS[8097]='tcp';;
			179) aSERVICES[i]='komga' aPORTS[2037]='tcp';;
			180) aSERVICES[i]='bazarr' aPORTS[6767]='tcp';;
			181) aSERVICES[i]='papermc' aPORTS[25565]='tcp';;
			182) aSERVICES[i]='unbound' aPORTS[53]='udp'; [[ ${aSERVICES[126]} ]] && aPORTS[5353]='udp';; # Uses port 5353 if Pi-hole or AdGuard Home is installed, but those do listen on port 53 instead
			183) aSERVICES[i]='vaultwarden' aPORTS[8001]='tcp';;
			#184) aSERVICES[i]='tor' aPORTS[443]='tcp' aPORTS[9051]='tcp';; # Cannot be installed non-interactively, ports can be chosen and depend on chosen relay type
			185) aSERVICES[i]='docker' aPORTS[9002]='tcp';;
			186) aSERVICES[i]='ipfs' aPORTS[5003]='tcp' aPORTS[8087]='tcp';;
			187) aSERVICES[i]='cups' aPORTS[631]='tcp';;
			191) aSERVICES[i]='snapserver' aPORTS[1780]='tcp';;
			#192) aSERVICES[i]='snapclient';; # cannot be installed non-interactively
			194) aSERVICES[i]='postgresql';;
			196) aCOMMANDS[i]='java -version';;
			198) aSERVICES[i]='filebrowser' aPORTS[8084]='tcp';;
			199) aSERVICES[i]='spotifyd';; # aPORTS[4079]='tcp';; ???
			200) aSERVICES[i]='dietpi-dashboard' aPORTS[5252]='tcp';;
			201) aSERVICES[i]='zerotier-one' aPORTS[9993]='tcp';;
			202) aCOMMANDS[i]='rclone -h';;
			203) aSERVICES[i]='readarr' aPORTS[8787]='tcp';;
			204) aSERVICES[i]='navidrome' aPORTS[4533]='tcp';;
			206) aSERVICES[i]='openhab' aPORTS[8444]='tcp';;
			209) aCOMMANDS[i]='restic version';;
			*) :;;
		esac
	done
}
for i in $SOFTWARE
do
	case $i in
		205) Process_Software webserver;;
		27|56|63|64|107|132) Process_Software 89 webserver;; # 93 (Pi-hole) cannot be installed non-interactively
		38|40|48|54|55|57|59|90|160) Process_Software 88 89 webserver;;
		47|114|168) Process_Software 88 89 91 webserver;;
		8) Process_Software 196;;
		32|148|119) Process_Software 128;;
		129) Process_Software 88 89 128 webserver;;
		49|165) Process_Software 88;;
		#61) Process_Software 60;; # Cannot be installed in CI
		125) Process_Software 194;;
		*) :;;
	esac
	Process_Software "$i"
done

##########################################
# Dependencies
##########################################
apackages=('7zip' 'parted' 'fdisk' 'systemd-container')
(( $G_HW_ARCH == $arch || ( $G_HW_ARCH < 10 && $G_HW_ARCH > $arch ) )) || apackages+=('qemu-user-static' 'binfmt-support')
G_AG_CHECK_INSTALL_PREREQ "${apackages[@]}"

##########################################
# Prepare container
##########################################
# Download
G_EXEC curl -sSfO "https://dietpi.com/downloads/images/$image.7z"
G_EXEC 7zz e "$image.7z" "$image.img"
G_EXEC rm "$image.7z"
G_EXEC truncate -s 3G "$image.img"

# Loop device
FP_LOOP=$(losetup -f)
G_EXEC losetup "$FP_LOOP" "$image.img"
G_EXEC partprobe "$FP_LOOP"
G_EXEC partx -u "$FP_LOOP"
G_EXEC_OUTPUT=1 G_EXEC e2fsck -fp "${FP_LOOP}p1"
G_EXEC_OUTPUT=1 G_EXEC eval "sfdisk -fN1 '$FP_LOOP' <<< ',+'"
G_EXEC partprobe "$FP_LOOP"
G_EXEC partx -u "$FP_LOOP"
G_EXEC_OUTPUT=1 G_EXEC resize2fs "${FP_LOOP}p1"
G_EXEC_OUTPUT=1 G_EXEC e2fsck -fp "${FP_LOOP}p1"
G_EXEC mkdir rootfs
G_EXEC mount "${FP_LOOP}p1" rootfs

# Force ARMv6 arch on Raspbian
(( $arch == 1 )) && G_EXEC sed -i '/# Start DietPi-Software/iG_EXEC sed -i -e '\''/^G_HW_ARCH=/cG_HW_ARCH=1'\'' -e '\''/^G_HW_ARCH_NAME=/cG_HW_ARCH_NAME=armv6l'\'' /boot/dietpi/.hw_model' rootfs/boot/dietpi/dietpi-login

# Force RPi on ARM systems if requested
if [[ $RPI == 'true' ]] && (( $arch < 10 ))
then
	case $arch in
		1) model=1;;
		2) model=2;;
		3) model=4;;
		*) G_DIETPI-NOTIFY 1 "Invalid architecture $ARCH beginning with \"a\" but not being one of the known/accepted ARM architectures. This should never happen!"; exit 1;;
	esac
	G_EXEC sed -i "/# Start DietPi-Software/iG_EXEC sed -i -e '/^G_HW_MODEL=/cG_HW_MODEL=$model' -e '/^G_HW_MODEL_NAME=/cG_HW_MODEL_NAME=\"RPi $model ($ARCH)\"' /boot/dietpi/.hw_model; > /boot/config.txt; > /boot/cmdline.txt" rootfs/boot/dietpi/dietpi-login
	G_EXEC curl -sSf 'https://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-archive-keyring/raspberrypi-archive-keyring_2021.1.1+rpt1_all.deb' -o keyring.deb
	G_EXEC dpkg --root=rootfs -i keyring.deb
	G_EXEC rm keyring.deb
fi

# Workaround invalid TERM on login
# shellcheck disable=SC2016
G_EXEC eval 'echo '\''infocmp "$TERM" > /dev/null 2>&1 || { echo "[ INFO ] Unsupported TERM=\"$TERM\", switching to TERM=\"dumb\""; export TERM=dumb; }'\'' > rootfs/etc/bashrc.d/00-dietpi-ci.sh'

# Enable automated setup
G_CONFIG_INJECT 'AUTO_SETUP_AUTOMATED=' 'AUTO_SETUP_AUTOMATED=1' rootfs/boot/dietpi.txt

# Workaround for failing IPv4 network connectivity check as GitHub Actions runners do not receive external ICMP echo replies.
G_CONFIG_INJECT 'CONFIG_CHECK_CONNECTION_IP=' 'CONFIG_CHECK_CONNECTION_IP=127.0.0.1' rootfs/boot/dietpi.txt

# Apply Git branch
G_CONFIG_INJECT 'DEV_GITBRANCH=' "DEV_GITBRANCH=$G_GITBRANCH" rootfs/boot/dietpi.txt
G_CONFIG_INJECT 'DEV_GITOWNER=' "DEV_GITOWNER=$G_GITOWNER" rootfs/boot/dietpi.txt

# Avoid DietPi-Survey uploads to not mess with the statistics
G_EXEC rm rootfs/root/.ssh/known_hosts

# Apply software IDs to install
for i in $SOFTWARE; do G_CONFIG_INJECT "AUTO_SETUP_INSTALL_SOFTWARE_ID=$i" "AUTO_SETUP_INSTALL_SOFTWARE_ID=$i" rootfs/boot/dietpi.txt; done

# Workaround for failing Redis as of PrivateUsers=true leading to "Failed to set up user namespacing"
G_EXEC mkdir rootfs/etc/systemd/system/redis-server.service.d
G_EXEC eval 'echo -e '\''[Service]\nPrivateUsers=0'\'' > rootfs/etc/systemd/system/redis-server.service.d/dietpi-container.conf'

# Workarounds for failing MariaDB install on Buster within GitHub Actions runner (both cannot be replicated on my test systems with and without QEMU):
# - mysqld does not have write access if our symlink is in place, even that directory permissions are correct.
# - Type=notify leads to a service start timeout while mysqld has actually fully started.
if [[ $DISTRO == 'buster' ]]
then
	G_EXEC sed -i '/# Start DietPi-Software/a\sed -i -e '\''s|rm -Rf /var/lib/mysql|rm -Rf /mnd/dietpi_userdata/mysql|'\'' -e '\''s|ln -s /mnt/dietpi_userdata/mysql /var/lib/mysql|ln -s /var/lib/mysql /mnt/dietpi_userdata/mysql|'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login
	G_EXEC mkdir rootfs/etc/systemd/system/mariadb.service.d
	G_EXEC eval 'echo -e '\''[Service]\nType=exec'\'' > rootfs/etc/systemd/system/mariadb.service.d/dietpi-container.conf'
fi

# Workaround for failing 32-bit ARM Rust builds on ext4 in QEMU emulated container on 64-bit host: https://github.com/rust-lang/cargo/issues/9545
(( $arch < 3 && $G_HW_ARCH > 9 )) && G_EXEC eval 'echo -e '\''tmpfs /mnt/dietpi_userdata tmpfs size=3G,noatime,lazytime\ntmpfs /root tmpfs size=3G,noatime,lazytime'\'' >> rootfs/etc/fstab'

# Workaround for Node.js on ARMv6
(( $arch == 1 )) && G_EXEC sed -i '/# Start DietPi-Software/a\sed -i '\''/G_EXEC chmod +x node-install.sh/a\\sed -i "/^ARCH=/c\\ARCH=armv6l" node-install.sh'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login

# Check for service status, ports and commands
# shellcheck disable=SC2016
G_EXEC sed -i '/# Start DietPi-Software/a\sed -i '\''/# Custom 1st run script/a\\for i in "${aSTART_SERVICES[@]}"; do G_EXEC_NOHALT=1 G_EXEC systemctl start "$i"; done'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login
G_EXEC eval 'echo -e '\''#!/bin/dash\nexit_code=0; /boot/dietpi/dietpi-services start || exit_code=1'\'' > rootfs/boot/Automation_Custom_Script.sh'
if (( ${#aSERVICES[@]} || ${#aPORTS[@]} || ${#aCOMMANDS[@]} ))
then
	G_EXEC eval 'echo '\''sleep 30'\'' >> rootfs/boot/Automation_Custom_Script.sh'
	for i in "${aSERVICES[@]}"
	do
		cat << _EOF_ >> rootfs/boot/Automation_Custom_Script.sh
echo -n '\e[33m[ INFO ] Checking $i service status:\e[0m '
systemctl is-active '$i' || { journalctl -u '$i'; exit_code=1; }
_EOF_
	done
	for i in "${!aPORTS[@]}"
	do
		cat << _EOF_ >> rootfs/boot/Automation_Custom_Script.sh
echo '\e[33m[ INFO ] Checking ${aPORTS[i]^^} port $i status:\e[0m'
ss -${aPORTS[i]::1}lpn | grep ':${i}[[:blank:]]' || exit_code=1
_EOF_
	done
	for i in "${aCOMMANDS[@]}"
	do
		cat << _EOF_ >> rootfs/boot/Automation_Custom_Script.sh
echo '\e[33m[ INFO ] Testing command $i:\e[0m'
$i || exit_code=1
_EOF_
	done
fi

# Success flag and shutdown
# shellcheck disable=SC2016
G_EXEC eval 'echo '\''[ $exit_code = 0 ] && > /success || { journalctl -n 25; ss -tlpn; df -h; free -h; poweroff; }; poweroff'\'' >> rootfs/boot/Automation_Custom_Script.sh'

# Shutdown as well on failure
G_EXEC sed -i 's|Prompt_on_Failure$|{ journalctl -n 25; ss -tlpn; df -h; free -h; poweroff; }|' rootfs/boot/dietpi/dietpi-login

##########################################
# Boot container
##########################################
systemd-nspawn -bD rootfs
[[ -f 'rootfs/success' ]] || { journalctl -n 25; df -h; free -h; exit 1; }
}
