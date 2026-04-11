#!/bin/bash
# DietPi USB Auto-Mount script
# - Called by udev rule (99-dietpi-automount.rules) on USB block device add and remove events
# Usage: dietpi-fs_automount.sh <add|remove> <device>
{
action=$1
device=$2

case $action in
	'add')
		# Skip if already mounted
		if findmnt -nro TARGET "$device" > /dev/null
		then
			logger -t dietpi-automount "Skipping $device: already mounted at $(findmnt -nro TARGET "$device")"
			exit 0
		fi

		# Get UUID and filesystem type
		uuid=$(blkid -s UUID -o value "$device")
		[[ $uuid ]] || exit 0
		fstype=$(blkid -s TYPE -o value "$device")
		[[ $fstype ]] || exit 0

		# Check if this UUID already has an /etc/fstab entry
		fstab_target=$(mawk -v uuid="UUID=$uuid" '$1 == uuid {print $2; exit}' /etc/fstab)
		if [[ $fstab_target ]]
		then
			# fstab entry exists: check mount options for x-systemd.automount
			fstab_options=$(mawk -v uuid="UUID=$uuid" '$1 == uuid {print $4; exit}' /etc/fstab)
			if [[ $fstab_options =~ (^|,)x-systemd\.automount(,|$) ]]
			then
				# x-systemd.automount entries are handled lazily by systemd on first access
				logger -t dietpi-automount "Skipping $device ($uuid): fstab entry at $fstab_target uses x-systemd.automount, systemd will handle it on access"
				exit 0
			fi

			# noauto without x-systemd.automount means the user wants manual control
			if [[ $fstab_options =~ (^|,)noauto(,|$) ]]
			then
				logger -t dietpi-automount "Skipping $device ($uuid): fstab entry at $fstab_target uses noauto, manual mount only"
				exit 0
			fi

			# auto (default) fstab entry: systemd mounts these at boot before local-fs.target.
			# Only mount ourselves if local-fs.target is already active, i.e. this is a post-boot hotplug event.
			if ! systemctl is-active --quiet local-fs.target
			then
				logger -t dietpi-automount "Skipping $device ($uuid): fstab entry at $fstab_target uses auto-mount, systemd will handle it at boot (local-fs.target not yet reached)"
				exit 0
			fi

			# Mount via fstab (applies configured options and mount point)
			logger -t dietpi-automount "Mounting $device ($uuid) via fstab entry at $fstab_target"
			if mount_out=$(mount "$fstab_target" 2>&1)
			then
				logger -t dietpi-automount "Successfully mounted $device at $fstab_target"
			else
				logger -t dietpi-automount -p 4 "[FAILED] Could not mount $device at $fstab_target: $mount_out"
				exit 1
			fi
		else
			# No fstab entry: auto-mount to /media/<uuid>
			options='noatime,lazytime,rw'
			case $fstype in
				'ntfs') options+=',permissions,big_writes';;
				'exfat') getent group dietpi > /dev/null && options+=',gid=dietpi,fmask=0002,dmask=0002';;
				*) :;;
			esac

			mount_point="/media/$uuid"
			mkdir -p "$mount_point"
			logger -t dietpi-automount "Auto-mounting $device ($uuid, $fstype) at $mount_point"
			if mount_out=$(mount -o "$options" "$device" "$mount_point" 2>&1)
			then
				logger -t dietpi-automount "Successfully auto-mounted $device at $mount_point"
			else
				logger -t dietpi-automount -p 4 "[FAILED] Could not auto-mount $device at $mount_point: $mount_out"
				rmdir "$mount_point"
				exit 1
			fi
		fi
	;;
	'remove')
		# Find auto-mount point in /media/ for this device
		# NB: Mounts triggered via fstab entry are intentionally not unmounted here;
		#     those are explicitly user-configured and the OS surfaces I/O errors naturally.
		mount_point=$(findmnt -nro TARGET "$device" | grep '^/media/')
		[[ $mount_point ]] || exit 0

		logger -t dietpi-automount "Unmounting auto-mounted $device from $mount_point"
		# Lazy unmount in case files are still in use
		if umount_out=$(umount -l "$mount_point" 2>&1)
		then
			logger -t dietpi-automount "Successfully unmounted $device from $mount_point"
			rmdir --ignore-fail-on-non-empty "$mount_point"
		else
			logger -t dietpi-automount -p 4 "[FAILED] Could not unmount $device from $mount_point: $umount_out"
			exit 1
		fi
	;;
	*) logger -t dietpi-automount "[FAILED] Invalid action \"$action\" for device \"$device\"";;
esac

exit 0
}
