#!/bin/bash
{
	#////////////////////////////////////
	# DietPi Raspimjpeg control Script
	#
	#////////////////////////////////////
	# Created by Daniel Knight / daniel.knight@dietpi.com / dietpi.com
	#
	# Info:
	# - Location /var/lib/dietpi/dietpi-software/services/raspimjpeg.service
	# - Allows service control for Raspimjpeg and PHP schedule, used by RPI Camera Web
	# - Called from /DietPi/dietpi/dietpi-services
	#
	#////////////////////////////////////

	Raspimjeg_Stop(){

		killall -w raspimjpeg &> /dev/null
		killall -w php &> /dev/null

	}

	Raspimjeg_Start(){

		mkdir -p /dev/shm/mjpeg
		chown www-data:www-data /dev/shm/mjpeg
		chmod 777 /dev/shm/mjpeg
		sleep 4
		sudo -u www-data raspimjpeg > /dev/null 2>&1 &
		if [ -e /etc/debian_version ]; then

		  sleep 4
		  sudo -u www-data php /var/www/rpicam/schedule.php > /dev/null 2>&1 &

		else

		  sleep 4
		  sudo -u www-data /bin/bash -c php /var/www/rpicam/schedule.php > /dev/null 2>&1 &

		fi

	}

	if [ "$1" = "stop" ]; then

		Raspimjeg_Stop

	fi

	if [ "$1" = "start" ]; then

		Raspimjeg_Start

	fi

	exit 0

}