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
	curl -sSf "https://raw.githubusercontent.com/${G_GITOWNER:=MichaIng}/DietPi/${G_GITBRANCH:=master}/dietpi/func/dietpi-globals" -o /tmp/dietpi-globals || Error_Exit 'Failed to download DietPi-Globals'
	# shellcheck disable=SC1091
	. /tmp/dietpi-globals
	G_EXEC rm /tmp/dietpi-globals
	export G_GITOWNER G_GITBRANCH G_HW_ARCH_NAME=$(uname -m)
	read -r debian_version < /etc/debian_version
	case $debian_version in
		'11.'*|'bullseye/sid') G_DISTRO=6;;
		'12.'*|'bookworm/sid') G_DISTRO=7;;
		'13.'*|'trixie/sid') G_DISTRO=8;;
		*) G_DIETPI-NOTIFY 1 "Unsupported distro version \"$debian_version\". Aborting ..."; exit 1;;
	esac
	# Ubuntu ships with /etc/debian_version from Debian testing, hence we assume one version lower.
	grep -q '^ID=ubuntu' /etc/os-release && ((G_DISTRO--))
	(( $G_DISTRO < 6 )) && { G_DIETPI-NOTIFY 1 'Unsupported Ubuntu version. Aborting ...'; exit 1; }
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
		*) G_DIETPI-NOTIFY 1 "Invalid input \"$1\", aborting..."; exit 1;;
	esac
	shift
done
[[ $DISTRO =~ ^('bullseye'|'bookworm'|'trixie')$ ]] || { G_DIETPI-NOTIFY 1 "Invalid distro \"$DISTRO\" passed, aborting..."; exit 1; }
case $ARCH in
	'armv6l') image="ARMv6-${DISTRO^}" arch=1;;
	'armv7l') image="ARMv7-${DISTRO^}" arch=2;;
	'aarch64') image="ARMv8-${DISTRO^}" arch=3;;
	'x86_64') image="x86_64-${DISTRO^}" arch=10;;
	'riscv64') image='RISC-V-Sid' arch=11;;
	*) G_DIETPI-NOTIFY 1 "Invalid architecture \"$ARCH\" passed, aborting..."; exit 1;;
esac
image="DietPi_Container-$image.img"
[[ $SOFTWARE =~ ^[0-9\ ]+$ ]] || { G_DIETPI-NOTIFY 1 "Invalid software list \"$SOFTWARE\" passed, aborting..."; exit 1; }
[[ $RPI =~ ^('false'|'true')$ ]] || { G_DIETPI-NOTIFY 1 "Invalid RPi flag \"$RPI\" passed, aborting..."; exit 1; }
[[ $TEST =~ ^('false'|'true')$ ]] || { G_DIETPI-NOTIFY 1 "Invalid test flag \"$TEST\" passed, aborting..."; exit 1; }

# Workaround for "Could not execute systemctl:  at /usr/bin/deb-systemd-invoke line 145." during Apache2 DEB postinst in 32-bit ARM Bookworm container: https://lists.ubuntu.com/archives/foundations-bugs/2022-January/467253.html
[[ $SOFTWARE =~ (^| )83( |$) && $DISTRO == 'bookworm' ]] && (( $arch < 3 )) && { echo '[ WARN ] Installing Lighttpd instead of Apache due to a bug in 32-bit ARM containers'; SOFTWARE=$(sed -E 's/(^| )83( |$)/\184\2/g' <<< "$SOFTWARE"); }
# Remove Docker containers from test installs as Docker cannot start in systemd containers
[[ $SOFTWARE =~ (^| )(86|142|185)( |$) ]] && { echo '[ WARN ] Removing Roon Extension Manager, MicroK8s and Portainer from test installs as Docker cannot start in systemd containers'; SOFTWARE=$(sed -E 's/(^| )(86|142|186)( |$)/\1\3/g' <<< "$SOFTWARE"); }
# Add MariaDB with Allo GUI (non-full/reinstall ID 160), as otherwise the install fails
[[ $SOFTWARE =~ (^| )160( |$) ]] && SOFTWARE=$(sed -E 's/(^| )160( |$)/\188 160\2/g' <<< "$SOFTWARE")

