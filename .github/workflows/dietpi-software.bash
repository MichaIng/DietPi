#!/bin/bash
# Created by MichaIng / micha@dietpi.com / dietpi.com
{
##########################################
# Load DietPi-Globals
##########################################
Error_Exit(){ G_DIETPI-NOTIFY 1 "$1, aborting ..."; exit 1; }
if [[ -f '/boot/dietpi/func/dietpi-globals' ]]
then
	. /boot/dietpi/func/dietpi-globals
else
	curl -sSf "https://raw.githubusercontent.com/${G_GITOWNER:=MichaIng}/DietPi/${G_GITBRANCH:=master}/dietpi/func/dietpi-globals" -o /tmp/dietpi-globals || { echo 'Failed to download DietPi-Globals, aborting ...'; exit 1; }
	# shellcheck disable=SC1091
	. /tmp/dietpi-globals
	G_EXEC rm /tmp/dietpi-globals
	export G_GITOWNER G_GITBRANCH G_HW_ARCH_NAME=$(uname -m)
	read -r debian_version < /etc/debian_version
	case $debian_version in
		'12.'*|'bookworm/sid') G_DISTRO=7;;
		'13.'*|'trixie/sid') G_DISTRO=8;;
		'14.'*|'forky/sid') G_DISTRO=9;;
		*) Error_Exit "Unsupported distro version \"$debian_version\"";;
	esac
	# Ubuntu ships with /etc/debian_version from Debian testing, hence we assume one version lower.
	grep -q '^ID=ubuntu' /etc/os-release && ((G_DISTRO--))
	(( $G_DISTRO < 7 )) && Error_Exit 'Unsupported Ubuntu version'
fi
case $G_HW_ARCH_NAME in
	'armv6l') export G_HW_ARCH=1;;
	'armv7l') export G_HW_ARCH=2;;
	'aarch64') export G_HW_ARCH=3;;
	'x86_64') export G_HW_ARCH=10;;
	'riscv64') export G_HW_ARCH=11;;
	*) Error_Exit "Unsupported host system architecture \"$G_HW_ARCH_NAME\" detected";;
esac
readonly G_PROGRAM_NAME='DietPi-Software test'
G_CHECK_ROOT_USER "$@"
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
RPI=false
TEST=false
while (( $# ))
do
	case $1 in
		'-d') shift; DISTRO=$1;;
		'-a') shift; ARCH=$1;;
		'-s') shift; SOFTWARE=$1;;
		'-rpi') shift; RPI=$1;;
		'-t') shift; TEST=$1;;
		*) Error_Exit "Invalid input \"$1\"";;
	esac
	shift
done
case $DISTRO in
	'bullseye') dist=6;;
	'bookworm') dist=7;;
	'trixie') dist=8;;
	'forky') dist=9;;
	*) Error_Exit "Invalid distro \"$DISTRO\" passed";;
esac
case $ARCH in
	'armv6l') image="ARMv6-${DISTRO^}" arch=1;;
	'armv7l') image="ARMv7-${DISTRO^}" arch=2;;
	'aarch64') image="ARMv8-${DISTRO^}" arch=3;;
	'x86_64') image="x86_64-${DISTRO^}" arch=10;;
	'riscv64') image="RISC-V-${DISTRO^}" arch=11;;
	*) Error_Exit "Invalid architecture \"$ARCH\" passed";;
esac
image="DietPi_Container-$image.img"
[[ $SOFTWARE =~ ^[0-9\ ]+$ ]] || Error_Exit "Invalid software list \"$SOFTWARE\" passed"
[[ $RPI =~ ^('false'|'true')$ ]] || Error_Exit "Invalid RPi flag \"$RPI\" passed"
[[ $TEST =~ ^('false'|'true')$ ]] || Error_Exit "Invalid test flag \"$TEST\" passed"

# Emulation support in case of incompatible architecture
emulation=0
(( $G_HW_ARCH == $arch || ( $G_HW_ARCH < 10 && $G_HW_ARCH > $arch ) )) || emulation=1

# Allo GUI (non-full/reinstall ID 160): Add MariaDB for needed database generation
[[ $SOFTWARE =~ (^| )160( |$) ]] && SOFTWARE=$(sed -E 's/(^| )160( |$)/\188 160\2/g' <<< "$SOFTWARE")
# Removals for QEMU-emulated tests:
# - PostgreSQL and dependants (Synapse): https://gitlab.com/qemu-project/qemu/-/issues/3068
# - WireGuard: "Unable to modify/access interface: Protocol not supported"
# - Docker containers (Roon Extension Manager and Synapse): Docker daemon fails with "iptables: Failed to initialize nft: Protocol not supported" and similar error with iptables-legacy
[[ $arch == 11 && $emulation == 1 && $SOFTWARE =~ (^| )(86|125|172|185|194)( |$) ]] && { echo '[ WARN ] Removing Roon Extension Manager, PostgreSQL, WireGuard, Portainer, and Synapse from test installs as they fail in emulated RISC-V containers'; SOFTWARE=$(sed -E 's/(^| )(86|125|172|185|194)( |$)/\1\3/g' <<< "$SOFTWARE"); }

