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
[[ $SOFTWARE =~ ^[[:alnum:]\ ._-]+$ ]] || Error_Exit "Invalid software list \"$SOFTWARE\" passed"
# Normalise software IDs like DietPi-Software does: Lower case, remove all non-alphanumeric characters
software=
for i in $SOFTWARE
do
	i=${i,,}
	software+=" ${i//[^[:alnum:]]/}"
done
SOFTWARE=${software# }
[[ $RPI =~ ^('false'|'true')$ ]] || Error_Exit "Invalid RPi flag \"$RPI\" passed"
[[ $TEST =~ ^('false'|'true')$ ]] || Error_Exit "Invalid test flag \"$TEST\" passed"

# Emulation support in case of incompatible architecture
emulation=0
(( $G_HW_ARCH == $arch || ( $G_HW_ARCH < 10 && $G_HW_ARCH > $arch ) )) || emulation=1

# Allo GUI (non-full/reinstall): Add MariaDB for needed database generation
[[ $SOFTWARE =~ (^| )allogui( |$) ]] && SOFTWARE=$(sed -E 's/(^| )allogui( |$)/\1mariadb allogui\2/g' <<< "$SOFTWARE")
# Removals for QEMU-emulated tests:
# - PostgreSQL and dependants (Synapse): https://gitlab.com/qemu-project/qemu/-/issues/3068
# - WireGuard: "Unable to modify/access interface: Protocol not supported"
# - Docker containers (Roon Extension Manager and Portainer): Docker daemon fails with "iptables: Failed to initialize nft: Protocol not supported" and similar error with iptables-legacy
[[ $arch == 11 && $emulation == 1 && $SOFTWARE =~ (^| )(roonextensionmanager|synapse|wireguard|portainer|postgresql)( |$) ]] && { echo '[ WARN ] Removing Roon Extension Manager, PostgreSQL, WireGuard, Portainer, and Synapse from test installs as they fail in emulated RISC-V containers'; SOFTWARE=$(sed -E 's/(^| )(roonextensionmanager|synapse|wireguard|portainer|postgresql)( |$)/\1\3/g' <<< "$SOFTWARE"); }

##########################################
# Create service and port lists
##########################################
declare -A aINSTALL aSERVICES aTCP aUDP aCOMMANDS aDELAY
CAPABILITIES='' SYSCALLS='' aOPTIONS=()
Process_Software()
{
	local i
	for i in "$@"
	do
		# shellcheck disable=SC2016
		case $i in
			'webserver') [[ $SOFTWARE =~ (^| )(apache|lighttpd|nginx)( |$) ]] || Process_Software apache;;
			opensshclient) aCOMMANDS[$i]='ssh -V';;
			sambaclient) aCOMMANDS[$i]='smbclient -V';;
			foldinghome) aSERVICES[$i]='fahclient' aTCP[$i]='7396';;
			mc) aCOMMANDS[$i]='mc -V';;
			fish) aCOMMANDS[$i]='fish -v';;
			alsa) aCOMMANDS[$i]='aplay -l';;
			x11) aCOMMANDS[$i]='X -version';;
			ffmpeg) aCOMMANDS[$i]='ffmpeg -version';;
			javajdk) aCOMMANDS[$i]='javac -version';;
			nodejs) aCOMMANDS[$i]='node -v';;
			amiberrylite) aCOMMANDS[$i]='amiberry-lite -h | grep '\''^\$VER: Amiberry-Lite '\';;
			gzdoom) aCOMMANDS[$i]='gzdoom -norun | grep '\''^GZDoom version '\';;
			rustdeskserver) aSERVICES[$i]='rustdesksignal rustdeskrelay' aTCP[$i]='21115 21116 21117 21118 21119' aUDP[$i]='21116';;
			rustdeskclient) aCOMMANDS[$i]='rustdesk --version';;
			#microblogpub) aSERVICES[$i]='microblog-pub' aTCP[$i]='8007';; Service enters a CPU-intense internal error loop until it has been configured interactively via "microblog-pub configure", hence it is not enabled and started anymore after install but instead as part of "microblog-pub configure"
			git) aCOMMANDS[$i]='git -v';;
			lxde) aCOMMANDS[$i]='lxsession -h';;
			mate) aCOMMANDS[$i]='mate-session -h';;
			xfce) aCOMMANDS[$i]='xfce4-session -h';;
			gnustep) aCOMMANDS[$i]='gnustep-tests';;
			#tasmoadmin)
			tigervncserver) aSERVICES[$i]='vncserver' aTCP[$i]='5901';;
			xrdp) aSERVICES[$i]='xrdp' aTCP[$i]='3389';;
			nomachine) aSERVICES[$i]='nxserver' aTCP[$i]='4000';;
			kodi) [[ $arch == 1 && $DISTRO == 'bookworm' ]] || aCOMMANDS[$i]='kodi -v';; # Bookworm RPi repo "kodi" calls fgconsole and chvt which both fails in non-interactive container: "Couldn't get a file descriptor referring to the console."
			ympd) aSERVICES[$i]='ympd' aTCP[$i]='1337';;
			airsonicadvanced) (( $emulation )) || aSERVICES[$i]='airsonic' aTCP[$i]='8080' aDELAY[$i]=60;; # Fails in QEMU-emulated containers, probably due to missing device access
			phpcomposer) aCOMMANDS[$i]='COMPOSER_ALLOW_SUPERUSER=1 composer -n -V';;
			lyrionmusicserver) aSERVICES[$i]='lyrionmusicserver' aTCP[$i]='9000';;
			squeezelite) aSERVICES[$i]='squeezelite';; # Service listens on random high UDP port
			shairportsync) aSERVICES[$i]='shairport-sync' aTCP[$i]='5000';; # AirPlay 2 would be TCP port 7000
			freshrss) aCOMMANDS[$i]='/opt/FreshRSS/cli/user-info.php';;
			readymedia) aSERVICES[$i]='minidlna' aTCP[$i]='8200';;
			#ampache)
			emby) aSERVICES[$i]='emby-server' aTCP[$i]='8096';;
			plexmediaserver) aSERVICES[$i]='plexmediaserver' aTCP[$i]='32400';;
			mumbleserver) aSERVICES[$i]='mumble-server' aTCP[$i]='64738';;
			transmission) aSERVICES[$i]='transmission-daemon' aTCP[$i]='9091 51413' aUDP[$i]='51413';;
			deluge) aSERVICES[$i]='deluged deluge-web' aTCP[$i]='8112 58846 6882';;
			qbittorrent) aSERVICES[$i]='qbittorrent' aTCP[$i]='1340 6881';;
			owncloudinfinitescale) aSERVICES[$i]='ocis' aTCP[$i]='9200';;
			gogs) aSERVICES[$i]='gogs' aTCP[$i]='3000';;
			syncthing) aSERVICES[$i]='syncthing' aTCP[$i]='8384';;
			opentyrian) aCOMMANDS[$i]='/usr/games/opentyrian/opentyrian -h';;
			cuberite) aSERVICES[$i]='cuberite' aTCP[$i]='1339' aDELAY[$i]=60;;
			mineos) aSERVICES[$i]='mineos' aTCP[$i]='8443';;
			#phpbb)
			#wordpress)
			#singlefilephpgallery)
			#baikal) Baïkal
			tailscale) aCOMMANDS[$i]='tailscale version';; # aSERVICES[$i]='tailscaled' aUDP[$i]='41641' GitHub Actions runners do not support the TUN module
			wifihotspot) aCOMMANDS[$i]='iptables -V' aSERVICES[$i]='isc-dhcp-server' aUDP[$i]='67';; # aSERVICES[$i]='hostapd' fails without actual WiFi interface
			torhotspot) aSERVICES[$i]='tor' aTCP[$i]='9040' aUDP[$i]='53';;
			box86) aCOMMANDS[$i]='box86 -v';;
			#linuxdash)
			#phpsysinfo)
			netdata) aSERVICES[$i]='netdata' aTCP[$i]='19999';;
			rpimonitor) aSERVICES[$i]='rpimonitor' aTCP[$i]='8888';;
			firefox) aCOMMANDS[$i]='firefox-esr -v';;
			remoteit) aSERVICES[$i]='schannel' aUDP[$i]='5980';; # remoteit@.service service listens on random high UDP port
			#python3rpigpio)
			wiringpi) aCOMMANDS[$i]='gpio -v | grep '\''gpio version'\';;
			webiopi) aSERVICES[$i]='webiopi' aTCP[$i]='8002';;
			#i2c)
			fail2ban) aSERVICES[$i]='fail2ban';;
			influxdb) aSERVICES[$i]='influxdb' aTCP[$i]='8086 8088';;
			#lasp)
			#lamp)
			grafana) aSERVICES[$i]='grafana-server' aTCP[$i]='3001' aDELAY[$i]=30;;
			#lesp)
			#lemp)
			ubooquity) aSERVICES[$i]='ubooquity' aTCP[$i]='2038 2039'; (( $emulation )) && aDELAY[$i]=60;;
			#llsp)
			#llmp)
			apache) aSERVICES[$i]='apache2' aTCP[$i]='80';;
			lighttpd) aSERVICES[$i]='lighttpd' aTCP[$i]='80';;
			nginx) aSERVICES[$i]='nginx' aTCP[$i]='80';;
			roonextensionmanager) aSERVICES[$i]='roon-extension-manager' SYSCALLS+=' add_key keyctl bpf';;
			sqlite) aCOMMANDS[$i]='sqlite3 -version';;
			mariadb) aSERVICES[$i]='mariadb' aTCP[$i]='3306';;
			php) case $DISTRO in
				'bookworm') aSERVICES[$i]='php8.2-fpm';;
				*) aSERVICES[$i]='php8.4-fpm';;
			esac;;
			#phpmyadmin)
			redis) aSERVICES[$i]='redis-server' aTCP[$i]='6379';;
			certbot) aCOMMANDS[$i]='certbot --version';;
			pihole) aSERVICES[$i]='pihole-FTL' aUDP[$i]='53';;
			proftpd) aSERVICES[$i]='proftpd' aTCP[$i]='21';;
			vsftpd) aSERVICES[$i]='vsftpd' aTCP[$i]='21';;
			sambaserver) aSERVICES[$i]='smbd' aTCP[$i]='139 445' aUDP[$i]='137 138';;
			openvpn) aCOMMANDS[$i]='openvpn --version';; # aSERVICES[$i]='openvpn' aUDP[$i]='1194' GitHub Actions runners do not support the TUN module
			haproxy) aSERVICES[$i]='haproxy' aTCP[$i]='80 1338';;
			prometheusnodeexporter) aSERVICES[$i]='node_exporter' aTCP[$i]='9100';;
			#pijuice) (( $arch < 3 )) && aCOMMANDS[$i]='/usr/bin/pijuice_cli32 -V' || aCOMMANDS[$i]='/usr/bin/pijuice_cli64 -V'; aSERVICES[$i]='pijuice' aTCP[$i]='????';; Service does not start without I2C device, not present in container and CLI command always puts you in interactive console
			logrotate) aCOMMANDS[$i]='logrotate -v /etc/logrotate.conf';;
			rsyslog) aSERVICES[$i]='rsyslog';;
			dietpiramlog) aSERVICES[$i]='dietpi-ramlog' aCOMMANDS[$i]='/boot/dietpi/func/dietpi-ramlog 1 && /boot/dietpi/func/dietpi-ramlog 0 && findmnt -t tmpfs /var/log';;
			dropbear) aSERVICES[$i]='dropbear' aTCP[$i]='22';;
			opensshserver) aSERVICES[$i]='ssh' aTCP[$i]='22';;
			lidarr) aSERVICES[$i]='lidarr' aTCP[$i]='8686';;
			rtorrent) aSERVICES[$i]='rtorrent' aTCP[$i]='49164' aUDP[$i]='6881';;
			amiberry) (( $arch == 1 )) && aCOMMANDS[$i]='/mnt/dietpi_userdata/amiberry/amiberry -h | grep '\''^\$VER: Amiberry '\' || aCOMMANDS[$i]='amiberry -h | grep '\''^\$VER: Amiberry '\';;
			nfsserver) aSERVICES[$i]='nfs-kernel-server' aTCP[$i]='2049';;
			nfsclient) aCOMMANDS[$i]='mount.nfs -V';;
			urbackupserver) aSERVICES[$i]='urbackupsrv' aTCP[$i]='55414';;
			dxxrebirth) aCOMMANDS[$i]='/mnt/dietpi_userdata/dxx-rebirth/d1x-rebirth_rpigl -h';;
			chromium) aCOMMANDS[$i]='chromium --version';;
			nextcloud) aCOMMANDS[$i]='sudo -u www-data php /var/www/nextcloud/occ status';;
			webmin) aSERVICES[$i]='webmin' aTCP[$i]='10000';;
			medusa) aSERVICES[$i]='medusa' aTCP[$i]='8081'; (( $emulation )) && aDELAY[$i]=30;;
			#pivpn) :;; # ToDo: Implement automated install via /boot/unattended_pivpn.conf
			mopidy) aSERVICES[$i]='mopidy' aTCP[$i]='6680';;
			cava) aCOMMANDS[$i]='cava -v';;
			#realvncserver)
			roonbridge) aSERVICES[$i]='roonbridge' aUDP[$i]='9003';;
			nodered) aSERVICES[$i]='node-red' aTCP[$i]='1880'; (( $emulation )) && aDELAY[$i]=30;;
			mosquitto) aSERVICES[$i]='mosquitto' aTCP[$i]='1883';;
			naadaemon) aSERVICES[$i]='networkaudiod' aTCP[$i]='43210' aUDP[$i]='43210';;
			synapse) aSERVICES[$i]='synapse' aTCP[$i]='8008';;
			adguardhome) aSERVICES[$i]='adguardhome' aUDP[$i]='53' aTCP[$i]='8083'; [[ ${aSERVICES[182]} ]] && aUDP[182]='5335' aTCP[182]='5335';; # Unbound uses port 5335 if AdGuard Home is installed
			birdnetgo) aSERVICES[$i]='birdnet' aTCP[$i]='8127';;
			mpd) aSERVICES[$i]='mpd' aTCP[$i]='6600';;
			#ompd)
			python3) aCOMMANDS[$i]='python3 -V';;
			blynkserver) aSERVICES[$i]='blynkserver' aTCP[$i]='9443'; (( $emulation )) && aDELAY[$i]=120;;
			aria2) aSERVICES[$i]='aria2' aTCP[$i]='6800';; # aTCP[$i]+=' 6881-6999';; # Listens on random port
			yacy) aSERVICES[$i]='yacy' aTCP[$i]='8090' aDELAY[$i]=30; (( $emulation )) && aDELAY[$i]=120;;
			dockercompose) aCOMMANDS[$i]='docker compose version';;
			icecast) aSERVICES[$i]='icecast2' aTCP[$i]='8000' aCOMMANDS[$i]='darkice -h | grep '\''^DarkIce'\';; # darkice service cannot start on GitHub runner as it requires a hardware capture device, and those runners do not provide the dummy audio kernel module
			motioneye) aSERVICES[$i]='motioneye' aTCP[$i]='8765';;
			mjpgstreamer) aCOMMANDS[$i]='/opt/mjpg-streamer/mjpg_streamer -v';; # aSERVICES[$i]='mjpg-streamer' aTCP[$i]='8082' Service does not start without an actual video device
			virtualhere) aSERVICES[$i]='virtualhere' aTCP[$i]='7575';;
			sabnzbd) aSERVICES[$i]='sabnzbd' aTCP[$i]='8080'; (( $arch == 10 )) || aDELAY[$i]=30;; # ToDo: Solve conflict with Airsonic
			domoticz) aSERVICES[$i]='domoticz' aTCP[$i]='8424';;
			adsbfeeder) aSERVICES[$i]='adsb-setup' aTCP[$i]='1099' SYSCALLS+=' add_key keyctl bpf'; (( $emulation )) || aSERVICES[$i]+=' adsb-docker';; # Container cannot start in QEMU-emulated container. Else, depending on container startup race condition, the Dozzle port can be 9999 (default) or 1094 (changed by internal setup step). I remains 1094 on subsequent restarts, and other ports join depending on manual init setup selections.
			# MicroK8s: /run/udev required for snapd update to succeed on first attempt doing a udev trigger; ~@mount + loop devices for snapd snaps=squashfs mounts; /dev/kmsg mount + CAP_SYSLOG: "Error: failed to run Kubelet: failed to create kubelet: open /dev/kmsg: no such file or directory"
			microk8s) aCOMMANDS[$i]='/snap/bin/microk8s status' aSERVICES[$i]='snapd snap.microk8s.daemon-containerd' aDELAY[$i]=30 CAPABILITIES+=',CAP_NET_ADMIN,CAP_MAC_ADMIN,CAP_SYSLOG' SYSCALLS+=' add_key keyctl bpf ~@mount' aOPTIONS+=('--bind-ro=/run/udev' '--bind=/dev/loop-control' '--bind=/dev/loop'{1,2,3,4,5,6,7} '--bind=/dev/kmsg');;
			koel) aSERVICES[$i]='koel' aTCP[$i]='8003'; (( $emulation )) && aDELAY[$i]=30;;
			sonarr) (( $arch == 1 )) || aSERVICES[$i]='sonarr' aTCP[$i]='8989';; # Skip on ARMv6 failing in container with "If you're reading this, the MonoMod.RuntimeDetour selftest failed."
			radarr) aSERVICES[$i]='radarr' aTCP[$i]='7878';;
			tautulli) aSERVICES[$i]='tautulli' aTCP[$i]='8181'; (( $emulation )) && aDELAY[$i]=60;;
			jackett) aSERVICES[$i]='jackett' aTCP[$i]='9117';;
			mympd) aSERVICES[$i]='mympd' aTCP[$i]='1333';;
			nzbget) aSERVICES[$i]='nzbget' aTCP[$i]='6789';;
			mono) aCOMMANDS[$i]='mono -V';;
			prowlarr) aSERVICES[$i]='prowlarr' aTCP[$i]='9696';;
			avahidaemon) aSERVICES[$i]='avahi-daemon' aUDP[$i]='5353';;
			octoprint) aSERVICES[$i]='octoprint' aTCP[$i]='5001'; (( $emulation )) && aDELAY[$i]=60;;
			roonserver) aSERVICES[$i]='roonserver';; # Listens on a variety of different port ranges
			htpcmanager) aSERVICES[$i]='htpc-manager' aTCP[$i]='8085'; (( $emulation )) && aDELAY[$i]=30;;
			#steam)
			homeassistant) aSERVICES[$i]='home-assistant' aTCP[$i]='8123'; (( $emulation )) && aDELAY[$i]=900 || aDELAY[$i]=60;;
			minio) aSERVICES[$i]='minio' aTCP[$i]='9001 9004' aCOMMANDS[$i]='bash -ic '\''mc mb local/test'\';;
			#alloguifull)
			#allogui)
			fuguhub) aSERVICES[$i]='bdd' aTCP[$i]='80 443';;
			docker) aCOMMANDS[$i]='docker -v' aSERVICES[$i]='containerd' CAPABILITIES+=',CAP_NET_ADMIN'; (( $emulation )) || aSERVICES[$i]+=' docker';; # QEMU: Docker daemon fails with "iptables: Failed to initialize nft: Protocol not supported" and similar error with iptables-legacy
			gmediarender) aSERVICES[$i]='gmediarender';; # DLNA => UPnP high range of ports
			nukkit) aSERVICES[$i]='nukkit' aUDP[$i]='19132'; (( $emulation )) && aDELAY[$i]=60;;
			gitea) aSERVICES[$i]='gitea' aTCP[$i]='3000';;
			#audiophonicspispc) aSERVICES[$i]='pi-spc';; Service cannot reasonably start in container as WirinPi's gpio command fails reading /proc/cpuinfo
			raspotify) aSERVICES[$i]='raspotify';;
			nextcloudtalk) aSERVICES[$i]='coturn' aTCP[$i]=3478 aUDP[$i]=3478;;
			lazylibrarian) aSERVICES[$i]='lazylibrarian' aTCP[$i]=5299; (( $emulation )) && aDELAY[$i]=60;;
			unrar) aCOMMANDS[$i]='unrar -V';;
			frp) aSERVICES[$i]='frps frpc' aTCP[$i]='7000 7400 7500';;
			wireguard) aCOMMANDS[$i]='wg' aSERVICES[$i]='wg-quick@wg0' aUDP[$i]='51820' CAPABILITIES+=',CAP_NET_ADMIN';;
			#lxqt) LXQt: all executables strictly require a Qt session, no help or version output possible
			gimp) aCOMMANDS[$i]='gimp -v';;
			xfcepowermanager) aCOMMANDS[$i]='xfce4-power-manager -V';;
			uptimekuma) aSERVICES[$i]='uptime-kuma' aTCP[$i]='3002';;
			forgejo) aSERVICES[$i]='forgejo' aTCP[$i]='3000';;
			jellyfin) aSERVICES[$i]='jellyfin' aTCP[$i]='8097';;
			komga) aSERVICES[$i]='komga' aTCP[$i]='2037' aDELAY[$i]=30; (( $emulation )) && aDELAY[$i]=420;;
			bazarr) aSERVICES[$i]='bazarr' aTCP[$i]='6767'; (( $emulation )) && aDELAY[$i]=120 || aDELAY[$i]=30;;
			papermc) aSERVICES[$i]='papermc' aTCP[$i]='25565 25575' aDELAY[$i]=60; (( $emulation )) && aDELAY[$i]=900;;
			unbound) aSERVICES[$i]='unbound' aUDP[$i]='53' aTCP[$i]='53'; [[ ${aSERVICES[126]} ]] && aUDP[$i]='5335' aTCP[$i]='5335';; # Uses port 5335 if Pi-hole or AdGuard Home is installed
			vaultwarden) aSERVICES[$i]='vaultwarden' aTCP[$i]='8001';;
			torrelay) aSERVICES[$i]='tor' aTCP[$i]='80 443 9051';;
			portainer) aTCP[$i]='9002 9442' SYSCALLS+=' add_key keyctl bpf';;
			kubo) aSERVICES[$i]='ipfs' aTCP[$i]='5003 8087';;
			cups) aSERVICES[$i]='cups' aTCP[$i]='631';;
			go) aCOMMANDS[$i]='go version';;
			vscodium) aCOMMANDS[$i]='sudo -u dietpi codium -v';;
			beets) aCOMMANDS[$i]='beet version';;
			snapcastserver) aSERVICES[$i]='snapserver' aTCP[$i]='1704 1780';;
			snapcastclient) aSERVICES[$i]='snapclient';;
			k3s) aCOMMANDS[$i]='k3s -v' aSERVICES[$i]='k3s' aOPTIONS+=('--bind=/dev/kmsg') CAPABILITIES+=',CAP_NET_ADMIN,CAP_SYSLOG' SYSCALLS+=' add_key keyctl bpf';; # /dev/kmsg mount + CAP_SYSLOG: "Error: failed to run Kubelet: failed to create kubelet: open /dev/kmsg: no such file or directory" resp. "...: operation not permitted"
			postgresql) aSERVICES[$i]='postgresql';;
			ytdlp) aCOMMANDS[$i]='yt-dlp --version';;
			javajre) aCOMMANDS[$i]='java -version';;
			box64) aCOMMANDS[$i]='box64 -v';;
			filebrowser) aSERVICES[$i]='filebrowser' aTCP[$i]='8084';;
			spotifyd) aSERVICES[$i]='spotifyd' aUDP[$i]='5353';; # + random high TCP port
			dietpidashboard) aSERVICES[$i]='dietpi-dashboard-frontend dietpi-dashboard-backend' aTCP[$i]='5252 5253';;
			zerotier) aSERVICES[$i]='zerotier-one' aTCP[$i]='9993';;
			rclone) aCOMMANDS[$i]='rclone version';;
			readarr) aSERVICES[$i]='readarr' aTCP[$i]='8787';;
			navidrome) aSERVICES[$i]='navidrome' aTCP[$i]='4533';;
			#homer)
			openhab) aSERVICES[$i]='openhab' aTCP[$i]='8444'; (( $emulation )) && aDELAY[$i]=600;;
			#moonlightcli) Moonlight (CLI), "moonlight" command
			#moonlightgui) Moonlight (GUI), "moonlight-qt" command
			restic) aCOMMANDS[$i]='restic version';;
			#mediawiki)
			homebridge) aCOMMANDS[$i]='hb-service status' aSERVICES[$i]='homebridge' aTCP[$i]='8581';;
			kavita) aSERVICES[$i]='kavita' aTCP[$i]='2036' aDELAY[$i]=30;;
			soju) aSERVICES[$i]='soju' aTCP[$i]='6667';;
			whodb) aSERVICES[$i]='whodb' aTCP[$i]='8091';;
			immich) aSERVICES[$i]='immich' aTCP[$i]='2283';;
			immichmachinelearning) aSERVICES[$i]='immich-ml' aTCP[$i]='3003';;
			uv) aCOMMANDS[$i]='uv --version';;
			prometheus) aSERVICES[$i]='prometheus' aTCP[$i]='9090' aCOMMANDS[$i]='curl -sSf '\''http://127.0.0.1:9090/api/v1/query?query=up'\'' | grep '\''"status":"success"'\';;
			homebox) aSERVICES[$i]='homebox' aTCP[$i]='7745' aCOMMANDS[$i]='curl -sSf '\''http://127.0.0.1:7745/api/v1/status'\'' | grep '\''"health":true'\';;
			scrypted) aSERVICES[$i]='scrypted' aTCP[$i]='10443 11080 10081';; # ports: https (secure), http (insecure), debug
			*) :;;
		esac
		aINSTALL[$i]=1
	done
}
for i in $SOFTWARE
do
	case $i in
		homer) Process_Software webserver;;
		tasmoadmin|singlefilephpgallery|linuxdash|phpsysinfo|rtorrent|aria2) Process_Software php webserver;;
		freshrss|phpbb|wordpress|baikal|phpmyadmin|allogui|mediawiki) Process_Software mariadb php webserver;;
		alloguifull) Process_Software squeezelite shairportsync netdata mariadb php sambaserver roonbridge naadaemon mpd ompd avahidaemon allogui gmediarender webserver;;
		owncloudinfinitescale|nextcloud|nextcloudtalk) Process_Software mariadb php redis webserver;;
		javajdk|ubooquity|yacy|nukkit|komga|papermc|openhab) Process_Software javajre;;
		nodered) Process_Software nodejs;;
		mineos|blynkserver) Process_Software nodejs javajre;;
		ympd|mympd|cava) Process_Software mpd;;
		ompd) Process_Software mariadb php mpd webserver;;
		gogs|gitea|forgejo) Process_Software opensshclient git mariadb;;
		torhotspot) Process_Software wifihotspot;;
		synapse) Process_Software postgresql;;
		roonextensionmanager|dockercompose|portainer) Process_Software docker;;
		adsbfeeder) Process_Software git dockercompose docker;;
		audiophonicspispc) Process_Software wiringpi;;
		bazarr) (( $arch == 10 || $arch == 3 )) || Process_Software unrar;;
		go) Process_Software git;;
		soju) Process_Software git go;;
		vaultwarden) Process_Software sqlite;;
		immich) Process_Software ffmpeg nodejs redis postgresql;;
		virtualhere|cups) Process_Software avahidaemon;;
		lasp) Process_Software apache sqlite php;;
		lamp) Process_Software apache mariadb php;;
		lesp) Process_Software nginx sqlite php;;
		lemp) Process_Software nginx mariadb php;;
		llsp) Process_Software lighttpd sqlite php;;
		llmp) Process_Software lighttpd mariadb php;;
		lxde|mate|xfce|gnustep|lxqt|squeezelite|mopidy|roonbridge|naadaemon|icecast|roonserver|snapcastserver|snapcastclient|spotifyd|navidrome|amiberry|amiberrylite|opentyrian|dxxrebirth|steam|gzdoom|vscodium|chromium|firefox) Process_Software alsa;;
		kodi|shairportsync|mpd|gmediarender|raspotify) Process_Software alsa avahidaemon;;
		airsonicadvanced) Process_Software alsa javajre;;
		ampache) Process_Software alsa mariadb php webserver;;
		*) :;;
	esac
	Process_Software "$i"