##########################################
# Create service and port lists
##########################################
aSERVICES=() aTCP=() aUDP=() aCOMMANDS=() aDELAY=()
Process_Software()
{
	local i
	for i in "$@"
	do
		# shellcheck disable=SC2016
		case $i in
			'webserver') [[ $SOFTWARE =~ (^| )8[345]( |$) ]] || aSERVICES[84]='lighttpd' aTCP[84]='80';; # Lighttpd as default due to above bug in 32-bit ARM Bookworm containers
			0) aCOMMANDS[i]='ssh -V';;
			1) aCOMMANDS[i]='smbclient -V';;
			2) aSERVICES[i]='fahclient' aTCP[i]='7396';;
			7) aCOMMANDS[i]='ffmpeg -version';;
			9) aCOMMANDS[i]='node -v';;
			#16) aSERVICES[i]='microblog-pub' aTCP[i]='8007';; Service enters a CPU-intense internal error loop until it has been configured interactively via "microblog-pub configure", hence it is not enabled and started anymore after install but instead as part of "microblog-pub configure"
			17) aCOMMANDS[i]='git --version';; # from Bookworm on, the shorthand "-v" is supported
			28) aSERVICES[i]='vncserver' aTCP[i]='5901';;
			29) aSERVICES[i]='xrdp' aTCP[i]='3389';;
			30) aSERVICES[i]='nxserver' aTCP[i]='4000';;
			32) aSERVICES[i]='ympd' aTCP[i]='1337';;
			33) (( $arch == 10 )) && aSERVICES[i]='airsonic' aTCP[i]='8080' aDELAY[i]=30;; # Fails in QEMU-emulated containers, probably due to missing device access
			35) aSERVICES[i]='logitechmediaserver' aTCP[i]='9000'; (( $arch < 10 )) && aDELAY[i]=60;;
			36) aCOMMANDS[i]='squeezelite -t';; # Service listens on random high UDP port and exits if no audio device has been found, which does not exist on GitHub Actions runners, respectively within the containers
			37) aSERVICES[i]='shairport-sync' aTCP[i]='5000';; # AirPlay 2 would be TCP port 7000
			39) aSERVICES[i]='minidlna' aTCP[i]='8200';;
			41) aSERVICES[i]='emby-server' aTCP[i]='8096';;
			42) aSERVICES[i]='plexmediaserver' aTCP[i]='32400';;
			43) aSERVICES[i]='mumble-server' aTCP[i]='64738';;
			44) aSERVICES[i]='transmission-daemon' aTCP[i]='9091 51413' aUDP[i]='51413';;
			45) aSERVICES[i]='deluged deluge-web' aTCP[i]='8112 58846 6882';;
			46) aSERVICES[i]='qbittorrent' aTCP[i]='1340 6881';;
			49) aSERVICES[i]='gogs' aTCP[i]='3000';;
			50) aSERVICES[i]='syncthing' aTCP[i]='8384';;
			51) aCOMMANDS[i]='/usr/games/opentyrian/opentyrian -h';;
			52) aSERVICES[i]='cuberite' aTCP[i]='1339'; (( $arch < 10 )) && aDELAY[i]=120;;
			53) aSERVICES[i]='mineos' aTCP[i]='8443';;
			58) aCOMMANDS[i]='tailscale version';; # aSERVICES[i]='tailscaled' aUDP[i]='41641' GitHub Action runners to not support the TUN module
			59) aSERVICES[i]='raspimjpeg';;
			#60) aUDP[i]='53 68';; Cannot be installed in CI since a WiFi interface is required
			#61) aSERVICES[i]='tor' aUDP[i]='9040';; Cannot be installed in CI since a WiFi interface is required
			62) aCOMMANDS[i]='box86 -v';;
			65) aSERVICES[i]='netdata' aTCP[i]='19999';;
			66) aSERVICES[i]='rpimonitor' aTCP[i]='8888';;
			67) aCOMMANDS[i]='firefox-esr -v';;
			68) aSERVICES[i]='schannel' aUDP[i]='5980';; # remoteit@.service service listens on random high UDP port
			70) aCOMMANDS[i]='gpio -v | grep '\''gpio version'\';;
			71) aSERVICES[i]='webiopi' aTCP[i]='8002';;
			73) aSERVICES[i]='fail2ban';;
			74) aSERVICES[i]='influxdb' aTCP[i]='8086 8088';;
			77) aSERVICES[i]='grafana-server' aTCP[i]='3001'; (( $arch < 10 )) && aDELAY[i]=60;;
			80) aSERVICES[i]='ubooquity' aTCP[i]='2038 2039'; (( $arch == 10 )) || aDELAY[i]=30;;
			83) aSERVICES[i]='apache2' aTCP[i]='80';;
			84) aSERVICES[i]='lighttpd' aTCP[i]='80';;
			85) aSERVICES[i]='nginx' aTCP[i]='80';;
			#86) aSERVICES[i]='roon-extension-manager';; # Docker does not start in systemd containers (without dedicated network)
			88) aSERVICES[i]='mariadb' aTCP[i]='3306';;
			89) case $DISTRO in 'bullseye') aSERVICES[i]='php7.4-fpm';; *) aSERVICES[i]='php8.2-fpm';; esac;;
			91) aSERVICES[i]='redis-server' aTCP[i]='6379';;
			93) aSERVICES[i]='pihole-FTL' aUDP[i]='53';;
			94) aSERVICES[i]='proftpd' aTCP[i]='21';;
			95) aSERVICES[i]='vsftpd' aTCP[i]='21';;
			96) aSERVICES[i]='smbd' aTCP[i]='139 445';;
			97) aCOMMANDS[i]='openvpn --version';; # aSERVICES[i]='openvpn' aUDP[i]='1194' GitHub Action runners do not support the TUN module
			98) aSERVICES[i]='haproxy' aTCP[i]='80 1338';;
			99) aSERVICES[i]='node_exporter' aTCP[i]='9100';;
			#100) (( $arch < 3 )) && aCOMMANDS[i]='/usr/bin/pijuice_cli32 -V' || aCOMMANDS[i]='/usr/bin/pijuice_cli64 -V' aSERVICES[i]='pijuice' aTCP[i]='????' Service does not start without I2C device, not present in container and CLI command always puts you in interactive console
			104) aSERVICES[i]='dropbear' aTCP[i]='22';;
			105) aSERVICES[i]='ssh' aTCP[i]='22';;
			106) aSERVICES[i]='lidarr' aTCP[i]='8686'; (( $arch < 10 )) && aDELAY[i]=60;;
			107) aSERVICES[i]='rtorrent' aTCP[i]='49164' aUDP[i]='6881';;
			108) aCOMMANDS[i]='LD_LIBRARY_PATH=/mnt/dietpi_userdata/amiberry/lib /mnt/dietpi_userdata/amiberry/amiberry -h | grep '\''^$VER: Amiberry '\';;
			109) aSERVICES[i]='nfs-kernel-server' aTCP[i]='2049';;
			110) aCOMMANDS[i]='mount.nfs -V';;
			111) aSERVICES[i]='urbackupsrv' aTCP[i]='55414';;
			115) aSERVICES[i]='webmin' aTCP[i]='10000';;
			116) aSERVICES[i]='medusa' aTCP[i]='8081'; (( $arch == 10 )) || aDELAY[i]=30;;
			#117) :;; # ToDo: Implement automated install via /boot/unattended_pivpn.conf
			118) aSERVICES[i]='mopidy' aTCP[i]='6680';;
			121) aSERVICES[i]='roonbridge' aUDP[i]='9003'; (( $arch < 10 )) && aDELAY[i]=30;;
			122) aSERVICES[i]='node-red' aTCP[i]='1880'; (( $arch == 10 )) || aDELAY[i]=30;;
			123) aSERVICES[i]='mosquitto' aTCP[i]='1883';;
			124) aSERVICES[i]='networkaudiod';; # aUDP[i]='????';;
			125) aSERVICES[i]='synapse' aTCP[i]='8008';;
			126) aSERVICES[i]='adguardhome' aUDP[i]='53' aTCP[i]='8083'; [[ ${aSERVICES[182]} ]] && aUDP[i]+=' 5335';; # Unbound uses port 5335 if AdGuard Home is installed
			128) aSERVICES[i]='mpd' aTCP[i]='6600';;
			131) (( $arch == 2 || $arch == 11 )) || aSERVICES[i]='blynkserver' aTCP[i]='9443'; (( $arch == 10 || $arch == 2 || $arch == 11 )) || aDELAY[i]=60;;
			132) aSERVICES[i]='aria2' aTCP[i]='6800';; # aTCP[i]+=' 6881-6999';; # Listens on random port
			133) (( $arch == 2 || $arch == 11 )) || aSERVICES[i]='yacy' aTCP[i]='8090'; (( $arch == 10 )) && aDELAY[i]=30; (( $arch == 10 || $arch == 2 || $arch == 11)) || aDELAY[i]=60;;
			134) aCOMMANDS[i]='docker compose version';;
			135) aSERVICES[i]='icecast2' aTCP[i]='8000' aCOMMANDS[i]='darkice -h | grep '\''^DarkIce'\';; # darkice service cannot start in container as is requires audio recording device access
			136) aSERVICES[i]='motioneye' aTCP[i]='8765';;
			137) aCOMMANDS[i]='/opt/mjpg-streamer/mjpg_streamer -v';; # aSERVICES[i]='mjpg-streamer' aTCP[i]='8082' Service does not start without an actual video device
			138) aSERVICES[i]='virtualhere' aTCP[i]='7575';;
			139) aSERVICES[i]='sabnzbd' aTCP[i]='8080'; (( $arch == 10 )) || aDELAY[i]=30;; # ToDo: Solve conflict with Airsonic
			140) aSERVICES[i]='domoticz' aTCP[i]='8124 8424';;
			#142) aSERVICES[i]='snapd';; "system does not fully support snapd: cannot mount squashfs image using "squashfs": mount: /tmp/syscheck-mountpoint-2075108377: mount failed: Operation not permitted."
			143) aSERVICES[i]='koel' aTCP[i]='8003'; (( $arch == 10 )) || aDELAY[i]=30;;
			144) aSERVICES[i]='sonarr' aTCP[i]='8989'; (( $arch < 10 )) && aDELAY[i]=90;;
			145) aSERVICES[i]='radarr' aTCP[i]='7878'; (( $arch < 10 )) && aDELAY[i]=90;;
			146) aSERVICES[i]='tautulli' aTCP[i]='8181'; (( $arch == 10 )) || aDELAY[i]=60;;
			147) aSERVICES[i]='jackett' aTCP[i]='9117'; (( $arch < 10 )) && aDELAY[i]=90;;
			148) aSERVICES[i]='mympd' aTCP[i]='1333';;
			149) aSERVICES[i]='nzbget' aTCP[i]='6789';;
			150) aCOMMANDS[i]='mono -V';;
			151) aSERVICES[i]='prowlarr' aTCP[i]='9696'; (( $arch < 10 )) && aDELAY[i]=60;;
			152) aSERVICES[i]='avahi-daemon' aUDP[i]='5353';;
			153) aSERVICES[i]='octoprint' aTCP[i]='5001'; (( $arch == 10 )) || aDELAY[i]=60;;
			154) aSERVICES[i]='roonserver';; # Listens on a variety of different port ranges
			155) aSERVICES[i]='htpc-manager' aTCP[i]='8085'; (( $arch == 10 )) || aDELAY[i]=30; [[ $arch == 3 && $DISTRO == 'trixie' ]] && aDELAY[i]=60;;
			157) aSERVICES[i]='home-assistant' aTCP[i]='8123'; (( $arch == 10 )) && aDELAY[i]=60 || aDELAY[i]=900;;
			158) aSERVICES[i]='minio' aTCP[i]='9001 9004';;
			161) aSERVICES[i]='bdd' aTCP[i]='80 443';;
			162) aCOMMANDS[i]='docker -v';; # aSERVICES[i]='docker' Service does not start in systemd containers (without dedicated network)
			163) aSERVICES[i]='gmediarender';; # DLNA => UPnP high range of ports
			164) aSERVICES[i]='nukkit' aUDP[i]='19132'; (( $arch == 10 )) || aDELAY[i]=60;;
			165) aSERVICES[i]='gitea' aTCP[i]='3000'; (( $arch < 10 )) && aDELAY[i]=30;;
			#166) aSERVICES[i]='pi-spc';; Service cannot reasonably start in container as WirinPi's gpio command fails reading /proc/cpuinfo
			167) aSERVICES[i]='raspotify';;
			#169) aSERVICES[i]='voice-recognizer';; "RuntimeError: This module can only be run on a Raspberry Pi!"
			170) aCOMMANDS[i]='unrar -V';;
			#171) aSERVICES[i]='frps frpc' aTCP[i]='7000 7400 7500';; Interactive install with service and ports depending on server/client/both choice
			172) aSERVICES[i]='wg-quick@wg0' aUDP[i]='51820';;
			174) aCOMMANDS[i]='gimp -v';;
			176) aSERVICES[i]='mycroft';;
			177) aSERVICES[i]='forgejo' aTCP[i]='3000'; (( $arch < 10 )) && aDELAY[i]=30;;
			178) aSERVICES[i]='jellyfin' aTCP[i]='8097'; [[ $arch == [23] ]] && aDELAY[i]=300;; # jellyfin[9983]: arm-binfmt-P: ../../target/arm/translate.c:9659: thumb_tr_translate_insn: Assertion `(dc->base.pc_next & 1) == 0' failed.   ###   jellyfin[9983]: qemu: uncaught target signal 6 (Aborted) - core dumped   ###   about 5 times
			179) aSERVICES[i]='komga' aTCP[i]='2037'; (( $arch == 10 )) && aDELAY[i]=30; (( $arch < 10 )) && aDELAY[i]=300;;
			180) aSERVICES[i]='bazarr' aTCP[i]='6767'; (( $arch == 10 )) && aDELAY[i]=30; (( $arch < 10 )) && aDELAY[i]=90;;
			181) aSERVICES[i]='papermc' aTCP[i]='25565 25575';;
			182) aSERVICES[i]='unbound' aUDP[i]='53'; [[ ${aSERVICES[126]} ]] && aUDP[i]+=' 5335';; # Uses port 5335 if Pi-hole or AdGuard Home is installed, but those do listen on port 53 instead
			183) aSERVICES[i]='vaultwarden' aTCP[i]='8001'; (( $arch < 10 )) && aDELAY[i]=20;;
			184) aSERVICES[i]='tor';; # aTCP[i]='443 9051' Interactive install with ports depending on choice and relay type
			#185) aTCP[i]='9002';; # Docker does not start in systemd containers (without dedicated network)
			186) aSERVICES[i]='ipfs' aTCP[i]='5003 8087';;
			187) aSERVICES[i]='cups' aTCP[i]='631';;
			188) aCOMMANDS[i]='go version';;
			189) aCOMMANDS[i]='sudo -u dietpi codium -v';;
			190) aCOMMANDS[i]='beet version';;
			191) aSERVICES[i]='snapserver' aTCP[i]='1780';;
			192) aSERVICES[i]='snapclient';;
			#193) aSERVICES[i]='k3s';; fails due to missing memory cgroup access from within the container
			194) aSERVICES[i]='postgresql';;
			196) aCOMMANDS[i]='java -version';;
			197) aCOMMANDS[i]='box64 -v';;
			198) aSERVICES[i]='filebrowser' aTCP[i]='8084';;
			199) aSERVICES[i]='spotifyd' aUDP[i]='5353';; # + random high TCP port
			#200) aSERVICES[i]='dietpi-dashboard' aTCP[i]='5252';; "dietpi-dashboard.service: Failed to set up standard input: No such file or directory"; "dietpi-dashboard.service: Failed at step STDIN spawning /opt/dietpi-dashboard/dietpi-dashboard: No such file or directory"
			201) aSERVICES[i]='zerotier-one' aTCP[i]='9993';;
			202) aCOMMANDS[i]='rclone -h';;
			203) aSERVICES[i]='readarr' aTCP[i]='8787'; [[ $arch == [23] ]] && aDELAY[i]=60;;
			204) aSERVICES[i]='navidrome' aTCP[i]='4533'; (( $arch > 9 )) || aDELAY[i]=60;;
			206) aSERVICES[i]='openhab'; (( $arch == 2 )) || aTCP[i]='8444'; [[ $arch == [23] || $arch == 11 ]] && aDELAY[i]=600;; # Service start takes too long in emulated ARMv7 container, so skip port check for now ...
			#207) Moonlight (CLI), "moonlight" command
			#208) Moonlight (GUI), "moonlight-qt" command
			209) aCOMMANDS[i]='restic version';;
			211) aCOMMANDS[i]='hb-service status' aSERVICES[i]='homebridge' aTCP[i]='8581'; (( $arch < 10 )) && aDELAY[i]=30; (( $arch == 3 )) && aDELAY[i]=120;;
			212) aSERVICES[i]='kavita' aTCP[i]='2036'; (( $arch < 10 )) && aDELAY[i]=180; (( $arch == 10 )) && aDELAY[i]=30;;
			213) aSERVICES[i]='soju' aTCP[i]='6667';;
			*) :;;
		esac
	done
}
for i in $SOFTWARE
do
	case $i in
		205) Process_Software webserver;;
		27|56|63|64|75|78|81|107|132) Process_Software 89 webserver;; # 93 (Pi-hole) cannot be installed non-interactively
		38|40|48|54|55|57|59|76|79|82|90|160|210) Process_Software 88 89 webserver;;
		159) Process_Software 36 37 65 88 89 96 121 124 128 129 152 160 163 webserver;;
		47|114|168) Process_Software 88 89 91 webserver;;
		8|33|131|179|206) Process_Software 196;;
		32|148|119) Process_Software 128;;
		129) Process_Software 88 89 128 webserver;;
		49|165|177) Process_Software 0 17 88;;
		#61) Process_Software 60;; # Cannot be installed in CI
		125) Process_Software 194;;
		#86|134|185) Process_Software 162;; # Docker does not start in systemd containers (without dedicated network)
		166) Process_Software 70;;
		180) (( $arch == 10 || $arch == 3 )) || Process_Software 170;;
		188) Process_Software 17;;
		213) Process_Software 17 188;;
		*) :;;
	esac
	Process_Software "$i"
