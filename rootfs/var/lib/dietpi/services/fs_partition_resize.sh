#!/bin/bash
{
	# Disable this service
	systemctl disable dietpi-fs_partition_resize

	# Detect root device
	ROOT_DEV=$(findmnt -no SOURCE /)

	# Detect root partition and parent drive for supported naming schemes:
	# - SCSI/SATA:	/dev/sd[a-z][1-9]
	# - IDE:	/dev/hd[a-z][1-9]
	# - eMMC:	/dev/mmcblk[0-9]p[1-9]
	# - NVMe:	/dev/nvme[0-9]n[0-9]p[1-9]
	# - loop:	/dev/loop[0-9]p[1-9]
	if [[ $ROOT_DEV =~ ^/dev/(mmcblk|nvme[0-9]n|loop)[0-9](p[1-9])?$ ]]; then

		ROOT_PART=${ROOT_DEV##*[0-9]p}	# /dev/mmcblk0p1 => 1
		ROOT_DRIVE=${ROOT_DEV%p[1-9]}	# /dev/mmcblk0p1 => /dev/mmcblk0

	elif [[ $ROOT_DEV =~ ^/dev/[sh]d[a-z][1-9]?$ ]]; then

		ROOT_PART=${ROOT_DEV: -1}	# /dev/sda1 => 1
		ROOT_DRIVE=${ROOT_DEV%[1-9]}	# /dev/sda1 => /dev/sda

	else

		echo "[FAILED] Unsupported block device naming scheme ($ROOT_DEV). Aborting..."
		exit 1

	fi

	# Maximize root partition if drive contains a partition table
	if [[ $ROOT_PART == [1-9] ]]; then

		# Failsafe: Sync changes to disk before touching partitions
		sync

		# GPT partition table: Move backup GPT data structures to the end of the disk
		sfdisk -l "$ROOT_DRIVE" | grep -q '^Disklabel type: gpt$' && sgdisk -e "$ROOT_DRIVE"

		# Maximize root partition size
		sfdisk --no-reread --no-tell-kernel -fN"$ROOT_PART" "$ROOT_DRIVE" <<< ',+'

		# Inform kernel about changed partition table, be failsafe by using two differet methods
		partprobe "$ROOT_DRIVE"
		partx -u "$ROOT_DRIVE"

	else

		echo "[ INFO ] The root file system ($ROOT_DEV) does not seem to be on a partition. Skipping partition resize..."

	fi

	# Maximize root file system
	resize2fs "$ROOT_DEV"

	exit 0
}
