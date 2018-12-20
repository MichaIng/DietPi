#!/bin/bash
{

	#Import DietPi-Globals ---------------------------------------------------------------
	. /DietPi/dietpi/func/dietpi-globals
	G_PROGRAM_NAME='DietPi-WiFi-Monitor'
	G_CHECK_ROOT_USER
	G_CHECK_ROOTFS_RW
	G_INIT
	#Import DietPi-Globals ---------------------------------------------------------------

	URL_PING=''
	ADAPTER="wlan$(sed -n 2p /DietPi/dietpi/.network)"
	TICKRATE=10

	#-------------------------------------------------------------------------------------
	#Main
	#-------------------------------------------------------------------------------------
	echo "Checking connnection for: $ADAPTER via ping to default gateway every $TICKRATE seconds"

	while :
	do

		# - Get current gateway for ping
		URL_PING="$(ip r s 0.0.0.0/0 dev $ADAPTER | awk '{print $3}')"

		[[ $G_DEBUG == 1 ]] && echo "Checking connnection for: $ADAPTER via ping to $URL_PING"
		if ping -I $ADAPTER -c 1 $URL_PING; then

			[[ $G_DEBUG == 1 ]] && echo "Connection valid for: $ADAPTER"

		else

			echo "Detected connection loss: $ADAPTER. Reconnecting..."
			ifdown "$ADAPTER"
			sleep 1
			ifup "$ADAPTER"
			echo 'Completed'

		fi

		sleep $TICKRATE

	done

	exit 0

}