done

##########################################
# Dependencies
##########################################
apackages=('xz-utils' 'parted' 'fdisk' 'systemd-container')

if (( $emulation ))
then
	if (( $G_DISTRO > 7 ))
	then
		apackages+=('qemu-user-binfmt')
	else
		apackages+=('qemu-user-static')
	fi
fi

G_AG_CHECK_INSTALL_PREREQ "${apackages[@]}"

# Register QEMU binfmt configs
if (( $emulation ))
then
	# Add credentials flag to allow setuid/setgid flags to function, e.g. used by Koel to add its crontab
	G_EXEC sed --follow-symlinks -i '1s|$|C|' /usr/lib/binfmt.d/qemu-*.conf
	G_EXEC systemctl restart systemd-binfmt
fi

##########################################
# Prepare container
##########################################
# Download
G_EXEC curl -sSfO "https://dietpi.com/downloads/images/$image.xz"
G_EXEC xz -d "$image.xz"
G_EXEC truncate -s 16G "$image"

# Mount as loop device
FP_LOOP=$(losetup -f)
G_EXEC losetup -P "$FP_LOOP" "$image"
G_EXEC_OUTPUT=1 G_EXEC eval "sfdisk -N1 '$FP_LOOP' <<< ',+'"
# - resize2fs: "Please run 'e2fsck -f /dev/loop0p1' first."
# - e2fsck "-p": "need terminal for interactive repairs"
# - sleep: e2fsck: No such file or directory while trying to open /dev/loop0p1
G_SLEEP 0.1
G_EXEC_OUTPUT=1 G_EXEC e2fsck -fp "${FP_LOOP}p1"
G_EXEC_OUTPUT=1 G_EXEC resize2fs "${FP_LOOP}p1"
G_EXEC mkdir rootfs
G_EXEC mount "${FP_LOOP}p1" rootfs

