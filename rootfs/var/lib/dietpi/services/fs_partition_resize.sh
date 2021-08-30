#!/bin/bash
{
	# Error out on command failures
	set -e

	# Disable this service
	! systemctl is-enabled dietpi-fs_partition_resize > /dev/null || systemctl disable dietpi-fs_partition_resize

	# Detect root device
	ROOT_DEV=$(findmnt -Ufnro SOURCE -M /)

	# Detect root partition and parent drive for supported naming schemes:
	# - SCSI/SATA:	/dev/sd[a-z][1-9]
	# - IDE:	/dev/hd[a-z][1-9]
	# - eMMC:	/dev/mmcblk[0-9]p[1-9]
	# - NVMe:	/dev/nvme[0-9]n[0-9]p[1-9]
	# - loop:	/dev/loop[0-9]p[1-9]
	if [[ $ROOT_DEV == /dev/[sh]d[a-z][1-9] ]]; then

		ROOT_PART=${ROOT_DEV: -1}	# /dev/sda1 => 1
		ROOT_DRIVE=${ROOT_DEV%[1-9]}	# /dev/sda1 => /dev/sda

	elif [[ $ROOT_DEV =~ ^/dev/(mmcblk|nvme[0-9]n|loop)[0-9]p[1-9]$ ]]; then

		ROOT_PART=${ROOT_DEV##*[0-9]p}	# /dev/mmcblk0p1 => 1
		ROOT_DRIVE=${ROOT_DEV%p[1-9]}	# /dev/mmcblk0p1 => /dev/mmcblk0

	else

		echo "[FAILED] Unsupported root device naming scheme ($ROOT_DEV). Aborting..."
		exit 1

	fi

	# Failsafe: Sync changes to disk before touching partitions
	sync

	# GPT partition table: Move backup GPT data structures to the end of the disk
	# - lsblk -ndo PTTYPE "$ROOT_DRIVE" does not work inside systemd-nspawn containers.
	[[ $(blkid -s PTTYPE -o value -c /dev/null "$ROOT_DRIVE") != 'gpt' ]] || sgdisk -e "$ROOT_DRIVE"

	# Maximise root partition size
	sfdisk --no-reread --no-tell-kernel -fN"$ROOT_PART" "$ROOT_DRIVE" <<< ',+'

	# Inform kernel about changed partition table, be failsafe by using two differet methods
	partprobe "$ROOT_DRIVE"
	partx -u "$ROOT_DRIVE"

	# Detect root filesystem type
	ROOT_FSTYPE=$(findmnt -Ufnro FSTYPE -M /)

	# Maximise root filesystem if type is supported
	if [[ $ROOT_FSTYPE == ext[2-4] ]]; then

		resize2fs "$ROOT_DEV"

	elif [[ $ROOT_FSTYPE == 'f2fs' ]]; then

		mount -o remount,ro /
		resize.f2fs "$ROOT_DEV"
		mount -o remount,rw /

	elif [[ $ROOT_FSTYPE == 'btrfs' ]]; then

		btrfs filesystem resize max /

	else

		echo "[FAILED] Unsupported root filesystem type ($ROOT_FSTYPE). Aborting..."
		exit 1

	fi

	exit 0
}