##########################################
# Create service and port lists
##########################################
aINSTALL=() aSERVICES=() aTCP=() aUDP=() aCOMMANDS=() aDELAY=() CAPABILITIES='' SYSCALLS='' aOPTIONS=()
Process_Software()
{
	local i
	for i in "$@"
	do
		# shellcheck disable=SC2016
		case $i in
			'webserver') [[ $SOFTWARE =~ (^| )8[345]( |$) ]] || Process_Software 83;;
			0) aCOMMANDS[i]='ssh -V';;
			1) aCOMMANDS[i]='smbclient -V';;
			2) aSERVICES[i]='fahclient' aTCP[i]='7396';;
			3) aCOMMANDS[i]='mc -V';;
			4) aCOMMANDS[i]='fish -v';;
			5) aCOMMANDS[i]='aplay -l';;
			6) aCOMMANDS[i]='X -version';;
			7) aCOMMANDS[i]='ffmpeg -version';;
			8) aCOMMANDS[i]='javac -version';;
			9) aCOMMANDS[i]='node -v';;
			10) aCOMMANDS[i]='amiberry-lite -h | grep '\''^\$VER: Amiberry-Lite '\';;
			11) aCOMMANDS[i]='gzdoom -norun | grep '\''^GZDoom version '\';;
			#16) aSERVICES[i]='microblog-pub' aTCP[i]='8007';; Service enters a CPU-intense internal error loop until it has been configured interactively via "microblog-pub configure", hence it is not enabled and started anymore after install but instead as part of "microblog-pub configure"
			17) aCOMMANDS[i]='git --version';; # from Bookworm on, the shorthand "-v" is supported
			#22) QuiteRSS: has no CLI
			23) aCOMMANDS[i]='lxsession -h';;
			24) aCOMMANDS[i]='mate-session -h';;
			25) aCOMMANDS[i]='xfce4-session -h';;
			26) aCOMMANDS[i]='gnustep-tests';;
			#27) TasmoAdmin
			28) aSERVICES[i]='vncserver' aTCP[i]='5901';;
			29) aSERVICES[i]='xrdp' aTCP[i]='3389';;
			30) aSERVICES[i]='nxserver' aTCP[i]='4000';;
			31) [[ $arch == 1 && $DISTRO == 'bookworm' ]] || aCOMMANDS[i]='kodi -v';; # Bookworm RPi repo "kodi" calls fgconsole and chvt which both fails in non-interactive container: "Couldn't get a file descriptor referring to the console."
			32) aSERVICES[i]='ympd' aTCP[i]='1337';;
			33) (( $emulation )) || aSERVICES[i]='airsonic' aTCP[i]='8080' aDELAY[i]=60;; # Fails in QEMU-emulated containers, probably due to missing device access
			34) aCOMMANDS[i]='COMPOSER_ALLOW_SUPERUSER=1 composer -n -V';;
			35) (( $dist < 8 || $arch > 2 )) && aSERVICES[i]='lyrionmusicserver' aTCP[i]='9000';; # disable check on 32-bit ARM Trixie for now: https://github.com/LMS-Community/slimserver/tree/public/9.1/CPAN/arch/5.40
			36) aCOMMANDS[i]='squeezelite -t';; # Service listens on random high UDP port and exits if no audio device has been found, which does not exist on GitHub Actions runners, respectively within the containers
			37) aSERVICES[i]='shairport-sync' aTCP[i]='5000';; # AirPlay 2 would be TCP port 7000
			38) aCOMMANDS[i]='/opt/FreshRSS/cli/user-info.php';;
			39) aSERVICES[i]='minidlna' aTCP[i]='8200';;
			#40) Ampache
			41) aSERVICES[i]='emby-server' aTCP[i]='8096';;
			42) aSERVICES[i]='plexmediaserver' aTCP[i]='32400';;
			43) aSERVICES[i]='mumble-server' aTCP[i]='64738';;
			44) aSERVICES[i]='transmission-daemon' aTCP[i]='9091 51413' aUDP[i]='51413';;
			45) aSERVICES[i]='deluged deluge-web' aTCP[i]='8112 58846 6882';;
			46) aSERVICES[i]='qbittorrent' aTCP[i]='1340 6881';;
			47) aCOMMANDS[i]='sudo -u www-data php /var/www/owncloud/occ status';;
			#48) Pydio
			49) aSERVICES[i]='gogs' aTCP[i]='3000';;
			50) aSERVICES[i]='syncthing' aTCP[i]='8384';;
			51) aCOMMANDS[i]='/usr/games/opentyrian/opentyrian -h';;
			52) aSERVICES[i]='cuberite' aTCP[i]='1339' aDELAY[i]=60;;
			53) aSERVICES[i]='mineos' aTCP[i]='8443';;
			#54) phpBB
			#55) WordPress
			#56) Single File PHP Gallery
			#57) Baïkal
			58) aCOMMANDS[i]='tailscale version';; # aSERVICES[i]='tailscaled' aUDP[i]='41641' GitHub Actions runners do not support the TUN module
			59) aSERVICES[i]='raspimjpeg';;
			60) aCOMMANDS[i]='iptables -V' aSERVICES[i]='isc-dhcp-server' aUDP[i]='67';; # aSERVICES[i]='hostapd' fails without actual WiFi interface
			61) aSERVICES[i]='tor' aTCP[i]='9040' aUDP[i]='53';;
			62) aCOMMANDS[i]='box86 -v';;
			#63 LinuxDash
			#64 phpSysInfo
			65) aSERVICES[i]='netdata' aTCP[i]='19999';;
			66) aSERVICES[i]='rpimonitor' aTCP[i]='8888';;
			67) aCOMMANDS[i]='firefox-esr -v';;
			68) aSERVICES[i]='schannel' aUDP[i]='5980';; # remoteit@.service service listens on random high UDP port
			#69) RPi.GPIO
			70) aCOMMANDS[i]='gpio -v | grep '\''gpio version'\';;
			71) aSERVICES[i]='webiopi' aTCP[i]='8002';;
			#72) I2C
			73) aSERVICES[i]='fail2ban';;
			74) aSERVICES[i]='influxdb' aTCP[i]='8086 8088';;
			#75) LASP
			#76) LAMP
			77) aSERVICES[i]='grafana-server' aTCP[i]='3001' aDELAY[i]=30;;
			#78) LESP
			#79) LEMP
			80) aSERVICES[i]='ubooquity' aTCP[i]='2038 2039'; (( $emulation )) && aDELAY[i]=30;;
			#81) LLSP
			#82) LLMP
			83) aSERVICES[i]='apache2' aTCP[i]='80';;
			84) aSERVICES[i]='lighttpd' aTCP[i]='80';;
			85) aSERVICES[i]='nginx' aTCP[i]='80';;
			86) aSERVICES[i]='roon-extension-manager' SYSCALLS+=' add_key keyctl bpf';;
			87) aCOMMANDS[i]='sqlite3 -version';;
			88) aSERVICES[i]='mariadb' aTCP[i]='3306';;
			89) case $DISTRO in
				'bullseye') aSERVICES[i]='php7.4-fpm';;
				'bookworm') aSERVICES[i]='php8.2-fpm';;
				*) aSERVICES[i]='php8.4-fpm';;
			esac;;
			#90 phpMyAdmin
			91) aSERVICES[i]='redis-server' aTCP[i]='6379';;
			92) aCOMMANDS[i]='certbot --version';;
			93) aSERVICES[i]='pihole-FTL' aUDP[i]='53';;
			94) aSERVICES[i]='proftpd' aTCP[i]='21';;
			95) aSERVICES[i]='vsftpd' aTCP[i]='21';;
			96) aSERVICES[i]='smbd' aTCP[i]='139 445';;
			97) aCOMMANDS[i]='openvpn --version';; # aSERVICES[i]='openvpn' aUDP[i]='1194' GitHub Actions runners do not support the TUN module
			98) aSERVICES[i]='haproxy' aTCP[i]='80 1338';;
			99) aSERVICES[i]='node_exporter' aTCP[i]='9100';;
			#100) (( $arch < 3 )) && aCOMMANDS[i]='/usr/bin/pijuice_cli32 -V' || aCOMMANDS[i]='/usr/bin/pijuice_cli64 -V'; aSERVICES[i]='pijuice' aTCP[i]='????';; Service does not start without I2C device, not present in container and CLI command always puts you in interactive console
			101) aCOMMANDS[i]='logrotate -v /etc/logrotate.conf';;
			102) aSERVICES[i]='rsyslog';;
			103) aSERVICES[i]='dietpi-ramlog' aCOMMANDS[i]='/boot/dietpi/func/dietpi-ramlog 1 && /boot/dietpi/func/dietpi-ramlog 0 && findmnt -t tmpfs /var/log';;
			104) aSERVICES[i]='dropbear' aTCP[i]='22';;
			105) aSERVICES[i]='ssh' aTCP[i]='22';;
			106) aSERVICES[i]='lidarr' aTCP[i]='8686';;
			107) aSERVICES[i]='rtorrent' aTCP[i]='49164' aUDP[i]='6881';;
			108) (( $arch == 1 )) && aCOMMANDS[i]='/mnt/dietpi_userdata/amiberry/amiberry -h | grep '\''^\$VER: Amiberry '\' || aCOMMANDS[i]='amiberry -h | grep '\''^\$VER: Amiberry '\';;
			109) aSERVICES[i]='nfs-kernel-server' aTCP[i]='2049';;
			110) aCOMMANDS[i]='mount.nfs -V';;
			111) aSERVICES[i]='urbackupsrv' aTCP[i]='55414';;
			112) aCOMMANDS[i]='/mnt/dietpi_userdata/dxx-rebirth/d1x-rebirth_rpigl -h';;
			113) aCOMMANDS[i]='chromium --version'; [[ $DISTRO == 'bullseye' && $RPI == 'true' ]] && (( $arch < 10 )) && aCOMMANDS[i]='chromium-browser --version';;
			114) aCOMMANDS[i]='sudo -u www-data php /var/www/nextcloud/occ status';;
			115) aSERVICES[i]='webmin' aTCP[i]='10000';;
			116) aSERVICES[i]='medusa' aTCP[i]='8081'; (( $emulation )) && aDELAY[i]=30;;
			#117) :;; # ToDo: Implement automated install via /boot/unattended_pivpn.conf
			118) aSERVICES[i]='mopidy' aTCP[i]='6680';;
			119) aCOMMANDS[i]='cava -v';;
			#120) RealVNC
			121) aSERVICES[i]='roonbridge' aUDP[i]='9003';;
			122) aSERVICES[i]='node-red' aTCP[i]='1880'; (( $emulation )) && aDELAY[i]=30;;
			123) aSERVICES[i]='mosquitto' aTCP[i]='1883';;
			124) aSERVICES[i]='networkaudiod';; # aUDP[i]='????';;
			125) aSERVICES[i]='synapse' aTCP[i]='8008';;
			126) aSERVICES[i]='adguardhome' aUDP[i]='53' aTCP[i]='8083'; [[ ${aSERVICES[182]} ]] && aUDP[i]+=' 5335';; # Unbound uses port 5335 if AdGuard Home is installed
			128) aSERVICES[i]='mpd' aTCP[i]='6600';;
			#129) O!MPD
			130) aCOMMANDS[i]='python3 -V';;
			131) (( $arch < 3 || $arch == 11 )) || aSERVICES[i]='blynkserver' aTCP[i]='9443'; (( $arch == 10 || $arch == 2 || $arch == 11 )) || aDELAY[i]=60;;
			132) aSERVICES[i]='aria2' aTCP[i]='6800';; # aTCP[i]+=' 6881-6999';; # Listens on random port
			133) (( $arch < 3 || $arch == 11 )) || aSERVICES[i]='yacy' aTCP[i]='8090'; (( $arch == 10 )) && aDELAY[i]=30; (( $arch == 10 || $arch == 2 || $arch == 11)) || aDELAY[i]=90;;
			134) aCOMMANDS[i]='docker compose version';;
			135) aSERVICES[i]='icecast2' aTCP[i]='8000' aCOMMANDS[i]='darkice -h | grep '\''^DarkIce'\';; # darkice service cannot start in container as is requires audio recording device access
			136) aSERVICES[i]='motioneye' aTCP[i]='8765';;
			137) aCOMMANDS[i]='/opt/mjpg-streamer/mjpg_streamer -v';; # aSERVICES[i]='mjpg-streamer' aTCP[i]='8082' Service does not start without an actual video device
			138) aSERVICES[i]='virtualhere' aTCP[i]='7575';;
			139) aSERVICES[i]='sabnzbd' aTCP[i]='8080'; (( $arch == 10 )) || aDELAY[i]=30;; # ToDo: Solve conflict with Airsonic
			140) aSERVICES[i]='domoticz' aTCP[i]='8424';;
			141) aSERVICES[i]='adsb-setup' aTCP[i]='1099' SYSCALLS+=' add_key keyctl bpf'; (( $emulation )) || aSERVICES[i]+=' adsb-docker';; # Container cannot start in QEMU-emulated container. Else, depending on container startup race condition, the Dozzle port can be 9999 (default) or 1094 (changed by internal setup step). I remains 1094 on subsequent restarts, and other ports join depending on manual init setup selections.
			# MicroK8s: /run/udev and on Bullseye /sys/devices required for snapd update to succeed on first attempt doing a udev trigger; ~@mount + loop devices for snapd snaps=squashfs mounts; /dev/kmsg mount + CAP_SYSLOG: "Error: failed to run Kubelet: failed to create kubelet: open /dev/kmsg: no such file or directory"
			142) aCOMMANDS[i]='/snap/bin/microk8s status' aSERVICES[i]='snapd snap.microk8s.daemon-containerd' aDELAY[i]=30 CAPABILITIES+=',CAP_NET_ADMIN,CAP_MAC_ADMIN,CAP_SYSLOG' SYSCALLS+=' add_key keyctl bpf ~@mount' aOPTIONS+=('--bind-ro=/run/udev' '--bind=/dev/loop-control' '--bind=/dev/loop'{1,2,3,4,5,6,7} '--bind=/dev/kmsg'); [[ $DISTRO == 'bullseye' ]] && aOPTIONS+=('--bind=/sys/devices') ;;
			143) aSERVICES[i]='koel' aTCP[i]='8003'; (( $emulation )) && aDELAY[i]=30;;
			144) (( $arch == 1 )) || aSERVICES[i]='sonarr' aTCP[i]='8989';; # Skip on ARMv6 failing in container with "If you're reading this, the MonoMod.RuntimeDetour selftest failed."
			145) aSERVICES[i]='radarr' aTCP[i]='7878';;
			146) aSERVICES[i]='tautulli' aTCP[i]='8181'; (( $emulation )) && aDELAY[i]=60;;
			147) aSERVICES[i]='jackett' aTCP[i]='9117';;
			148) aSERVICES[i]='mympd' aTCP[i]='1333';;
			149) aSERVICES[i]='nzbget' aTCP[i]='6789';;
			150) aCOMMANDS[i]='mono -V';;
			151) aSERVICES[i]='prowlarr' aTCP[i]='9696';;
			152) aSERVICES[i]='avahi-daemon' aUDP[i]='5353';;
			153) aSERVICES[i]='octoprint' aTCP[i]='5001'; (( $emulation )) && aDELAY[i]=60;;
			154) aSERVICES[i]='roonserver';; # Listens on a variety of different port ranges
			155) aSERVICES[i]='htpc-manager' aTCP[i]='8085'; (( $emulation )) && aDELAY[i]=30;;
			#156) Steam
			157) aSERVICES[i]='home-assistant' aTCP[i]='8123'; (( $emulation )) && aDELAY[i]=900 || aDELAY[i]=60;;
			158) aSERVICES[i]='minio' aTCP[i]='9001 9004';;
			#159) Allo GUI full
			#160) Allo GUI without dependencies
			161) aSERVICES[i]='bdd' aTCP[i]='80 443';;
			162) aCOMMANDS[i]='docker -v' aSERVICES[i]='containerd' CAPABILITIES+=',CAP_NET_ADMIN'; (( $emulation )) || aSERVICES[i]+=' docker';; # QEMU: Docker daemon fails with "iptables: Failed to initialize nft: Protocol not supported" and similar error with iptables-legacy
			163) aSERVICES[i]='gmediarender';; # DLNA => UPnP high range of ports
			164) aSERVICES[i]='nukkit' aUDP[i]='19132'; (( $emulation )) && aDELAY[i]=60;;
			165) aSERVICES[i]='gitea' aTCP[i]='3000';;
			#166) aSERVICES[i]='pi-spc';; Service cannot reasonably start in container as WirinPi's gpio command fails reading /proc/cpuinfo
			167) aSERVICES[i]='raspotify';;
			168) aSERVICES[i]='coturn' aTCP[i]=3478 aUDP[i]=3478;;
			169) aSERVICES[i]='lazylibrarian' aTCP[i]=5299; (( $emulation )) && aDELAY[i]=60;;
			170) aCOMMANDS[i]='unrar -V';;
			171) aSERVICES[i]='frps frpc' aTCP[i]='7000 7400 7500';;
			172) aCOMMANDS[i]='wg' aSERVICES[i]='wg-quick@wg0' aUDP[i]='51820' CAPABILITIES+=',CAP_NET_ADMIN';;
			#173 LXQt: all executables strictly require a Qt session, no help or version output possible
			174) aCOMMANDS[i]='gimp -v';;
			175) aCOMMANDS[i]='xfce4-power-manager -V';;
			177) aSERVICES[i]='forgejo' aTCP[i]='3000';;
			178) aSERVICES[i]='jellyfin' aTCP[i]='8097';;
			179) aSERVICES[i]='komga' aTCP[i]='2037'; (( $emulation )) && aDELAY[i]=300 || aDELAY[i]=30;;
			180) aSERVICES[i]='bazarr' aTCP[i]='6767'; (( $emulation )) && aDELAY[i]=120 || aDELAY[i]=30;;
			181) aSERVICES[i]='papermc' aTCP[i]='25565 25575'; (( $emulation )) && aDELAY[i]=900 || aDELAY[i]=60;;
			182) aSERVICES[i]='unbound' aUDP[i]='53'; [[ ${aSERVICES[126]} ]] && aUDP[i]+=' 5335';; # Uses port 5335 if Pi-hole or AdGuard Home is installed, but those do listen on port 53 instead
			183) aSERVICES[i]='vaultwarden' aTCP[i]='8001';;
			184) aSERVICES[i]='tor' aTCP[i]='80 443 9051';;
			185) aTCP[i]='9002 9442' SYSCALLS+=' add_key keyctl bpf';;
			186) aSERVICES[i]='ipfs' aTCP[i]='5003 8087';;
			187) aSERVICES[i]='cups' aTCP[i]='631';;
			188) aCOMMANDS[i]='go version';;
			189) aCOMMANDS[i]='sudo -u dietpi codium -v';;
			190) aCOMMANDS[i]='beet version';;
			191) aSERVICES[i]='snapserver' aTCP[i]='1704 1780';;
			192) aSERVICES[i]='snapclient';;
			193) aCOMMANDS[i]='k3s -v' aSERVICES[i]='k3s' aOPTIONS+=('--bind=/dev/kmsg') CAPABILITIES+=',CAP_NET_ADMIN,CAP_SYSLOG' SYSCALLS+=' add_key keyctl bpf';; # /dev/kmsg mount + CAP_SYSLOG: "Error: failed to run Kubelet: failed to create kubelet: open /dev/kmsg: no such file or directory" resp. "...: operation not permitted"
			194) aSERVICES[i]='postgresql';;
			195) aCOMMANDS[i]='yt-dlp --version';;
			196) aCOMMANDS[i]='java -version';;
			197) aCOMMANDS[i]='box64 -v';;
			198) aSERVICES[i]='filebrowser' aTCP[i]='8084';;
			199) aSERVICES[i]='spotifyd' aUDP[i]='5353';; # + random high TCP port
			#200) aSERVICES[i]='dietpi-dashboard' aTCP[i]='5252';; "dietpi-dashboard.service: Failed to set up standard input: No such file or directory"; "dietpi-dashboard.service: Failed at step STDIN spawning /opt/dietpi-dashboard/dietpi-dashboard: No such file or directory"
			201) aSERVICES[i]='zerotier-one' aTCP[i]='9993';;
			202) aCOMMANDS[i]='rclone version';;
			203) aSERVICES[i]='readarr' aTCP[i]='8787';;
			204) aSERVICES[i]='navidrome' aTCP[i]='4533';;
			#205 Homer
			206) aSERVICES[i]='openhab' aTCP[i]='8444'; (( $emulation )) && aDELAY[i]=600;;
			#207) Moonlight (CLI), "moonlight" command
			#208) Moonlight (GUI), "moonlight-qt" command
			209) aCOMMANDS[i]='restic version';;
			#210) MediaWiki
			211) aCOMMANDS[i]='hb-service status' aSERVICES[i]='homebridge' aTCP[i]='8581';;
			212) aSERVICES[i]='kavita' aTCP[i]='2036' aDELAY[i]=30;;
			213) aSERVICES[i]='soju' aTCP[i]='6667';;
			*) :;;
		esac
		aINSTALL[i]=1
	done
}
for i in $SOFTWARE
do
	case $i in
		205) Process_Software webserver;;
		27|56|63|64|107|132) Process_Software 89 webserver;;
		38|40|48|54|55|57|59|90|160|210) Process_Software 88 89 webserver;;
		159) Process_Software 36 37 65 88 89 96 121 124 128 129 152 160 163 webserver;;
		47|114|168) Process_Software 88 89 91 webserver;;
		8|33|53|80|131|133|164|179|181|206) Process_Software 196;;
		32|148|119) Process_Software 128;;
		129) Process_Software 88 89 128 webserver;;
		49|165|177) Process_Software 0 17 88;;
		61) Process_Software 60;;
		125) Process_Software 194;;
		86|134|185) Process_Software 162;;
		141) Process_Software 17 130 134 162;;
		166) Process_Software 70;;
		180) (( $arch == 10 || $arch == 3 )) || Process_Software 170;;
		188) Process_Software 17;;
		213) Process_Software 17 188;;
		106|144|145|151|183|203) Process_Software 87;;
		31|37|128|138|163|167|187) Process_Software 152;;
		75) Process_Software 83 87 89;;
		76) Process_Software 83 88 89;;
		78) Process_Software 85 87 89;;
		79) Process_Software 85 88 89;;
		81) Process_Software 84 87 89;;
		82) Process_Software 84 88 89;;
		*) :;;
	esac
	Process_Software "$i"