# Enforce target ARM arch in containers with newer host/emulated ARM version
if (( $arch < 3 && $G_HW_ARCH != $arch ))
then
	# shellcheck disable=SC2015
	echo -e "#!/bin/dash\n[ \"\$*\" = '-m' ] && echo '$ARCH' || /bin/uname \"\$@\" | sed -E 's/armv[67]l|aarch64|x86_64|riscv64/$ARCH/g'" > rootfs/usr/local/bin/uname && G_EXEC chmod +x rootfs/usr/local/bin/uname || Error_Exit "Failed to generate /usr/local/bin/uname for $ARCH"
fi

# Force RPi on ARM systems if requested
if [[ $RPI == 'true' ]] && (( $arch < 10 ))
then
	case $arch in
		sambaclient) model=1;;
		foldinghome) model=2;;
		mc) model=4;;
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
	G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/a\G_EXEC sed --follow-symlinks -Ei '\''s@G_AGI "?(amiberry|amiberry-lite|domoticz|gmediarender|gzdoom|haproxy|shairport-sync\\$airplay2|squeezelite|unbound|vaultwarden|ympd)"?@Download_Install "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/\\1""_$G_HW_ARCH_NAME.deb"@'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login
	G_CONFIG_INJECT 'SOFTWARE_DIETPI_DASHBOARD_VERSION=' 'SOFTWARE_DIETPI_DASHBOARD_VERSION=Nightly' rootfs/boot/dietpi.txt
