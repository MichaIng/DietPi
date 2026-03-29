#!/bin/bash
# DietPi USB Auto-Mount script
# - Called by dietpi-automount@.service on USB block device add
# - Called directly by udev rule on USB block device remove
# Usage: dietpi-fs_automount.sh <add|remove> <device>
{
	action=$1
	device=$2

	if [[ $action == 'add' ]]
	then
		# Skip if already mounted
		findmnt -nro TARGET "$device" &> /dev/null && exit 0

		# Get UUID and filesystem type
		uuid=$(blkid -s UUID -o value "$device")
		[[ $uuid ]] || exit 0
		fstype=$(blkid -s TYPE -o value "$device")
		[[ $fstype ]] || exit 0

		# Mount options
		options='noatime,lazytime,rw'
		case $fstype in
			'ntfs') options+=',permissions,big_writes';;
			'exfat') getent group dietpi > /dev/null && options+=',gid=dietpi,fmask=0002,dmask=0002';;
		esac

		# Mount to /media/<uuid>
		mount_point="/media/$uuid"
		mkdir -p "$mount_point"
		if ! mount -o "$options" "$device" "$mount_point" 2>/dev/null
		then
			rmdir "$mount_point" 2> /dev/null
			exit 1
		fi

	elif [[ $action == 'remove' ]]
	then
		# Find mount point in /media/ for this device
		mount_point=$(findmnt -nro TARGET "$device" 2>/dev/null | grep '^/media/')
		[[ $mount_point ]] || exit 0

		# Lazy unmount in case files are still in use
		umount -l "$mount_point"
		rmdir "$mount_point" 2> /dev/null || true
	fi

	exit 0
}