done

##########################################
# Dependencies
##########################################
apackages=('xz-utils' 'parted' 'fdisk' 'systemd-container')

(( $emulation )) && apackages+=('qemu-user-static')

G_AG_CHECK_INSTALL_PREREQ "${apackages[@]}"

# Register QEMU binfmt configs
(( $emulation )) && G_EXEC systemctl restart systemd-binfmt

##########################################
# Prepare container
##########################################
# Download
G_EXEC curl -sSfO "https://dietpi.com/downloads/images/$image.xz"
G_EXEC xz -d "$image.xz"
G_EXEC truncate -s 8G "$image"

# Loop device
FP_LOOP=$(losetup -f)
G_EXEC losetup -P "$FP_LOOP" "$image"
G_EXEC_OUTPUT=1 G_EXEC e2fsck -fp "${FP_LOOP}p1"
G_EXEC_OUTPUT=1 G_EXEC eval "sfdisk -fN1 '$FP_LOOP' <<< ',+'"
G_EXEC partprobe "$FP_LOOP"
G_EXEC partx -u "$FP_LOOP"
G_EXEC_OUTPUT=1 G_EXEC resize2fs "${FP_LOOP}p1"
G_EXEC_OUTPUT=1 G_EXEC e2fsck -fp "${FP_LOOP}p1"
G_EXEC mkdir rootfs
G_EXEC mount "${FP_LOOP}p1" rootfs