fi

# Workaround invalid TERM on login
# shellcheck disable=SC2016
G_EXEC eval 'echo '\''infocmp "$TERM" > /dev/null 2>&1 || { echo "[ INFO ] Unsupported TERM=\"$TERM\", switching to TERM=\"dumb\""; export TERM=dumb; }'\'' > rootfs/etc/bashrc.d/00-dietpi-ci.sh'

# Enable automated setup
G_CONFIG_INJECT 'AUTO_SETUP_AUTOMATED=' 'AUTO_SETUP_AUTOMATED=1' rootfs/boot/dietpi.txt

# Apply dummy ALSA device
G_CONFIG_INJECT 'CONFIG_SOUNDCARD=' 'CONFIG_SOUNDCARD=dummy' rootfs/boot/dietpi.txt

# ARMv6/7/RISC-V Trixie: Workaround failing chpasswd, which tries to access /proc/sys/vm/mmap_min_addr, but fails as of AppArmor on the host
if (( ( $arch < 3 || $arch == 11 ) && $dist > 7 )) && systemctl -q is-active apparmor
then
	G_EXEC eval 'echo '\''/proc/sys/vm/mmap_min_addr r,'\'' > /etc/apparmor.d/local/unix-chkpwd'
	G_EXEC_OUTPUT=1 G_EXEC apparmor_parser -r /etc/apparmor.d/unix-chkpwd
