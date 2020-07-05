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
	[[ -t 0 && $PS1 && $- == *'i'* ]] || return 0

	# DietPi-Globals: dietpi-* aliases, G_* functions and variables
	. /boot/dietpi/func/dietpi-globals || { echo -e '[\e[31mFAILED\e[0m] DietPi-Login | Failed to load DietPi-Globals. Skipping DietPi login scripts...'; return 1; }

	# "G_DIETPI-NOFITY -2 message" starts a process animation. If scripts fail to kill the animation, e.g. cancelled by user, terminal bash prompt has to do it as last resort.
	[[ $PROMPT_COMMAND == *'dietpi-process.pid'* ]] || PROMPT_COMMAND="[[ -w '/tmp/dietpi-process.pid' ]] && rm -f /tmp/dietpi-process.pid &> /dev/null && echo -ne '\r\e[J'; $PROMPT_COMMAND"

	# Workaround if SSH client overrides locale with "POSIX" fallback: https://github.com/MichaIng/DietPi/issues/1540#issuecomment-367066178
	if [[ $(locale) == *'POSIX'* ]]; then

		current_locale=$(sed -n '/^[[:blank:]]*AUTO_SETUP_LOCALE=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
		export LC_ALL=${current_locale:-C.UTF-8}
		unset current_locale

	fi

	# Workaround if SSH client sets an unsupported $TERM string: https://github.com/MichaIng/DietPi/issues/2034
	if [[ $SSH_TTY ]] && ! toe -a | grep -q "^${TERM}[[:blank:]]"; then

		TERM_old=$TERM
		[[ $TERM == *'256'* ]] && export TERM='xterm-256color' || export TERM='xterm'

		G_WHIP_MENU_ARRAY=('0' 'Ignore for now, I will change the SSH clients terminal.')
		ncurses_term=
		if ! dpkg-query -s ncurses-term &> /dev/null; then

			ncurses_term=' or install the "ncurses-term" APT packages, which enables a wider terminal support'
			G_WHIP_MENU_ARRAY+=('1' 'Install "ncurses-term" now to enable a wider terminal support.')
			G_WHIP_DEFAULT_ITEM=1

		fi

		G_PROGRAM_NAME='Unsupported SSH client terminal' G_WHIP_MENU "[WARNING] Your SSH client passed an unsupported terminal: TERM=$TERM_old\n
As a workaround we fooled the server by setting: TERM=$TERM. This is not the cleanest solution, since commands might expect colours or formats, that are not supported by the actual terminal.\n
Please change your SSH clients terminal, respectively the passed \$TERM string$ncurses_term." && (( $G_WHIP_RETURNED_VALUE )) && G_AGI ncurses-term
		unset TERM_old ncurses_term

	fi

	# DietPi-Login: First run setup, autostarts and login banner
	# - Prevent call if $G_DIETPI_LOGIN has been set. E.g. when shell is called as subshell of G_EXEC or dietpi-login itself, we don't want autostart programs to be launched.
	[[ $G_DIETPI_LOGIN ]] || /boot/dietpi/dietpi-login
}