done

##########################################
# Dependencies
##########################################
apackages=('xz-utils' 'parted' 'fdisk' 'systemd-container')

# Emulation support in case of incompatible architecture
emulation=0
(( $G_HW_ARCH == $arch || ( $G_HW_ARCH < 10 && $G_HW_ARCH > $arch ) )) || emulation=1

# Bullseye/Jammy: binfmt-support still required for emulation. With systemd-binfmt only, mmdebstrap throws "E: <arch> can neither be executed natively nor via qemu user emulation with binfmt_misc"
(( $emulation )) && { apackages+=('qemu-user-static'); (( $G_DISTRO < 7 )) && apackages+=('binfmt-support'); }

G_AG_CHECK_INSTALL_PREREQ "${apackages[@]}"

# Register QEMU binfmt configs
if (( $emulation ))
then
	if (( $G_DISTRO < 7 ))
	then
		G_EXEC systemctl disable --now systemd-binfmt
		G_EXEC systemctl restart binfmt-support
	else
		G_EXEC systemctl restart systemd-binfmt
	fi
fi

##########################################
# Prepare container
##########################################
# Download
G_EXEC curl -sSfO "https://dietpi.com/downloads/images/$image.xz"
G_EXEC xz -d "$image.xz"
G_EXEC truncate -s 8G "$image"

