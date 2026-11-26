#!/bin/bash
{
	# Import DietPi-Globals ---------------------------------------------------------------
	. /boot/dietpi/func/dietpi-globals
	readonly G_PROGRAM_NAME='dietpi-wifi-monitor'
	G_CHECK_ROOT_USER "$@"
	G_INIT
	# Import DietPi-Globals ---------------------------------------------------------------

	readonly ADAPTER=$(G_GET_NET -t wlan iface)
	[[ $ADAPTER ]] || { G_DIETPI-NOTIFY 1 'No WiFi adapter has been found. Exiting ...'; exit 1; }
	if [[ ! $TICKRATE =~ ^([3-9]|[1-9][0-9]+)$ ]]
	then
		TICKRATE=$(sed -n '/^[[:blank:]]*CONFIG_WIFI_MONITOR_INTERVAL=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
		[[ $TICKRATE =~ ^([3-9]|[1-9][0-9]+)$ ]] || TICKRATE=10
	fi
	GATEWAY=

	#-------------------------------------------------------------------------------------
	# Main
	#-------------------------------------------------------------------------------------
	G_DIETPI-NOTIFY 2 "Checking connection for $ADAPTER to default gateway every $TICKRATE seconds"

	while G_SLEEP "$TICKRATE"
	do
		if [[ ! -e /sys/class/net/$ADAPTER ]]
		then
			G_DIETPI-NOTIFY 1 "WiFi adapter $ADAPTER has been unplugged. Exiting ..."
			exit 1

		elif ! GATEWAY=$(G_GET_NET -i "$ADAPTER" gateway) || ! ping -nqc 1 -w 10 -I "$ADAPTER" "$GATEWAY" &> /dev/null
		then
			G_DIETPI-NOTIFY 2 "Detected $ADAPTER connection loss. Reconnecting ..."
			ifdown "$ADAPTER"
			G_SLEEP 0.5
			ifup "$ADAPTER"
			G_DIETPI-NOTIFY 0 'Completed'
		fi
	done

	exit 0
}