fi

# Transmission: Workaround for transmission-daemon timing out with container host AppArmor throwing: apparmor="ALLOWED" operation="sendmsg" class="file" info="Failed name lookup - disconnected path" error=-13 profile="transmission-daemon" name="run/systemd/notify"
if (( ${aINSTALL[transmission]} )) && (( $dist > 7 )) && systemctl -q is-active apparmor
then
	G_EXEC sed --follow-symlinks -i '/^profile transmission-daemon/s/flags=(complain)/flags=(complain,attach_disconnected)/' /etc/apparmor.d/transmission
	G_EXEC_OUTPUT=1 G_EXEC apparmor_parser -r /etc/apparmor.d/transmission
fi

# rsyslog: Workaround for rsyslogd timing out with container host AppArmor throwing: apparmor="DENIED" operation="sendmsg" class="file" info="Failed name lookup - disconnected path" error=-13 profile="rsyslogd" name="run/systemd/journal/dev-log"
if (( ${aINSTALL[rsyslog]} )) && (( $dist > 7 )) && systemctl -q is-active apparmor
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
if (( ${aINSTALL[papermc]} ))
then
	G_EXEC mkdir -p rootfs/mnt/dietpi_userdata/papermc/plugins
	G_EXEC eval 'echo '\''eula=true'\'' > rootfs/mnt/dietpi_userdata/papermc/eula.txt'
	G_EXEC touch rootfs/mnt/dietpi_userdata/papermc/plugins/Geyser-Spigot.jar