# Enforce target ARM arch in containers with newer host/emulated ARM version
if (( $arch < 3 && $G_HW_ARCH != $arch ))
then
	# shellcheck disable=SC2015
	echo -e "#/bin/dash\n[ \"\$*\" = -m ] && echo $ARCH || /bin/uname \"\$@\"" > rootfs/usr/local/bin/uname && G_EXEC chmod +x rootfs/usr/local/bin/uname || Error_Exit "Failed to generate /usr/local/bin/uname for $ARCH"
fi

# Force RPi on ARM systems if requested
if [[ $RPI == 'true' ]] && (( $arch < 10 ))
then
	case $arch in
		1) model=1;;
		2) model=2;;
		3) model=4;;
		*) Error_Exit "Invalid architecture $ARCH ($arch). This is a bug in this script!";;
	esac
	G_EXEC rm rootfs/etc/.dietpi_hw_model_identifier
	G_EXEC touch rootfs/boot/{bcm-rpi-dummy.dtb,config.txt,cmdline.txt}
	G_EXEC sed --follow-symlinks -i "/# Start DietPi-Software/iG_EXEC sed --follow-symlinks -i -e '/^G_HW_MODEL=/cG_HW_MODEL=$model' -e '/^G_HW_MODEL_NAME=/cG_HW_MODEL_NAME=\"RPi $model ($ARCH)\"' /boot/dietpi/.hw_model" rootfs/boot/dietpi/dietpi-login
	G_EXEC curl -sSfo keyring.deb 'https://archive.raspberrypi.com/debian/pool/main/r/raspberrypi-archive-keyring/raspberrypi-archive-keyring_2025.1+rpt1_all.deb'
	G_EXEC dpkg --root=rootfs -i keyring.deb
	G_EXEC rm keyring.deb
