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
	*) G_DIETPI-NOTIFY 1 "Unsupported host system architecture \"$G_HW_ARCH_NAME\" detected, aborting..."; exit 1;;
esac
readonly G_PROGRAM_NAME='DietPi-vaultwarden_container_setup'
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
distro=
case $DISTRO in
        5) distro='buster';;
	6) distro='bullseye';;
	7) distro='bookworm';;
	*) G_DIETPI-NOTIFY 1 "Invalid distro \"$DISTRO\" passed, aborting..."; exit 1;;
esac
image=
arch=
case $ARCH in
	1) image="DietPi_Container-ARMv6-${distro^}" arch='armv6l';;
	2) image="DietPi_Container-ARMv7-${distro^}" arch='armv7l';;
	3) image="DietPi_Container-ARMv8-${distro^}" arch='aarch64';;
	10) image="DietPi_Container-x86_64-${distro^}" arch='x86_64';;
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
G_EXEC 7zz x "$image.7z"
G_EXEC rm "$image.7z" hash.txt README.md
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

# Automated build
cat << _EOF_ > rootfs/etc/rc.local || exit 1
#!/bin/dash
infocmp "\$TERM" > /dev/null 2>&1 || TERM='dumb'
if grep -q 'raspbian' /etc/os-release
then
	sed -i '/^G_HW_ARCH=/c\G_HW_ARCH=1' /boot/dietpi/.hw_model
	sed -i '/^G_HW_ARCH_NAME=/c\G_HW_ARCH_NAME=armv6l' /boot/dietpi/.hw_model
fi
echo '[ INFO ] Running vaultwarden build script...'
bash -c "\$(curl -sSf 'https://raw.githubusercontent.com/$G_GITOWNER/DietPi/$G_GITBRANCH/.build/software/vaultwarden/build.bash')"
mv -v '/tmp/vaultwarden/vaultwarden_$arch.deb' '/vaultwarden_$arch.deb'
poweroff
_EOF_
G_EXEC chmod +x rootfs/etc/rc.local

# Assure that build starts after DietPi-PostBoot
[[ -d 'rootfs/etc/systemd/system/rc-local.service.d' ]] || G_EXEC mkdir rootfs/etc/systemd/system/rc-local.service.d
G_EXEC eval 'echo -e '\''[Unit]\nAfter=dietpi-postboot.service'\'' > rootfs/etc/systemd/system/rc-local.service.d/dietpi.conf'

##########################################
# Boot container
##########################################
systemd-nspawn -bD rootfs --bind="$FP_LOOP"{,p1} --bind=/dev/disk
[[ -f rootfs/vaultwarden_$arch.deb ]] || exit 1
}
