# /var/lib/dietpi/postboot.d is implemented by DietPi and allows to run scripts at the end of the boot process:
# - /etc/systemd/system/dietpi-postboot.service => /boot/dietpi/postboot => /var/lib/dietpi/postboot.d/*
# There are nearly no restrictions about file names and permissions:
# - All files (besides this "readme.txt" and dot files ".filename") are executed as root user.
# - Execute permissions are automatically added.
# NB: This delays the login prompt by the time the script takes, hence it must not be used for long-term processes, but only for oneshot tasks.
