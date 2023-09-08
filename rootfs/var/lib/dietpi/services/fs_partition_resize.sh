#!/bin/bash
{
	# Error out on command failures
	set -e

	Reboot_to_load_Partition_table()
	{
		> /dietpi_skip_partition_resize
		systemctl enable dietpi-fs_partition_resize
		echo '[ INFO ] Rebooting to load the new partition table'
		reboot
		exit 0
	}

	# Disable this service
	! systemctl is-enabled dietpi-fs_partition_resize > /dev/null || systemctl disable dietpi-fs_partition_resize

	# Detect root device
	ROOT_DEV=$(findmnt -Ufnro SOURCE -M /)

	# Detect root partition and parent drive for supported naming schemes:
	# - SCSI/SATA:	/dev/sd[a-z][1-9]
	# - IDE:	/dev/hd[a-z][1-9]
	# - VirtIO:	/dev/vd[a-z][1-9]
	# - eMMC:	/dev/mmcblk[0-9]p[1-9]
	# - NVMe:	/dev/nvme[0-9]n[0-9]p[1-9]
	# - loop:	/dev/loop[0-9]p[1-9]
	if [[ $ROOT_DEV == /dev/[shv]d[a-z][1-9] ]]
	then
		ROOT_PART=${ROOT_DEV: -1}	# /dev/sda1 => 1
		ROOT_DRIVE=${ROOT_DEV::-1}	# /dev/sda1 => /dev/sda

	elif [[ $ROOT_DEV =~ ^/dev/(mmcblk|nvme[0-9]n|loop)[0-9]p[1-9]$ ]]
	then
		ROOT_PART=${ROOT_DEV: -1}	# /dev/mmcblk0p1 => 1
		ROOT_DRIVE=${ROOT_DEV::-2}	# /dev/mmcblk0p1 => /dev/mmcblk0
	else
		echo "[FAILED] Unsupported root device naming scheme ($ROOT_DEV). Aborting..."
		exit 1
	fi

	# check if the last partition is a 4MB partition with the Windows/FAT type
	if sfdisk -l "$ROOT_DRIVE" | tail -1 | grep -E "\s4M\s+c\s" > /dev/null 2>&1
	then
		# the last partition is a 4M FAT filesystem - let's check if it is ours
		SETUP_PART=$(sfdisk -l "$ROOT_DRIVE" | tail -1 | mawk '{print $1}')
		if blkid "$SETUP_PART" | grep 'LABEL="DIETPISETUP"'
		then
			# mount it and copy files
			TEMP_MOUNT=$(mktemp -d)
			mount "$SETUP_PART" "$TEMP_MOUNT"
			[[ -f "$TEMP_MOUNT"/dietpi.txt ]] && cp "$TEMP_MOUNT"/dietpi.txt /boot/dietpi.txt
			[[ -f "$TEMP_MOUNT"/dietpi-wifi.txt ]] && cp "$TEMP_MOUNT"/dietpi-wifi.txt /boot/dietpi-wifi.txt
			umount "$SETUP_PART"
			rmdir "$TEMP_MOUNT"
			# finally delete the partition so the resizing works
			sfdisk --no-tell --no-reread --delete "$ROOT_DRIVE" "${SETUP_PART: -1}"
		fi
	fi

	# Only increase partition size if not yet done on first boot
	if [[ -f '/dietpi_skip_partition_resize' ]]
	then
		rm /dietpi_skip_partition_resize
	else
		# Failsafe: Sync changes to disk before touching partitions
		sync

		# GPT partition table: Move backup GPT data structures to the end of the disk
		# - lsblk -ndo PTTYPE "$ROOT_DRIVE" does not work inside systemd-nspawn containers.
		[[ $(blkid -s PTTYPE -o value -c /dev/null "$ROOT_DRIVE") != 'gpt' ]] || sgdisk -e "$ROOT_DRIVE"

		# Maximise root partition size
		sfdisk --no-reread --no-tell-kernel -fN"$ROOT_PART" "$ROOT_DRIVE" <<< ',+'

		# Inform kernel about changed partition table, be failsafe by using two different methods and reboot if any fails
		partprobe "$ROOT_DRIVE" || Reboot_to_load_Partition_table
		partx -u "$ROOT_DRIVE" || Reboot_to_load_Partition_table

		# Give the system some time to have the changes fully applied: https://github.com/MichaIng/DietPi/issues/5006
		sleep 0.5
	fi

	# Detect root filesystem type
	ROOT_FSTYPE=$(findmnt -Ufnro FSTYPE -M /)

	# Maximise root filesystem if type is supported
	case $ROOT_FSTYPE in
		'ext'[234]) resize2fs "$ROOT_DEV" || reboot;; # Reboot if resizing fails: https://github.com/MichaIng/DietPi/issues/6149
		'f2fs')
			mount -o remount,ro /
			resize.f2fs "$ROOT_DEV"
			mount -o remount,rw /
		;;
		'btrfs') btrfs filesystem resize max /;;
		*)
			echo "[FAILED] Unsupported root filesystem type ($ROOT_FSTYPE). Aborting..."
			exit 1
		;;
	esac

	exit 0
}
