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
readonly G_PROGRAM_NAME='DietPi-Software build'
G_CHECK_ROOT_USER "$@"
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
[[ $NAME =~ ^('amiberry'|'amiberry'[-+]'lite'|'domoticz'|'gzdoom'|'gmediarender'|'gogs'|'shairport-sync'|'squeezelite'|'unbound'|'vaultwarden'|'ympd')$ ]] || Error_Exit "Invalid software title \"$NAME\" passed"
[[ $NAME == 'gogs' ]] && EXT='7z' || EXT='deb'
case $DISTRO in
	'bullseye') dist=6;;
	'bookworm') dist=7;;
	'trixie') dist=8;;
	'forky') dist=9;;
	*) Error_Exit "Invalid distro \"$DISTRO\" passed";;
esac
case $ARCH in
	'armv6l') image="ARMv6-${DISTRO^}" arch=1; [[ $NAME == 'amiberry-lite' || $NAME == 'gzdoom' ]] && Error_Exit "Invalid software title \"$NAME\" for arch \"$ARCH\" passed";;
	'armv7l') image="ARMv7-${DISTRO^}" arch=2; [[ $NAME == 'gzdoom' ]] && Error_Exit "Invalid software title \"$NAME\" for arch \"$ARCH\" passed";;
	'aarch64') image="ARMv8-${DISTRO^}" arch=3;;
	'x86_64') image="x86_64-${DISTRO^}" arch=10;;
	'riscv64') image="RISC-V-${DISTRO^}" arch=11; (( $dist < 8 )) && Error_Exit "Invalid distro \"$DISTRO\" for arch \"$ARCH\" passed, only \"trixie\" or newer is supported";;
	*) Error_Exit "Invalid architecture \"$ARCH\" passed";;
esac
image="DietPi_Container-$image.img"

SCRIPT=$NAME
ARGS=()
if [[ $NAME == 'amiberry'* ]]
then
	# ARMv6: Use dedicated Amiberry v5.7.1 build script
	if (( $arch == 1 ))
	then
		SCRIPT='amiberry-v5'
		NAME='amiberry'

	# Else: Use merged build script and pass variant as argument
	else
		SCRIPT='amiberry'
		ARGS+=("$NAME")
		NAME=${NAME%+lite} # Check for amiberry_*.deb if both were built
	fi
fi

##########################################
# Dependencies
##########################################
apackages=('xz-utils' 'parted' 'fdisk' 'systemd-container')

# Emulation support in case of incompatible architecture
emulation=0
(( $G_HW_ARCH == $arch || ( $G_HW_ARCH < 10 && $G_HW_ARCH > $arch ) )) || emulation=1

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

# Mount as loop device
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

# ARMv6/7 Trixie: Workaround failing chpasswd, which tries to access /proc/sys/vm/mmap_min_addr, but fails as of AppArmor on the host
if (( $arch < 3 && $dist > 7 )) && systemctl -q is-active apparmor
then
	G_EXEC eval 'echo '\''/proc/sys/vm/mmap_min_addr r,'\'' > /etc/apparmor.d/local/unix-chkpwd'
	G_EXEC_NOHALT=1 G_EXEC_OUTPUT=1 systemctl restart apparmor || { journalctl -n 25; exit 1; }
fi

# Install Go for Gogs
[[ $NAME == 'gogs' ]] && G_CONFIG_INJECT 'AUTO_SETUP_INSTALL_SOFTWARE_ID=' 'AUTO_SETUP_INSTALL_SOFTWARE_ID=188' rootfs/boot/dietpi.txt

# Workaround invalid TERM on login
# shellcheck disable=SC2016
G_EXEC eval 'echo '\''infocmp "$TERM" > /dev/null 2>&1 || { echo "[ WARN ] Unsupported TERM=\"$TERM\", switching to TERM=\"dumb\""; export TERM=dumb; }'\'' > rootfs/etc/bashrc.d/00-dietpi-build.sh'

# Workaround for failing IPv4 network connectivity check as GitHub Actions runners do not receive external ICMP echo replies
G_CONFIG_INJECT 'CONFIG_CHECK_CONNECTION_IP=' 'CONFIG_CHECK_CONNECTION_IP=127.0.0.1' rootfs/boot/dietpi.txt

# vaultwarden for ARMv6 on ARMv8 host: https://github.com/rust-lang/rust/issues/60605
[[ $NAME == 'vaultwarden' ]] && (( $arch == 1 && $G_HW_ARCH == 3 )) && G_EXEC sysctl -w 'abi.cp15_barrier=2'

# Shutdown on failures before the custom script is executed
G_EXEC sed --follow-symlinks -i 's|Prompt_on_Failure$|{ journalctl -n 50; ss -tulpn; df -h; free -h; systemctl start poweroff.target; }|' rootfs/boot/dietpi/dietpi-login

# Avoid DietPi-Survey uploads to not mess with the statistics
G_EXEC rm rootfs/root/.ssh/known_hosts

# Automated build
# shellcheck disable=SC2154
cat << _EOF_ > rootfs/boot/Automation_Custom_Script.sh || Error_Exit 'Failed to generate Automation_Custom_Script.sh'
#!/bin/dash
echo '[ INFO ] Running $SCRIPT build script ...'
[ '$GH_TOKEN' ] && export GH_TOKEN='$GH_TOKEN'
bash -c "\$(curl -sSf 'https://raw.githubusercontent.com/$G_GITOWNER/DietPi/$G_GITBRANCH/.build/software/$SCRIPT/build.bash')"${ARGS[0]:+ -- "${ARGS[@]}"}
mkdir -v /output && mv -v /tmp/*.$EXT /output
systemctl start poweroff.target
_EOF_

##########################################
# Boot container
##########################################
systemd-nspawn -bD rootfs
[[ -f rootfs/output/${NAME}_$ARCH.$EXT ]] || Error_Exit "Failed to build package: ${NAME}_$ARCH.$EXT"
}
