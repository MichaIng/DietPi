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
	*) Error_Exit "Unsupported host system architecture \"$G_HW_ARCH_NAME\" detected";;
esac
readonly G_PROGRAM_NAME='DietPi-Software build'
G_CHECK_ROOT_USER
G_CHECK_ROOTFS_RW
readonly FP_ORIGIN=$PWD # Store origin dir
G_INIT
G_EXEC cd "$FP_ORIGIN" # Process everything in origin dir instead of /tmp/$G_PROGRAM_NAME

##########################################
# Process inputs
##########################################
NAME=
DISTRO=
ARCH=
while (( $# ))
do
	case $1 in
		'-n') shift; NAME=$1;;
		'-d') shift; DISTRO=$1;;
		'-a') shift; ARCH=$1;;
		*) Error_Exit "Invalid input \"$1\"";;
	esac
	shift
done
[[ $NAME =~ ^('gmediarender'|'gogs'|'shairport-sync'|'squeezelite'|'vaultwarden'|'ympd')$ ]] || Error_Exit "Invalid software title \"$NAME\" passed"
[[ $NAME == 'gogs' ]] && EXT='7z' || EXT='deb'
[[ $DISTRO =~ ^('bullseye'|'bookworm'|'trixie')$ ]] || Error_Exit "Invalid distro \"$DISTRO\" passed"
case $ARCH in
	'armv6l') image="ARMv6-${DISTRO^}" arch=1;;
	'armv7l') image="ARMv7-${DISTRO^}" arch=2;;
	'aarch64') image="ARMv8-${DISTRO^}" arch=3;;
	'x86_64') image="x86_64-${DISTRO^}" arch=10;;
	'riscv64') image='RISC-V-Sid' arch=11; [[ $DISTRO == 'trixie' ]] || Error_Exit "Invalid distro \"$DISTRO\" for arch \"$ARCH\" passed, only \"trixie\" is supported";;
	*) Error_Exit "Invalid architecture \"$ARCH\" passed";;
esac
image="DietPi_Container-$image.img"

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

# Mount as loop device
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

# Enforce ARMv6 arch on Raspbian
# shellcheck disable=SC2015
(( $arch > 1 )) || { echo -e '#/bin/dash\n[ "$*" = -m ] && echo armv6l || /usr/bin/uname "$@"' > rootfs/usr/local/bin/uname && G_EXEC chmod +x rootfs/usr/local/bin/uname; } || Error_Exit 'Failed to generate /usr/local/bin/uname for ARMv6'

# Enable automated setup
G_CONFIG_INJECT 'AUTO_SETUP_AUTOMATED=' 'AUTO_SETUP_AUTOMATED=1' rootfs/boot/dietpi.txt
# - Workaround for skipped autologin in emulated Trixie/Sid containers: https://gitlab.com/qemu-project/qemu/-/issues/1962
if [[ $DISTRO == 'trixie' ]] && (( $G_HW_ARCH != $arch && ( $G_HW_ARCH > 9 || $G_HW_ARCH < $arch ) ))
then
	cat << '_EOF_' > rootfs/etc/systemd/system/dietpi-automation.service
[Unit]
Description=DietPi-Automation
After=dietpi-postboot.service

[Service]
Type=idle
StandardOutput=tty
ExecStart=/bin/dash -c 'infocmp "$TERM" > /dev/null 2>&1 || { echo "[ WARN ] Unsupported TERM=\"$TERM\", switching to TERM=\"dumb\""; export TERM=dumb; }; exec /boot/dietpi/dietpi-login'
ExecStop=/sbin/poweroff

[Install]
WantedBy=multi-user.target
_EOF_
	G_EXEC ln -s /etc/systemd/system/dietpi-automation.service rootfs/etc/systemd/system/multi-user.target.wants/
fi

# Install Go for Gogs
[[ $NAME == 'gogs' ]] && G_CONFIG_INJECT 'AUTO_SETUP_INSTALL_SOFTWARE_ID=' 'AUTO_SETUP_INSTALL_SOFTWARE_ID=188' rootfs/boot/dietpi.txt

# Workaround invalid TERM on login
# shellcheck disable=SC2016
G_EXEC eval 'echo '\''infocmp "$TERM" > /dev/null 2>&1 || { echo "[ WARN ] Unsupported TERM=\"$TERM\", switching to TERM=\"dumb\""; export TERM=dumb; }'\'' > rootfs/etc/bashrc.d/00-dietpi-build.sh'

# Workaround for failing IPv4 network connectivity check as GitHub Actions runners do not receive external ICMP echo replies
G_CONFIG_INJECT 'CONFIG_CHECK_CONNECTION_IP=' 'CONFIG_CHECK_CONNECTION_IP=127.0.0.1' rootfs/boot/dietpi.txt

# Shutdown on failures before the custom script is executed
G_EXEC sed --follow-symlinks -i 's|Prompt_on_Failure$|{ journalctl -n 50; ss -tulpn; df -h; free -h; poweroff; }|' rootfs/boot/dietpi/dietpi-login

# Avoid DietPi-Survey uploads to not mess with the statistics
G_EXEC rm rootfs/root/.ssh/known_hosts

# ARMv6/7 Trixie: Temporarily prevent dist-upgrade on Trixie, as it fails due to 64-bit time_t transition causing dependency conflicts across the repo.
(( $arch < 3 )) && [[ $DISTRO == 'trixie' ]] && G_EXEC touch rootfs/boot/dietpi/.skip_distro_upgrade

# Automated build
cat << _EOF_ > rootfs/boot/Automation_Custom_Script.sh || Error_Exit 'Failed to generate Automation_Custom_Script.sh'
#!/bin/dash
echo '[ INFO ] Running $NAME build script ...'
bash -c "\$(curl -sSf 'https://raw.githubusercontent.com/$G_GITOWNER/DietPi/$G_GITBRANCH/.build/software/$NAME/build.bash')"
mkdir -v /output && mv -v /tmp/*.$EXT /output
poweroff
_EOF_

##########################################
# Boot container
##########################################
systemd-nspawn -bD rootfs
[[ -f rootfs/output/${NAME}_$ARCH.$EXT ]] || Error_Exit "Failed to build package: ${NAME}_$ARCH.$EXT"
}