fi

# Install test builds from dietpi.com if requested
if [[ $TEST == 'true' ]]
then
	# shellcheck disable=SC2016
	G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/a\G_EXEC sed --follow-symlinks -i '\''s|dietpi.com/downloads/binaries/$G_DISTRO_NAME/|dietpi.com/downloads/binaries/$G_DISTRO_NAME/testing/|'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login
	# shellcheck disable=SC2016
	G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/a\G_EXEC sed --follow-symlinks -Ei '\''s@G_AGI "?(amiberry|amiberry-lite|domoticz|gmediarender|gzdoom|shairport-sync\\$airplay2|squeezelite|unbound|vaultwarden|ympd)"?@Download_Install "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/\\1""_$G_HW_ARCH_NAME.deb"@'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login
	G_CONFIG_INJECT 'SOFTWARE_DIETPI_DASHBOARD_VERSION=' 'SOFTWARE_DIETPI_DASHBOARD_VERSION=Nightly' rootfs/boot/dietpi.txt
fi

# Workaround invalid TERM on login
# shellcheck disable=SC2016
G_EXEC eval 'echo '\''infocmp "$TERM" > /dev/null 2>&1 || { echo "[ INFO ] Unsupported TERM=\"$TERM\", switching to TERM=\"dumb\""; export TERM=dumb; }'\'' > rootfs/etc/bashrc.d/00-dietpi-ci.sh'