# Loop device
FP_LOOP=$(losetup -f)
G_EXEC losetup "$FP_LOOP" "$image"
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
# shellcheck disable=SC2015
(( $arch > 1 )) || { echo -e '#/bin/dash\n[ "$*" = -m ] && echo armv6l || /usr/bin/uname "$@"' > rootfs/usr/local/bin/uname && G_EXEC chmod +x rootfs/usr/local/bin/uname; } || Error_Exit 'Failed to generate /usr/local/bin/uname for ARMv6'

# Force RPi on ARM systems if requested
if [[ $RPI == 'true' ]] && (( $arch < 10 ))
then
	case $arch in
		1) model=1;;
		2) model=2;;
		3) model=4;;
		*) G_DIETPI-NOTIFY 1 "Invalid architecture $ARCH beginning with \"a\" but not being one of the known/accepted ARM architectures. This should never happen!"; exit 1;;
	esac
	G_EXEC rm rootfs/etc/.dietpi_hw_model_identifier
	G_EXEC touch rootfs/boot/{bcm-rpi-dummy.dtb,config.txt,cmdline.txt}
	G_EXEC sed --follow-symlinks -i "/# Start DietPi-Software/iG_EXEC sed -i -e '/^G_HW_MODEL=/cG_HW_MODEL=$model' -e '/^G_HW_MODEL_NAME=/cG_HW_MODEL_NAME=\"RPi $model ($ARCH)\"' /boot/dietpi/.hw_model" rootfs/boot/dietpi/dietpi-login
	G_EXEC curl -sSfo keyring.deb 'https://archive.raspberrypi.com/debian/pool/main/r/raspberrypi-archive-keyring/raspberrypi-archive-keyring_2021.1.1+rpt1_all.deb'
	G_EXEC dpkg --root=rootfs -i keyring.deb
	G_EXEC rm keyring.deb
	# Enforce Debian Trixie FFmpeg packages over RPi repo ones
	[[ $DISTRO == 'trixie' ]] && G_EXEC eval 'echo -e '\''Package: src:ffmpeg\nPin: origin archive.raspberrypi.com\nPin-Priority: -1'\'' > /etc/apt/preferences.d/dietpi-ffmpeg'
