#!/bin/bash
{

	# Check for root permissions
	(( $UID )) && { echo 'ERROR: Root permissions required. Please run this script with "sudo". Exiting...'; exit 1; }

	# Check for concurrent execution
	(( $(pgrep -cf 'dietpi-wifi-monitor.sh') > 1 )) && { echo 'ERROR: Concurrent execution detected. Please exit the running instance of DietPi-WiFi-Monitor first. Exiting...'; exit 1; }

	# Update network info
	/DietPi/dietpi/func/obtain_network_details

	URL_PING=''
	ADAPTER="wlan$(sed -n 2p /DietPi/dietpi/.network)"
	[[ $TICKRATE =~ ^[0-9]+$ ]] && (( $TICKRATE > 0 )) || TICKRATE=10

	#-------------------------------------------------------------------------------------
	# Main
	#-------------------------------------------------------------------------------------
	# Check for valid WiFi adapter
	[[ -e /sys/class/net/$ADAPTER ]] || { echo "ERROR: No valid WiFi adapter found on interface: $ADAPTER. Exiting..."; exit 1; }

	echo "Checking connection for: $ADAPTER via ping to default gateway every $TICKRATE seconds"

	while :
	do

		# - Get current gateway for ping
		URL_PING=$(ip r s 0.0.0.0/0 dev $ADAPTER | mawk '{print $3}')

		[[ $G_DEBUG == 1 ]] && echo "Checking connection for: $ADAPTER via ping to $URL_PING"
		if ping -qI $ADAPTER -c 1 $URL_PING &> /dev/null; then

			[[ $G_DEBUG == 1 ]] && echo "Connection valid for: $ADAPTER"

		else

			[[ -e /sys/class/net/$ADAPTER ]] || { echo "ERROR: WiFi adapter has been unplugged: $ADAPTER. Exiting..."; exit 1; }

			echo "Detected connection loss: $ADAPTER. Reconnecting..."
			ifdown $ADAPTER
			sleep 1
			ifup $ADAPTER
			echo 'Completed'

		fi

		sleep $TICKRATE

	done

	exit 0

}
