#!/bin/bash
# DIETPI copy SDCRAD to Internal Storage / eMMC

# RUN
# bash install-dietpi.s90x.emmc.sh
clear

# Exit on error
set -e

# Red/plain colour codes used by the root-check message below
_r=$'\033[31m'
_x=$'\033[0m'

# Script needs root
[[ $(whoami) != root ]] && echo "$_r Please run this program as root""$_x" && exit 1

# APT
pkgs=(parted util-linux dosfstools rsync)
if ! dpkg -s "${pkgs[@]}" >/dev/null 2>&1; then
  sudo apt install "${pkgs[@]}" -y
fi

echo "SCRIPT WILL COPY SDCARD TO INTERNAL STORAGE eMMC"
echo "it will overwrite exsisting ANDROIDE"
echo ""

echo "Only some tv boxes are able to boot from internal storage"
echo ""

echo "The script takes from 5-15min "
echo "Press SPACE To Continue CTRL+C to exit."
read -rs -d ' '

echo "Start script create MBR and filesystem"

hasdrives=$(lsblk | grep -oE '(mmcblk[0-9])' | sort | uniq)
	if [[ "$hasdrives" = "" ]] ; then
	echo "UNABLE TO FIND ANY EMMC OR SD DRIVES ON THIS SYSTEM!!! "
	exit 1
	fi

avail=$(lsblk | grep -oE '(mmcblk[0-9]|sda[0-9])' | sort | uniq)
	if [[ "$avail" = "" ]] ; then
	echo "UNABLE TO FIND ANY DRIVES ON THIS SYSTEM!!!"
	exit 1
	fi

runfrom=$(lsblk | grep /$ | grep -oE '(mmcblk[0-9]|sda[0-9])')
	if [[ "$runfrom" = "" ]] ; then
	echo " UNABLE TO FIND ROOT OF THE RUNNING SYSTEM!!! "
	exit 1
	fi

emmc=$(echo "$avail" | sed "s/$runfrom//" | sed "s/sd[a-z][0-9]//g" | sed "s/ //g")
	if [[ "$emmc" = "" ]] ; then
	echo " UNABLE TO FIND YOUR EMMC DRIVE OR YOU ALREADY RUN FROM EMMC!!!"
	exit 1
	fi

	if [[ "$runfrom" = "$avail" ]] ; then
	echo " YOU ARE RUNNING ALREADY FROM EMMC!!! "
	exit 1
	fi

	if [[ $runfrom = "$emmc" ]] ; 	then
	echo " YOU ARE RUNNING ALREADY FROM EMMC!!! "
	exit 1
	fi

	if [[ "$(echo "$emmc" | grep mmcblk)" = "" ]] ; then
	echo " YOU DO NOT APPEAR TO HAVE AN EMMC DRIVE!!! "
	exit 1
	fi

DEV_EMMC="/dev/$emmc"
echo "FOUND INTERNAL STORAGE: $DEV_EMMC"

echo "Start backup u-boot default"
dd if="${DEV_EMMC}" of=u-boot-default-aml.img bs=1M count=4 &> /dev/null

echo "Start create MBR and partittion"
parted -s "${DEV_EMMC}" mklabel msdos
parted -s "${DEV_EMMC}" mkpart primary fat32 1000M 1512M
parted -s "${DEV_EMMC}" mkpart primary ext4 1513M 100%

echo "Start restore u-boot"
dd if=u-boot-default-aml.img of="${DEV_EMMC}" conv=fsync bs=1 count=442 &> /dev/null
dd if=u-boot-default-aml.img of="${DEV_EMMC}" conv=fsync bs=512 skip=1 seek=1 &> /dev/null
sync

PART_BOOT="${DEV_EMMC}p1"
PART_ROOT="${DEV_EMMC}p2"

DIR_INSTALL="/EMMC_INSTALL"
mkdir -p "$DIR_INSTALL"

echo "BOOT_EMMC SETUP"

if grep -q "$PART_BOOT" /proc/mounts ; then
    echo "Unmounting BOOT partiton."
    umount -f "$PART_BOOT"
fi

echo "Formatting BOOT partition..."
mkfs.vfat -n "BOOT_EMMC" "$PART_BOOT" &> /dev/null

mount -o rw "$PART_BOOT" "$DIR_INSTALL"

echo -e "Copying BOOT files..."
#cp -r ./BOOT_EMMC/* $DIR_INSTALL && sync
cd /boot
cp -v -r ./* "$DIR_INSTALL" && sync

BOOT_DEV_SD=$(blkid | grep vfat | grep -v "BOOT_EMMC" | cut -d ':' -f1)
mkdir -p boot_vfat_sd
mount "$BOOT_DEV_SD" ./boot_vfat_sd
cp -v ./boot_vfat_sd/u-boot.ext "$DIR_INSTALL/u-boot.emmc"
while ! umount "$BOOT_DEV_SD" ; do sleep 1 ; done
rm -r ./boot_vfat_sd

if umount "$DIR_INSTALL" ; then
echo "Unmount BOOT_EMMC"
fi

if grep -q "$PART_ROOT" /proc/mounts ; then
    echo "Unmounting ROOT partiton."
    umount -f "$PART_ROOT"
fi

echo "Formatting ROOT partition..."
mke2fs -F -q -t ext4 -L ROOT_EMMC -m 0 "$PART_ROOT"
e2fsck -n "$PART_ROOT"

mount -v -o rw,noatime,lazytime,commit=120 "$PART_ROOT" "$DIR_INSTALL"

echo "Copying SDCARD ROOT to eMMC."

#echo "Stop swap"
#swapoff /var/swap
#rm  -f /var/swap

#cd /
#echo "Copy VAR"
#tar -cf - var | (cd $DIR_INSTALL; tar -xpf -)

rsync -aAEHXx --info=progress2  --numeric-ids --exclude={"/EMMC_INSTALL","/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} /  "/$DIR_INSTALL/"

cp -v -r /mnt/{dietpi_userdata,ftp_client,nfs_client,samba} "/$DIR_INSTALL/mnt/"

echo "Change UUID /etc/fstab and /boot/dietpiEnv.txt"

SD_UUID=$(findmnt -n -o UUID /)
EMMC_UUID=$(findmnt -n -o UUID /EMMC_INSTALL)

# FIX UUID EMMC
sed -i "s/$SD_UUID/$EMMC_UUID/" "/$DIR_INSTALL/etc/fstab"
sed -i "s/$SD_UUID/$EMMC_UUID/" "/$DIR_INSTALL/boot/dietpiEnv.txt"

sync

# Performance
#tune2fs -o journal_data_writeback $(findmnt -n -o SOURCE /EMMC_INSTALL)
tune2fs -O fast_commit "$(findmnt -n -o SOURCE /EMMC_INSTALL)"

echo "Umount EMMC_ROOT"
umount "$DIR_INSTALL"
rm -rf "$DIR_INSTALL"

echo "*******************************************"
echo "Complete copy OS to eMMC "
echo
echo "REMOVE SDCARD AFTER SHUTDOWN"
echo "*******************************************"