fi

# Install test builds from dietpi.com if requested
if [[ $TEST == 'true' ]]
then
	# shellcheck disable=SC2016
	G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/a\sed -i '\''s|dietpi.com/downloads/binaries/$G_DISTRO_NAME/|dietpi.com/downloads/binaries/$G_DISTRO_NAME/testing/|'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login
	G_CONFIG_INJECT 'SOFTWARE_DIETPI_DASHBOARD_VERSION=' 'SOFTWARE_DIETPI_DASHBOARD_VERSION=Nightly' rootfs/boot/dietpi.txt
fi

# Workaround invalid TERM on login
# shellcheck disable=SC2016
G_EXEC eval 'echo '\''infocmp "$TERM" > /dev/null 2>&1 || { echo "[ INFO ] Unsupported TERM=\"$TERM\", switching to TERM=\"dumb\""; export TERM=dumb; }'\'' > rootfs/etc/bashrc.d/00-dietpi-ci.sh'

# Enable automated setup
G_CONFIG_INJECT 'AUTO_SETUP_AUTOMATED=' 'AUTO_SETUP_AUTOMATED=1' rootfs/boot/dietpi.txt
# - Workaround for skipped autologin in emulated Trixie/Sid containers: https://gitlab.com/qemu-project/qemu/-/issues/1962
# - Set HOME path, required e.g. go builds, which is otherwise missing when started from a systemd unit.
if [[ $DISTRO == 'trixie' ]] && (( $G_HW_ARCH != $arch && ( $G_HW_ARCH > 9 || $G_HW_ARCH < $arch ) ))
then
	cat << '_EOF_' > rootfs/etc/systemd/system/dietpi-automation.service