# Enable automated setup
G_CONFIG_INJECT 'AUTO_SETUP_AUTOMATED=' 'AUTO_SETUP_AUTOMATED=1' rootfs/boot/dietpi.txt

# Workaround for failing systemd services in emulated container: https://gitlab.com/qemu-project/qemu/-/issues/1962, https://github.com/systemd/systemd/issues/31219
if (( $emulation ))
then
	for i in rootfs/lib/systemd/system/*.service
	do
		[[ -f $i ]] || continue
		grep -Eq '^(Load|Import)Credential=' "$i" || continue
		G_EXEC mkdir "${i/lib/etc}.d"
		if [[ $DISTRO == 'bullseye' || $DISTRO == 'bookworm' ]]
		then
			G_EXEC eval "echo -e '[Service]\nLoadCredential=' > \"${i/lib/etc}.d/dietpi-no-credentials.conf\""
		else
			G_EXEC eval "echo -e '[Service]\nImportCredential=' > \"${i/lib/etc}.d/dietpi-no-credentials.conf\""
		fi
	done
fi

# Do not attempt to change kernel parameters via sysctl, but do dry runs. Those fail in case of invalid syntax or settings which do not exist, but do not fail on missing container capabilities.
G_EXEC eval 'echo -e '\''#!/bin/dash\n/sbin/sysctl --dry-run "$@"'\'' > rootfs/usr/local/bin/sysctl'
G_EXEC chmod +x rootfs/usr/local/bin/sysctl

# ARMv6/7 Trixie: Workaround failing chpasswd, which tries to access /proc/sys/vm/mmap_min_addr, but fails as of AppArmor on the host
if (( $arch < 3 && $dist > 7 )) && systemctl -q is-active apparmor
then
	G_EXEC eval 'echo '\''/proc/sys/vm/mmap_min_addr r,'\'' > /etc/apparmor.d/local/unix-chkpwd'
	G_EXEC_OUTPUT=1 G_EXEC apparmor_parser -r /etc/apparmor.d/unix-chkpwd
fi

# Transmission: Workaround for transmission-daemon timing out with container host AppArmor throwing: apparmor="ALLOWED" operation="sendmsg" class="file" info="Failed name lookup - disconnected path" error=-13 profile="transmission-daemon" name="run/systemd/notify"
if (( ${aINSTALL[44]} )) && (( $dist > 7 )) && systemctl -q is-active apparmor
then
	G_EXEC sed --follow-symlinks -i '/^profile transmission-daemon/s/flags=(complain)/flags=(complain,attach_disconnected)/' /etc/apparmor.d/transmission
	G_EXEC_OUTPUT=1 G_EXEC apparmor_parser -r /etc/apparmor.d/transmission
fi

# rsyslog: Workaround for rsyslogd timing out with container host AppArmor throwing: apparmor="DENIED" operation="sendmsg" class="file" info="Failed name lookup - disconnected path" error=-13 profile="rsyslogd" name="run/systemd/journal/dev-log"
if (( ${aINSTALL[102]} )) && (( $dist > 7 )) && systemctl -q is-active apparmor
then
	G_EXEC sed --follow-symlinks -i '/^profile rsyslogd/s/{$/flags=(attach_disconnected) {/' /etc/apparmor.d/usr.sbin.rsyslogd
	G_EXEC_OUTPUT=1 G_EXEC apparmor_parser -r /etc/apparmor.d/usr.sbin.rsyslogd
fi

# Workaround for failing IPv4 network connectivity check as GitHub Actions runners do not receive external ICMP echo replies.
G_CONFIG_INJECT 'CONFIG_CHECK_CONNECTION_IP=' 'CONFIG_CHECK_CONNECTION_IP=127.0.0.1' rootfs/boot/dietpi.txt

# Apply Git branch
G_CONFIG_INJECT 'DEV_GITBRANCH=' "DEV_GITBRANCH=$G_GITBRANCH" rootfs/boot/dietpi.txt
G_CONFIG_INJECT 'DEV_GITOWNER=' "DEV_GITOWNER=$G_GITOWNER" rootfs/boot/dietpi.txt

# Avoid DietPi-Survey uploads to not mess with the statistics
G_EXEC rm rootfs/root/.ssh/known_hosts

# Apply software IDs to install
for i in $SOFTWARE; do G_CONFIG_INJECT "AUTO_SETUP_INSTALL_SOFTWARE_ID=$i" "AUTO_SETUP_INSTALL_SOFTWARE_ID=$i" rootfs/boot/dietpi.txt; done

# PaperMC: Enable unattended install
if (( ${aINSTALL[181]} ))
then
	G_EXEC mkdir -p rootfs/mnt/dietpi_userdata/papermc/plugins
	G_EXEC eval 'echo '\''eula=true'\'' > rootfs/mnt/dietpi_userdata/papermc/eula.txt'
	G_EXEC touch rootfs/mnt/dietpi_userdata/papermc/plugins/Geyser-Spigot.jar
fi

# Workarounds for QEMU-emulated RISC-V and 32-bit ARM containers
if (( ( $arch < 3 || $arch == 11 ) && $emulation ))
then
	# Failing services as PrivateUsers=true leads to "Failed to set up user namespacing", and AmbientCapabilities to "Failed to apply ambient capabilities (before UID change): Operation not permitted"
	G_EXEC mkdir rootfs/etc/systemd/system/{redis-server,raspotify,navidrome,homebridge}.service.d
	G_EXEC eval 'echo -e '\''[Service]\nPrivateUsers=0'\'' > rootfs/etc/systemd/system/redis-server.service.d/dietpi-container.conf'
	G_EXEC eval 'echo -e '\''[Service]\nPrivateUsers=0'\'' > rootfs/etc/systemd/system/raspotify.service.d/dietpi-container.conf'
	G_EXEC eval 'echo -e '\''[Service]\nPrivateUsers=0'\'' > rootfs/etc/systemd/system/navidrome.service.d/dietpi-container.conf'
	G_EXEC eval 'echo -e '\''[Service]\nAmbientCapabilities='\'' > rootfs/etc/systemd/system/homebridge.service.d/dietpi-container.conf'

	# Failing 32-bit ARM Rust builds on ext4 in QEMU emulated container on 64-bit host: https://github.com/rust-lang/cargo/issues/9545
	if (( $arch < 3 ))
	then
		G_EXEC eval 'echo -e '\''tmpfs /mnt/dietpi_userdata tmpfs size=3G,noatime,lazytime\ntmpfs /root tmpfs size=3G,noatime,lazytime'\'' >> rootfs/etc/fstab'
		cat << '_EOF_' > rootfs/boot/Automation_Custom_PreScript.sh
#!/bin/dash -e
findmnt /mnt/dietpi_userdata > /dev/null 2>&1 || exit 0
umount /mnt/dietpi_userdata
mkdir /mnt/dietpi_userdata_bak
mv /mnt/dietpi_userdata/* /mnt/dietpi_userdata_bak/
mount /mnt/dietpi_userdata
mv /mnt/dietpi_userdata_bak/* /mnt/dietpi_userdata/
rm -R /mnt/dietpi_userdata_bak
_EOF_
	fi
fi

# ARMv6: Workaround for ARMv7 Rust toolchain selected in containers with newer host/emulated ARM version
(( $arch == 1 )) && G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/a\sed -i '\''s/--profile minimal .*$/--profile minimal --default-host arm-unknown-linux-gnueabihf/'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login

# ARMv6: Workaround for hanging Rust tools chain on ARMv8 host: https://github.com/MichaIng/DietPi/issues/6306#issuecomment-1515303702
(( $arch == 1 && $G_HW_ARCH == 3 )) && G_EXEC sysctl -w 'abi.cp15_barrier=2'

# WiFi Hotspot
if (( ${aINSTALL[60]} ))
then
	# Create dummy network config for sed to succeed
	G_EXEC mkdir -p rootfs/etc/network
	G_EXEC eval '>> rootfs/etc/network/interfaces'
	# Replace dedicated hotspot interface with default route interface, for the DHCP server and in case Tor have a valid interface and IP to listen on
	G_EXEC sed --follow-symlinks -i "/# Start DietPi-Software/i\sed -i '/INTERFACESv4/s/\$wifi_iface/$(G_GET_NET iface)/' /boot/dietpi/dietpi-software" rootfs/boot/dietpi/dietpi-login
	G_EXEC sed --follow-symlinks -i "/# Start DietPi-Software/i\sed -i '/192\.168\.42\.10/! s/192\.168\.42\.1/$(G_GET_NET ip)/' /boot/dietpi/dietpi-software" rootfs/boot/dietpi/dietpi-login
	G_EXEC sed --follow-symlinks -i "/# Start DietPi-Software/i\sed -i 's/192\.168\.42\./$(G_GET_NET ip | sed 's/[0-9]*$//')/g' /boot/dietpi/dietpi-software" rootfs/boot/dietpi/dietpi-login
fi

# Workaround for Apache2 on emulated RISC-V system
if (( ${aINSTALL[83]} )) && (( $emulation && $arch == 11 ))
then
	G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/i\sed -i '\''/^DocumentRoot/a\Mutex posixsem'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login
fi

# Workaround for Readarr/Kavita explicitly calling uname without shell, breaking our ARM workaround
if (( ${aINSTALL[203]} )) || (( ${aINSTALL[212]} )) && [[ -f 'rootfs/usr/local/bin/uname' ]]
then
	G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/i\sed -i '\''/# Custom 1st run script/i\\rm /usr/local/bin/uname'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login
fi

# Workaround for Snapcast Client, using file output where no ALSA device is available
# shellcheck disable=SC2016
(( ${aINSTALL[192]} )) && G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/i\sed -i '\''s/-p \$snapcast_server_port/-p \$snapcast_server_port --player file/'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login

# ADS-B Feeder/Portainer/K3s
if (( ${aINSTALL[141]} )) || (( ${aINSTALL[185]} )) || (( ${aINSTALL[193]} ))
then
	# Unmount R/O /proc/sys created by systemd-nspawn: "failed to disable IPv6 on container's interface eth0" resp. "open /proc/sys/foo/bar: read-only file system"
	# - systemd-journald restart fixes missing "journalctl -e/-u" outputs
	G_EXEC eval 'cat << '\''_EOF_'\'' > rootfs/var/lib/dietpi/postboot.d/container.sh
#!/bin/dash
umount -l /proc/sys
systemctl restart systemd-journald
_EOF_'
fi

# MicroK8s
if (( ${aINSTALL[142]} ))
then
	# Unmount R/O /proc/sys created by systemd-nspawn: "open /proc/sys/...: read-only file system"
	# - systemd-journald restart fixes missing "journalctl -e/-u" outputs
	# Mount securityfs to enable AppArmor access, which also requires CAP_MAC_ADMIN
	G_EXEC eval 'cat << '\''_EOF_'\'' > rootfs/var/lib/dietpi/postboot.d/container.sh
#!/bin/dash
umount -l /proc/sys
systemctl restart systemd-journald
mount -t securityfs securityfs /sys/kernel/security
_EOF_'
	# apparmor="DENIED" operation="sendmsg" class="net" profile="/snap/snapd/24792/usr/lib/snapd/snap-confine" pid=218663 comm="snap-confine" family="unix" sock_type="stream" protocol=0 requested_mask="send" denied_mask="send"
	G_EXEC mkdir -p /var/lib/snapd/apparmor/snap-confine.internal
	G_EXEC eval 'echo '\''include <abstractions/base>'\'' > /var/lib/snapd/apparmor/snap-confine.internal/net'
fi

# Check for service status, ports and commands
# shellcheck disable=SC2016
# - Start all services
G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/a\sed -i '\''/# Custom 1st run script/a\\for i in "${aSTART_SERVICES[@]}"; do G_EXEC_NOHALT=1 G_EXEC systemctl start "$i"; done'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login
delay=10
for i in "${aDELAY[@]}"; do (( $i > $delay )) && delay=$i; done
G_EXEC eval "echo -e '#!/bin/dash\nexit_code=0; /boot/dietpi/dietpi-services start || exit_code=1; echo Waiting $delay seconds for service starts; sleep $delay' > rootfs/boot/Automation_Custom_Script.sh"
# - Loop through software IDs to test
printf '%s\n' "${!aSERVICES[@]}" "${!aTCP[@]}" "${!aUDP[@]}" "${!aCOMMANDS[@]}" | sort -u | while read -r i
do
	[[ ${aSERVICES[i]}${aTCP[i]}${aUDP[i]}${aCOMMANDS[i]} ]] || continue

	# Check whether ID really got installed, to skip software unsupported on hardware or distro
	cat << _EOF_ >> rootfs/boot/Automation_Custom_Script.sh
if grep -q '^aSOFTWARE_INSTALL_STATE\[$i\]=2$' /boot/dietpi/.installed
then
_EOF_
	# Check service status
	[[ ${aSERVICES[i]} ]] && for j in ${aSERVICES[i]}; do cat << _EOF_ >> rootfs/boot/Automation_Custom_Script.sh
echo -n '\e[33m[ INFO ] Checking $j service status:\e[0m '
systemctl is-active '$j' || { journalctl -u '$j'; exit_code=1; }
_EOF_
	done
	# Check TCP ports
	[[ ${aTCP[i]} ]] && for j in ${aTCP[i]}; do cat << _EOF_ >> rootfs/boot/Automation_Custom_Script.sh
echo '\e[33m[ INFO ] Checking TCP port $j status:\e[0m'
ss -tlpn | grep ':${j}[[:blank:]]' 2> /dev/null || { echo '\e[31m[FAILED] TCP port ${j} not active\e[0m'; exit_code=1; }
_EOF_
	done
	# Check UDP ports
	[[ ${aUDP[i]} ]] && for j in ${aUDP[i]}; do cat << _EOF_ >> rootfs/boot/Automation_Custom_Script.sh
echo '\e[33m[ INFO ] Checking UDP port $j status:\e[0m'
ss -ulpn | grep ':${j}[[:blank:]]' 2> /dev/null || { echo '\e[31m[FAILED] UDP port ${j} not active\e[0m'; exit_code=1; }
_EOF_
	done
	# Check commands
	[[ ${aCOMMANDS[i]} ]] && cat << _EOF_ >> rootfs/boot/Automation_Custom_Script.sh
echo '\e[33m[ INFO ] Testing command "${aCOMMANDS[i]}":\e[0m'
${aCOMMANDS[i]} || { echo '\e[31m[FAILED] Command returned error code\e[0m'; exit_code=1; }
_EOF_
	G_EXEC eval 'echo fi >> rootfs/boot/Automation_Custom_Script.sh'
done

# Success flag and shutdown
# shellcheck disable=SC2016
G_EXEC eval 'echo '\''[ $exit_code = 0 ] && > /success || { journalctl -n 50; ss -tulpn; df -h; free -h; }; systemctl start poweroff.target; exit $?'\'' >> rootfs/boot/Automation_Custom_Script.sh'

# Shutdown as well on failures before the custom script is executed
G_EXEC sed --follow-symlinks -i 's|Prompt_on_Failure$|{ journalctl -n 50; ss -tulpn; df -h; free -h; systemctl start poweroff.target; exit 1; }|' rootfs/boot/dietpi/dietpi-login

##########################################
# Boot container
##########################################
[[ $CAPABILITIES ]] && aOPTIONS+=("--capability=${CAPABILITIES#,}")
[[ $SYSCALLS ]] && aOPTIONS+=("--system-call-filter=${SYSCALLS# }")
G_DIETPI-NOTIFY 2 "Running container with: systemd-nspawn ${aOPTIONS[*]} -bD rootfs"
systemd-nspawn "${aOPTIONS[@]}" -bD rootfs
# shellcheck disable=SC2015
[[ -f 'rootfs/success' ]] && exit 0 || { journalctl -n 25; ss -tlpn; df -h; free -h; exit 1; }
}