fi

# Workarounds for QEMU-emulated containers
if (( $emulation ))
then
	# Failing systemd services: https://gitlab.com/qemu-project/qemu/-/issues/1962, https://github.com/systemd/systemd/issues/31219
	for i in rootfs/lib/systemd/system/*.service
	do
		[[ -f $i ]] || continue
		grep -Eq '^(Import|Load)Credential=' "$i" || continue
		G_EXEC mkdir "${i/lib/etc}.d"
		G_EXEC eval "echo -e '[Service]\nImportCredential=\nLoadCredential=' > '${i/lib/etc}.d/dietpi-no-credentials.conf'"
	done

	# PrivateUsers causes "Failed to set up user namespacing"
	# ProtectHome/ProtectSystem/PrivateTmp/... cause "Failed to set up mount namespacing: Invalid argument": https://github.com/systemd/systemd/issues/39951
	# shellcheck disable=SC2068
	for i in ${aSERVICES[@]}
	do
		G_EXEC mkdir "rootfs/etc/systemd/system/$i.service.d"
		G_EXEC eval "echo -e '[Service]\nPrivateUsers=0\nProtectSystem=0\nProtectHome=0\nPrivateTmp=0\nPrivateDevices=0\nProtectKernelModules=0\nProtectControlGroups=0\nProtectKernelTunables=0\nProtectKernelLogs=0\nReadWritePaths=\nProtectProc=default\nProcSubset=all\nNoExecPaths=\nExecPaths=\nInaccessiblePaths=' > 'rootfs/etc/systemd/system/$i.service.d/dietpi-container.conf'"
	done

	# Failing 32-bit ARM Rust builds on ext4 with 64-bit host: https://github.com/rust-lang/cargo/issues/9545
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

# ARMv6/7: Workaround for "deprecated CP15 Barrier instruction" on ARMv8 host: https://github.com/MichaIng/DietPi/issues/6306#issuecomment-1515303702
(( $arch < 3 && $G_HW_ARCH == 3 )) && G_EXEC sysctl -w 'abi.cp15_barrier=2'

# WiFi Hotspot
if (( ${aINSTALL[wifihotspot]} ))
then
	# Create dummy network config for sed to succeed
	G_EXEC mkdir -p rootfs/etc/network
	G_EXEC eval '>> rootfs/etc/network/interfaces'
	# Replace dedicated hotspot interface with default route interface, for the DHCP server and in case Tor have a valid interface and IP to listen on
	G_EXEC sed --follow-symlinks -i "/# Start DietPi-Software/i\sed -i '/INTERFACESv4/s/\$wifi_iface/$(G_GET_NET iface)/' /boot/dietpi/dietpi-software" rootfs/boot/dietpi/dietpi-login
	G_EXEC sed --follow-symlinks -i "/# Start DietPi-Software/i\sed -i '/192\.168\.42\.10/! s/192\.168\.42\.1/$(G_GET_NET ip)/' /boot/dietpi/dietpi-software" rootfs/boot/dietpi/dietpi-login
	G_EXEC sed --follow-symlinks -i "/# Start DietPi-Software/i\sed -i 's/192\.168\.42\./$(G_GET_NET ip | sed 's/[0-9]*$//')/g' /boot/dietpi/dietpi-software" rootfs/boot/dietpi/dietpi-login
fi

# Workaround for Apache on emulated RISC-V system
if (( ${aINSTALL[apache]} )) && (( $emulation && $arch == 11 ))
then
	G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/i\sed -i '\''/^DocumentRoot/a\Mutex posixsem'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login
fi

# Workaround for Readarr/Kavita explicitly calling uname without shell, breaking our ARM workaround
if (( ${aINSTALL[readarr]} )) || (( ${aINSTALL[kavita]} )) && [[ -f 'rootfs/usr/local/bin/uname' ]]
then
	G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/i\sed -i '\''/# Custom 1st run script/i\\rm /usr/local/bin/uname'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login
fi

# Workaround for Snapcast Client, using file output where no ALSA device is available
# shellcheck disable=SC2016
(( ${aINSTALL[snapcastclient]} )) && G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/i\sed -i '\''s/-p \$snapcast_server_port/-p \$snapcast_server_port --player file/'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login

# ADS-B Feeder/Portainer/K3s
if (( ${aINSTALL[adsbfeeder]} )) || (( ${aINSTALL[portainer]} )) || (( ${aINSTALL[k3s]} ))
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
if (( ${aINSTALL[microk8s]} ))
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
# - Start all services
# shellcheck disable=SC2016
G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/a\sed -i '\''/# Custom 1st run script/a\\for i in "${aSTART_SERVICES[@]}"; do G_EXEC_NOHALT=1 G_EXEC systemctl start "$i"; done'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login
delay=10
for i in "${aDELAY[@]}"; do (( $i > $delay )) && delay=$i; done
G_EXEC eval "echo -e '#!/bin/dash\nexit_code=0; /boot/dietpi/dietpi-services start || exit_code=1; echo Waiting $delay seconds for service starts; sleep $delay' > rootfs/boot/Automation_Custom_Script.sh"
# - Loop through software IDs to test
printf '%s\n' "${!aSERVICES[@]}" "${!aTCP[@]}" "${!aUDP[@]}" "${!aCOMMANDS[@]}" | sort -u | while read -r i
do
	[[ ${aSERVICES[$i]}${aTCP[$i]}${aUDP[$i]}${aCOMMANDS[$i]} ]] || continue

	# Check whether ID really got installed, to skip software unsupported on hardware or distro
	cat << _EOF_ >> rootfs/boot/Automation_Custom_Script.sh
if grep -q '^aSOFTWARE_INSTALL_STATE\[$i\]=2$' /boot/dietpi/.installed
then
_EOF_
	# Check service status
	[[ ${aSERVICES[$i]} ]] && for j in ${aSERVICES[$i]}; do cat << _EOF_ >> rootfs/boot/Automation_Custom_Script.sh
echo -n '\e[33m[ INFO ] Checking $j service status:\e[0m '
systemctl is-active '$j' || { journalctl -u '$j'; exit_code=1; }
_EOF_
	done
	# Check TCP ports
	[[ ${aTCP[$i]} ]] && for j in ${aTCP[$i]}; do cat << _EOF_ >> rootfs/boot/Automation_Custom_Script.sh
echo '\e[33m[ INFO ] Checking TCP port $j status:\e[0m'
ss -tlpn | grep ':${j}[[:blank:]]' 2> /dev/null || { echo '\e[31m[FAILED] TCP port ${j} not active\e[0m'; exit_code=1; }
_EOF_
	done
	# Check UDP ports
	[[ ${aUDP[$i]} ]] && for j in ${aUDP[$i]}; do cat << _EOF_ >> rootfs/boot/Automation_Custom_Script.sh
echo '\e[33m[ INFO ] Checking UDP port $j status:\e[0m'
ss -ulpn | grep ':${j}[[:blank:]]' 2> /dev/null || { echo '\e[31m[FAILED] UDP port ${j} not active\e[0m'; exit_code=1; }
_EOF_
	done
	# Check commands
	[[ ${aCOMMANDS[$i]} ]] && cat << _EOF_ >> rootfs/boot/Automation_Custom_Script.sh
echo '\e[33m[ INFO ] Testing command "${aCOMMANDS[$i]}":\e[0m'
${aCOMMANDS[$i]} || { echo '\e[31m[FAILED] Command returned error code\e[0m'; exit_code=1; }
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