[Unit]
Description=DietPi-Automation
After=dietpi-postboot.service

[Service]
Type=idle
StandardOutput=tty
Environment=HOME=/root
ExecStart=/bin/dash -c 'infocmp "$TERM" > /dev/null 2>&1 || export TERM=dumb; exec /boot/dietpi/dietpi-login'
ExecStop=/sbin/poweroff

[Install]
WantedBy=multi-user.target
_EOF_
	G_EXEC ln -s /etc/systemd/system/dietpi-automation.service rootfs/etc/systemd/system/multi-user.target.wants/
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

# Workaround for "Could not execute systemctl:  at /usr/bin/deb-systemd-invoke line 145." during Apache2 DEB postinst in 32-bit ARM Bookworm container: https://lists.ubuntu.com/archives/foundations-bugs/2022-January/467253.html
G_CONFIG_INJECT 'AUTO_SETUP_WEB_SERVER_INDEX=' 'AUTO_SETUP_WEB_SERVER_INDEX=-2' rootfs/boot/dietpi.txt

# Workaround for failing services as PrivateUsers=true leads to "Failed to set up user namespacing" on QEMU-emulated 32-bit ARM containers, and AmbientCapabilities to "Failed to apply ambient capabilities (before UID change): Operation not permitted"
G_EXEC mkdir rootfs/etc/systemd/system/{redis-server,raspotify,navidrome,homebridge}.service.d
G_EXEC eval 'echo -e '\''[Service]\nPrivateUsers=0'\'' > rootfs/etc/systemd/system/redis-server.service.d/dietpi-container.conf'
G_EXEC eval 'echo -e '\''[Service]\nPrivateUsers=0'\'' > rootfs/etc/systemd/system/raspotify.service.d/dietpi-container.conf'
G_EXEC eval 'echo -e '\''[Service]\nPrivateUsers=0'\'' > rootfs/etc/systemd/system/navidrome.service.d/dietpi-container.conf'
G_EXEC eval 'echo -e '\''[Service]\nAmbientCapabilities='\'' > rootfs/etc/systemd/system/homebridge.service.d/dietpi-container.conf'

