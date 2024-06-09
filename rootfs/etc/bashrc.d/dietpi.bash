#!/bin/bash
{
	#////////////////////////////////////
	# DietPi bash init script
	#
	#////////////////////////////////////
	# Created by MichaIng / micha@dietpi.com / dietpi.com
	#
	#////////////////////////////////////
	#
	# Info:
	# - Location: /etc/bashrc.d/dietpi.bash
	# - Sourced by all interactive bash shells from: /etc/bash.bashrc
	# - Prepares shell for DietPi and runs autostarts on /dev/tty1
	#////////////////////////////////////

	# Failsafe: Never load this script in non-interactive shells, e.g. SFTP, SCP or rsync
	[[ -t 0 && $- == *'i'* ]] || return 0

	# DietPi-Globals: dietpi-* aliases, G_* functions and variables
	. /boot/dietpi/func/dietpi-globals || { echo -e '[\e[31mFAILED\e[0m] DietPi-Login | Failed to load DietPi-Globals. Skipping DietPi login scripts...'; return 1; }

	# Aliases
	# - sudo alias that allows running other aliases with "sudo": https://github.com/MichaIng/DietPi/issues/424
	alias sudo='sudo '
	# - DietPi programs
	alias dietpi-letsencrypt='/boot/dietpi/dietpi-letsencrypt'
	alias dietpi-autostart='/boot/dietpi/dietpi-autostart'
	alias dietpi-cron='/boot/dietpi/dietpi-cron'
	alias dietpi-launcher='/boot/dietpi/dietpi-launcher'
	alias dietpi-cleaner='/boot/dietpi/dietpi-cleaner'
	alias dietpi-morsecode='/boot/dietpi/dietpi-morsecode'
	alias dietpi-sync='/boot/dietpi/dietpi-sync'
	alias dietpi-backup='/boot/dietpi/dietpi-backup'
	alias dietpi-bugreport='/boot/dietpi/dietpi-bugreport'
	alias dietpi-services='/boot/dietpi/dietpi-services'
	alias dietpi-config='/boot/dietpi/dietpi-config'
	alias dietpi-software='/boot/dietpi/dietpi-software'
	alias dietpi-update='/boot/dietpi/dietpi-update'
	alias dietpi-drive_manager='/boot/dietpi/dietpi-drive_manager'
	alias dietpi-logclear='/boot/dietpi/func/dietpi-logclear'
	alias dietpi-survey='/boot/dietpi/dietpi-survey'
	alias dietpi-explorer='/boot/dietpi/dietpi-explorer'
	alias dietpi-banner='/boot/dietpi/func/dietpi-banner'
	alias dietpi-justboom='/boot/dietpi/misc/dietpi-justboom'
	alias dietpi-led_control='/boot/dietpi/dietpi-led_control'
	alias dietpi-wifidb='/boot/dietpi/func/dietpi-wifidb'
	alias dietpi-optimal_mtu='/boot/dietpi/func/dietpi-optimal_mtu'
	alias dietpi-cloudshell='/boot/dietpi/dietpi-cloudshell'
	alias dietpi-nordvpn='G_DIETPI-NOTIFY 1 "DietPi-NordVPN has been renamed to DietPi-VPN. Please use the \"dietpi-vpn\" command."'
	alias dietpi-vpn='/boot/dietpi/dietpi-vpn'
	alias dietpi-ddns='/boot/dietpi/dietpi-ddns'
	alias cpu='/boot/dietpi/dietpi-cpuinfo'
	# - Optional DietPi software aliases
	[[ -d '/mnt/dietpi_userdata/sonarr' || -d '/mnt/dietpi_userdata/radarr' || -d '/mnt/dietpi_userdata/lidarr' ]] && alias dietpi-arr_to_RAM='/boot/dietpi/misc/dietpi-arr_to_RAM'
	command -v kodi > /dev/null && alias startkodi='kodi --standalone'
	[[ -f '/usr/games/opentyrian/run' ]] && alias opentyrian='/usr/games/opentyrian/run'
	[[ -f '/mnt/dietpi_userdata/dxx-rebirth/run.sh' ]] && alias dxx-rebirth='/mnt/dietpi_userdata/dxx-rebirth/run.sh'
	[[ -f '/var/www/owncloud/occ' ]] && alias occ='sudo -u www-data php /var/www/owncloud/occ'
	[[ -f '/var/www/nextcloud/occ' ]] && alias ncc='sudo -u www-data php /var/www/nextcloud/occ'
	# - 1337 moments ;)
	alias 1337='echo "Indeed, you are =)"'

	# "G_DIETPI-NOFITY -2 message" starts a process animation. If scripts fail to kill the animation, e.g. cancelled by user, terminal bash prompt has to do it as last resort.
	[[ $PROMPT_COMMAND == *'dietpi-process.pid'* ]] || PROMPT_COMMAND="[[ -w '/tmp/dietpi-process.pid' ]] && rm -f /tmp/dietpi-process.pid &> /dev/null && echo -ne '\r\e[J'; $PROMPT_COMMAND"

	# Workaround if SSH client overrides locale with "POSIX" fallback: https://github.com/MichaIng/DietPi/issues/1540#issuecomment-367066178
	if [[ ${LC_ALL:-${LANG:-POSIX}} == 'POSIX' ]]
	then
		current_locale=$(sed -n '/^[[:blank:]]*AUTO_SETUP_LOCALE=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
		export LC_ALL=${current_locale:=C.UTF-8} LANG=$current_locale
		unset -v current_locale
	fi

	# Workaround if SSH client sets an unsupported $TERM string: https://github.com/MichaIng/DietPi/issues/2034
	term="/${TERM::1}/$TERM"
	if [[ $SSH_TTY && ! -f /lib/terminfo$term && ! -f /usr/share/terminfo$term && ! -f ~/.terminfo$term && ! -f /etc/terminfo$term ]]
	then
		TERM_old=$TERM
		export TERM='xterm'
		[[ $TERM_old == *'256'* ]] && TERM+='-256color'

		G_WHIP_MENU_ARRAY=('0' 'Ignore for now, I will change the SSH clients terminal.')
		ncurses_term=
		if ! dpkg-query -s ncurses-term &> /dev/null
		then
			ncurses_term=' or install the "ncurses-term" APT package, which enables broader terminal support'
			G_WHIP_MENU_ARRAY+=('1' 'Install "ncurses-term" now to enable broader terminal support.')
			G_WHIP_DEFAULT_ITEM=1
		fi

		if G_PROGRAM_NAME='Unsupported SSH client terminal' G_WHIP_MENU "[WARNING] Your SSH client passed an unsupported terminal: TERM=$TERM_old
\nAs a workaround, we fooled the server by setting TERM=$TERM. This is not the cleanest solution as commands may use control sequences which are not supported by the current terminal.
\nPlease change your SSH clients terminal, respectively the passed \$TERM string$ncurses_term." && (( $G_WHIP_RETURNED_VALUE ))
		then
			if (( $UID ))
			then
				G_SUDO G_AGI ncurses-term
			else
				G_AGI ncurses-term
			fi
		fi
		unset -v TERM_old ncurses_term
	fi
	unset -v term

	# DietPi-Login: First run setup, autostarts and login banner
	# - Prevent call if $G_DIETPI_LOGIN has been set. E.g. when shell is called as subshell of G_EXEC or dietpi-login itself, we don't want autostart programs to be launched.
	[[ $G_DIETPI_LOGIN ]] || /boot/dietpi/dietpi-login
}
