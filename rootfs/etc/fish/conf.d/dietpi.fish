# Copied from /etc/bashrc.d/dietpi.bash
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
alias dietpi-nordvpn='echo "DietPi-NordVPN has been renamed to DietPi-VPN. Please use the \"dietpi-vpn\" command."'
alias dietpi-vpn='/boot/dietpi/dietpi-vpn'
alias dietpi-ddns='/boot/dietpi/dietpi-ddns'
alias cpu='/boot/dietpi/dietpi-cpuinfo'
alias 1337='echo "Indeed, you are =)"'


function fish_greeting
        /boot/dietpi/dietpi-login
end