# Workaround for failing 32-bit ARM Rust builds on ext4 in QEMU emulated container on 64-bit host: https://github.com/rust-lang/cargo/issues/9545
(( $arch < 3 && $G_HW_ARCH > 9 )) && G_EXEC eval 'echo -e '\''tmpfs /mnt/dietpi_userdata tmpfs size=3G,noatime,lazytime\ntmpfs /root tmpfs size=3G,noatime,lazytime'\'' >> rootfs/etc/fstab'

# Workaround for Node.js on ARMv6
(( $arch == 1 )) && G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/a\sed -i '\''/G_EXEC chmod +x node-install.sh/a\\sed -i "/^ARCH=/c\\ARCH=armv6l" node-install.sh'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login

# Workaround for sysctl: permission denied on key "net.core.rmem_max" in containers
G_EXEC sed --follow-symlinks -i '/# Start DietPi-Software/a\sed -i '\''/G_EXEC sysctl -w net\.core\.rmem_max/d'\'' /boot/dietpi/dietpi-software' rootfs/boot/dietpi/dietpi-login

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
G_EXEC eval 'echo '\''[ $exit_code = 0 ] && > /success || { journalctl -n 50; ss -tulpn; df -h; free -h; }; poweroff'\'' >> rootfs/boot/Automation_Custom_Script.sh'

# Shutdown as well on failures before the custom script is executed
G_EXEC sed --follow-symlinks -i 's|Prompt_on_Failure$|{ journalctl -n 50; ss -tulpn; df -h; free -h; poweroff; }|' rootfs/boot/dietpi/dietpi-login

##########################################
# Boot container
##########################################
systemd-nspawn -bD rootfs
[[ -f 'rootfs/success' ]] || { journalctl -n 25; ss -tlpn; df -h; free -h; exit 1; }
}
