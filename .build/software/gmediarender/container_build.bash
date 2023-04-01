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
readonly G_PROGRAM_NAME='DietPi-GMediaRender_container_setup'
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
while (( $# ))
do
	case $1 in
		'-d') shift; DISTRO=$1;;
		'-a') shift; ARCH=$1;;
		*) G_DIETPI-NOTIFY 1 "Invalid input \"$1\", aborting..."; exit 1;;
	esac
	shift
done
case $DISTRO in
        5) distro='buster';;
	6) distro='bullseye';;
	7) distro='bookworm';;
	*) G_DIETPI-NOTIFY 1 "Invalid distro \"$DISTRO\" passed, aborting..."; exit 1;;
esac
case $ARCH in
	1) image="DietPi_Container-ARMv6-${distro^}" arch='armv6l';;
	2) image="DietPi_Container-ARMv7-${distro^}" arch='armv7l';;
	3) image="DietPi_Container-ARMv8-${distro^}" arch='aarch64';;
	10) image="DietPi_Container-x86_64-${distro^}" arch='x86_64';;
	11) image='DietPi_Container-RISC-V-Sid' arch='riscv64';;
	*) G_DIETPI-NOTIFY 1 "Invalid architecture \"$ARCH\" passed, aborting..."; exit 1;;
esac

##########################################
# Dependencies
##########################################
apackages=('7zip' 'parted' 'fdisk' 'systemd-container')
(( $G_HW_ARCH == $ARCH || ( $G_HW_ARCH < 10 && $G_HW_ARCH > $ARCH ) )) || apackages+=('qemu-user-static' 'binfmt-support')
G_AG_CHECK_INSTALL_PREREQ "${apackages[@]}"

##########################################
# Prepare container
##########################################
# Download
G_EXEC curl -sSfO "https://dietpi.com/downloads/images/$image.7z"
G_EXEC 7zz e "$image.7z" "$image.img"
G_EXEC rm "$image.7z"
G_EXEC truncate -s $((2*1024**3)) "$image.img"

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

# Enable automated setup
G_CONFIG_INJECT 'AUTO_SETUP_AUTOMATED=' 'AUTO_SETUP_AUTOMATED=1' rootfs/boot/dietpi.txt

# Force ARMv6 arch on Raspbian
(( $ARCH == 1 )) && echo 'sed -i -e '\''/^G_HW_ARCH=/c\G_HW_ARCH=1'\'' -e '\''/^G_HW_ARCH_NAME=/c\G_HW_ARCH_NAME=armv6l'\'' /boot/dietpi/.hw_model' > rootfs/boot/Automation_Custom_PreScript.sh

# Skip filesystem expansion
G_EXEC rm rootfs/etc/systemd/system/local-fs.target.wants/dietpi-fs_partition_resize.service

# Avoid DietPi-Survey uploads to not mess with the statistics
G_EXEC rm rootfs/root/.ssh/known_hosts

# Workaround invalid TERM on login
# shellcheck disable=SC2016
G_EXEC eval 'echo '\''infocmp "$TERM" > /dev/null 2>&1 || export TERM=dumb'\'' > rootfs/etc/bashrc.d/00-dietpi-build.sh'

# Workaround for network connection checks
G_CONFIG_INJECT 'CONFIG_CHECK_CONNECTION_IP=' 'CONFIG_CHECK_CONNECTION_IP=127.0.0.1' rootfs/boot/dietpi.txt
G_CONFIG_INJECT 'CONFIG_CHECK_DNS_DOMAIN=' 'CONFIG_CHECK_DNS_DOMAIN=localhost' rootfs/boot/dietpi.txt

# Automated build
cat << _EOF_ > rootfs/boot/Automation_Custom_Script.sh || exit 1
#!/bin/dash
echo '[ INFO ] Running GMediaRender build script...'
bash -c "\$(curl -sSf 'https://raw.githubusercontent.com/$G_GITOWNER/DietPi/$G_GITBRANCH/.build/software/gmediarender/build.bash')"
mv -v '/tmp/gmediarender_$arch.deb' /
poweroff
_EOF_

##########################################
# Boot container
##########################################
systemd-nspawn -bD rootfs --bind="$FP_LOOP"{,p1} --bind=/dev/disk
[[ -f rootfs/gmediarender_$arch.deb ]] || exit 1
}
