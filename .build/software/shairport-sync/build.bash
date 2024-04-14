#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals

# -------------------------
# ------- AirPlay 1 -------
# -------------------------

# Build deps
# - Workaround for CI on Buster: Mask Avahi daemon service, since it can fail to start, failing the package install
(( $G_DISTRO == 5 )) && G_EXEC systemctl mask avahi-daemon
G_AGUP
G_AGDUG automake pkg-config make g++ libpopt-dev libconfig-dev libssl-dev libsoxr-dev libavahi-client-dev libasound2-dev libglib2.0-dev libmosquitto-dev avahi-daemon git libplist-dev libsodium-dev libgcrypt20-dev libavformat-dev xxd
(( $G_DISTRO == 5 )) && G_EXEC systemctl unmask avahi-daemon
adeps=('libc6' 'libasound2' 'libavahi-client3' 'libsoxr0' 'libconfig9' 'libpopt0' 'libglib2.0-0' 'libmosquitto1' 'avahi-daemon')
adeps2=('libplist3' 'libsodium23' 'libgcrypt20')
case $G_DISTRO in
	5|6) adeps+=('libssl1.1'); adeps2+=('libavcodec58');;
	7) adeps+=('libssl3'); adeps2+=('libavcodec59');;
	8) adeps+=('libssl3'); adeps2+=('libavcodec60');;
	*) G_DIETPI-NOTIFY 1 "Unsupported distro version: $G_DISTRO_NAME (ID=$G_DISTRO)"; exit 1;;
esac
for i in "${adeps[@]}" "${adeps2[@]}"
do
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Sid: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || dpkg-query -s "${i}t64" &> /dev/null && continue
	G_DIETPI-NOTIFY 1 "Expected dependency package was not installed: $i"
	exit 1
done

# Obtain latest version
name='shairport-sync'
name_pretty='Shairport Sync'
repo='https://github.com/mikebrady/shairport-sync'
version=$(curl -sSf 'https://api.github.com/repos/mikebrady/shairport-sync/releases/latest' | mawk -F\" '/^  "tag_name"/{print $4;exit}')
[[ $version ]] || { G_DIETPI-NOTIFY 1 "No latest $name_pretty version found, aborting ..."; exit 1; }

# Download
G_DIETPI-NOTIFY 2 "Downloading $name_pretty version \e[33m$version"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "$repo/archive/$version.tar.gz"
[[ -d $name-$version ]] && G_EXEC rm -R "$name-$version"
G_EXEC tar xf "$version.tar.gz"
G_EXEC rm "$version.tar.gz"

# Compile
G_DIETPI-NOTIFY 2 "Compiling $name_pretty"
G_EXEC cd "$name-$version"
G_EXEC_OUTPUT=1 G_EXEC autoreconf -fiW all
CFLAGS='-g0 -O3' CXXFLAGS='-g0 -O3' G_EXEC_OUTPUT=1 G_EXEC ./configure --with-alsa --with-avahi --with-ssl=openssl --with-soxr --with-metadata --with-systemd --with-dbus-interface --with-mpris-interface --with-mqtt-client --with-pipe --with-stdout
G_EXEC_OUTPUT=1 G_EXEC make
G_EXEC strip --remove-section=.comment --remove-section=.note "$name"

# Package dir: In case of Raspbian, force ARMv6
G_DIETPI-NOTIFY 2 "Preparing $name_pretty DEB package directory"
G_EXEC cd /tmp
grep -q '^ID=raspbian' /etc/os-release && G_HW_ARCH_NAME='armv6l'
DIR="${name}_$G_HW_ARCH_NAME"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
# - Control files, systemd service, executable, configs, copyright
G_EXEC mkdir -p "$DIR/"{DEBIAN,lib/systemd/system,usr/local/{bin,etc,"share/doc/$name"},etc/dbus-1/system.d}

# Binary
G_EXEC cp -a "$name-$version/$name" "$DIR/usr/local/bin/"

# Copyright
G_EXEC cp "$name-$version/LICENSES" "$DIR/usr/local/share/doc/$name/copyright"

# systemd service
G_EXEC cp "$name-$version/scripts/$name.service-avahi" "$DIR/lib/systemd/system/$name.service"

# dbus/mpris permissions
G_EXEC cp "$name-$version/scripts/shairport-sync-dbus-policy.conf" "$DIR/etc/dbus-1/system.d/"
G_EXEC cp "$name-$version/scripts/shairport-sync-mpris-policy.conf" "$DIR/etc/dbus-1/system.d/"

# Config file: https://github.com/mikebrady/shairport-sync/blob/master/scripts/shairport-sync.conf
cat << '_EOF_' > "$DIR/usr/local/etc/$name.conf"
// Sample Configuration File for Shairport Sync
// Commented out settings are generally the defaults, except where noted.
// See the individual sections for details.

// General Settings
general =
{
//	name = "%H"; // This means "Hostname" -- see below. This is the name the service will advertise to iTunes.
//		The default is "Hostname" -- i.e. the machine's hostname with the first letter capitalised (ASCII only.)
//		You can use the following substitutions:
//				%h for the hostname,
//				%H for the Hostname (i.e. with first letter capitalised (ASCII only)),
//				%v for the version number, e.g. 3.0 and
//				%V for the full version string, e.g. 3.3-OpenSSL-Avahi-ALSA-soxr-metadata-sysconfdir:/etc
//		Overall length can not exceed 50 characters. Example: "Shairport Sync %v on %H".
//	password = "secret"; // (AirPlay 1 only) leave this commented out if you don't want to require a password
//	interpolation = "auto"; // aka "stuffing". Default is "auto". Alternatives are "basic" or "soxr". Choose "soxr" only if you have a reasonably fast processor.
//	output_backend = "alsa"; // Run "shairport-sync -h" to get a list of all output_backends, e.g. "alsa", "pipe", "stdout". The default is the first one.
//	mdns_backend = "avahi"; // Run "shairport-sync -h" to get a list of all mdns_backends. The default is the first one.
//	interface = "name"; // Use this advanced setting to specify the interface on which Shairport Sync should provide its service. Leave it commented out to get the default, which is to select the interface(s) automatically.
//	port = <number>; // Listen for service requests on this port. 5000 for AirPlay 1, 7000 for AirPlay 2
//	udp_port_base = 6001; // (AirPlay 1 only) start allocating UDP ports from this port number when needed
//	udp_port_range = 10; // (AirPlay 1 only) look for free ports in this number of places, starting at the UDP port base. Allow at least 10, though only three are needed in a steady state.
//	airplay_device_id_offset = 0; // (AirPlay 2 only) add this to the default airplay_device_id calculated from one of the device's MAC address
//	airplay_device_id = 0x<six-digit_hexadecimal_number>L; // (AirPlay 2 only) use this as the airplay_device_id e.g. 0xDCA632D4E8F3L -- remember the "L" at the end as it's a 64-bit quantity!
//	regtype = "<string>"; // Use this advanced setting to set the service type and transport to be advertised by Zeroconf/Bonjour. Default is "_raop._tcp" for AirPlay 1, "_airplay._tcp" for AirPlay 2.

//	drift_tolerance_in_seconds = 0.002; // allow a timing error of this number of seconds of drift away from exact synchronisation before attempting to correct it
//	resync_threshold_in_seconds = 0.050; // a synchronisation error greater than this number of seconds will cause resynchronisation; 0 disables it
//	resync_recovery_time_in_seconds = 0.100; // allow this extra time to recover after a late resync. Increase the value, possibly to 0.5, in a virtual machine.
//	playback_mode = "stereo"; // This can be "stereo", "mono", "reverse stereo", "both left" or "both right". Default is "stereo".
//	alac_decoder = "hammerton"; // This can be "hammerton" or "apple". This advanced setting allows you to choose
//		the original Shairport decoder by David Hammerton or the Apple Lossless Audio Codec (ALAC) decoder written by Apple.
//		If you build Shairport Sync with the flag --with-apple-alac, the Apple ALAC decoder will be chosen by default.

//	ignore_volume_control = "no"; // set this to "yes" if you want the volume to be at 100% no matter what the source's volume control is set to.
//	volume_range_db = 60 ; // use this advanced setting to set the range, in dB, you want between the maximum volume and the minimum volume. Range is 30 to 150 dB. Leave it commented out to use mixer's native range.
//	volume_max_db = 0.0 ; // use this advanced setting, which must have a decimal point in it, to set the maximum volume, in dB, you wish to use.
//		The setting is for the hardware mixer, if chosen, or the software mixer otherwise. The value must be in the mixer's range (0.0 to -96.2 for the software mixer).
//		Leave it commented out to use mixer's maximum volume.
//	volume_control_profile = "standard" ; // use this advanced setting to specify how the airplay volume is transferred to the mixer volume.
//		"standard" makes the volume change more quickly at lower volumes and slower at higher volumes.
//		"flat" makes the volume change at the same rate at all volumes.
//		"dasl_tapered" is similar to "standard" - it makes the volume change more quickly at lower volumes and slower at higher volumes.
//			The intention behind dasl_tapered is that a given percentage change in volume should result in the same percentage change in
//			perceived loudness. For instance, doubling the volume level should result in doubling the perceived loudness.
//			With the range of AirPlay volume being from -30 to 0, doubling the volume from -22.5 to -15 results in an increase of 10 dB.
//			Similarly, doubling the volume from -15 to 0 results in an increase of 10 dB.
//			For compatibility with mixers having a restricted attenuation range (e.g. 30 dB), "dasl_tapered" will switch to a flat profile at low AirPlay volumes.
//	volume_control_combined_hardware_priority = "no"; // when extending the volume range by combining the built-in software attenuator with the hardware mixer attenuator, set this to "yes" to reduce volume by using the hardware mixer first, then the built-in software attenuator.

//	default_airplay_volume = -24.0; // this is the suggested volume after a reset or after the high_volume_threshold has been exceed and the high_volume_idle_timeout_in_minutes has passed

//	The following settings are for dealing with potentially surprising high ("very loud") volume levels.
//	When a new play session starts, it usually requests a suggested volume level from Shairport Sync. This is normally the volume level of the last session.
//	This can cause unpleasant surprises if the last session was (a) very loud and (b) a long time ago.
//	Thus, the user could be unpleasantly surprised by the volume level of the new session.

//	To deal with this, when the last session volume is "very loud", the following two settings will lower the suggested volume after a period of idleness:

//	high_threshold_airplay_volume = -16.0; // airplay volume greater or equal to this is "very loud"
//	high_volume_idle_timeout_in_minutes = 0; // if the current volume is "very loud" and the device is not playing for more than this time, suggest the default volume for new connections instead of the current volume.
//		Note 1: This timeout is set to 0 by default to disable this feature. Set it to some positive number, e.g. 180 to activate the feature.
//		Note 2: Not all applications use the suggested volume: MacOS Music and Mac OS System Sounds use their own settings.

//	run_this_when_volume_is_set = "/full/path/to/application/and/args"; //	Run the specified application whenever the volume control is set or changed.
//		The desired AirPlay volume is appended to the end of the command line – leave a space if you want it treated as an extra argument.
//		AirPlay volume goes from 0.0 to -30.0 and -144.0 means "mute".

//	audio_backend_latency_offset_in_seconds = 0.0; // This is added to the latency requested by the player to delay or advance the output by a fixed amount.
//		Use it, for example, to compensate for a fixed delay in the audio back end.
//		E.g. if the output device, e.g. a soundbar, takes 100 ms to process audio, set this to -0.1 to deliver the audio
//		to the output device 100 ms early, allowing it time to process the audio and output it perfectly in sync.
//	audio_backend_buffer_desired_length_in_seconds = 0.2; // If set too small, buffer underflow occurs on low-powered machines.
//		Too long and the response time to volume changes becomes annoying.
//		Default is 0.2 seconds in the alsa backend, 0.35 seconds in the pa backend and 1.0 seconds otherwise.
//	audio_backend_buffer_interpolation_threshold_in_seconds = 0.075; // Advanced feature. If the buffer size drops below this, stop using time-consuming interpolation like soxr to avoid dropouts due to underrun.
//	audio_backend_silent_lead_in_time = "auto"; // This optional advanced setting, either "auto" or a positive number, sets the length of the period of silence that precedes the start of the audio.
//		The default is "auto" -- the silent lead-in starts as soon as the player starts sending packets.
//		Values greater than the latency are ignored. Values that are too low will affect initial synchronisation.

//	dbus_service_bus = "system"; // The Shairport Sync dbus interface, will appear
//		as "org.gnome.ShairportSync" on the whichever bus you specify here: "system" (default) or "session".
//	mpris_service_bus = "system"; // The Shairport Sync mpris interface, will appear
//		as "org.gnome.ShairportSync" on the whichever bus you specify here: "system" (default) or "session".

//	resend_control_first_check_time = 0.10; // Use this optional advanced setting to set the wait time in seconds before deciding a packet is missing.
//	resend_control_check_interval_time = 0.25; //  Use this optional advanced setting to set the time in seconds between requests for a missing packet.
//	resend_control_last_check_time = 0.10; // Use this optional advanced setting to set the latest time, in seconds, by which the last check should be done before the estimated time of a missing packet's transfer to the output buffer.
//	missing_port_dacp_scan_interval_seconds = 2.0; // Use this optional advanced setting to set the time interval between scans for a DACP port number if no port number has been provided by the player for remote control commands
};

// Advanced parameters for controlling how Shairport Sync stays active and how it runs a session
sessioncontrol =
{
//	"active" state starts when play begins and ends when the active_state_timeout has elapsed after play ends, unless another play session starts before the timeout has fully elapsed.
//	run_this_before_entering_active_state = "/full/path/to/application and args"; // make sure the application has executable permission. If it's a script, include the shebang (#!/bin/...) on the first line
//	run_this_after_exiting_active_state = "/full/path/to/application and args"; // make sure the application has executable permission. If it's a script, include the shebang (#!/bin/...) on the first line
//	active_state_timeout = 10.0; // wait for this number of seconds after play ends before leaving the active state, unless another play session begins.

//	run_this_before_play_begins = "/full/path/to/application and args"; // make sure the application has executable permission. If it's a script, include the shebang (#!/bin/...) on the first line
//	run_this_after_play_ends = "/full/path/to/application and args"; // make sure the application has executable permission. If it's a script, include the shebang (#!/bin/...) on the first line

//	run_this_if_an_unfixable_error_is_detected = "/full/path/to/application and args"; // if a problem occurs that can't be cleared by Shairport Sync itself, hook a program on here to deal with it. An error code-string is passed as the last argument.
//	  Many of these "unfixable" problems are caused by malfunctioning output devices, and sometimes it is necessary to restart the whole device to clear the problem.
//	  You could hook on a program to do this automatically, but beware -- the device may then power off and restart without warning!
//	wait_for_completion = "no"; // set to "yes" to get Shairport Sync to wait until the "run_this..." applications have terminated before continuing

//	allow_session_interruption = "no"; // set to "yes" to allow another device to interrupt Shairport Sync while it's playing from an existing audio source
//	session_timeout = 120; // wait for this number of seconds after a source disappears before terminating the session and becoming available again.
};

// These are parameters for the "alsa" audio back end.
alsa =
{
//	output_device = "default"; // the name of the alsa output device. Use "shairport-sync -h" to discover the names of ALSA hardware devices. Use "alsamixer" or "aplay" to find out the names of devices, mixers, etc.
//	mixer_control_name = "PCM"; // the name of the mixer to use to adjust output volume. No default. If not specified, no mixer is used and volume in adjusted in software.
//	mixer_control_index = 0; // the index of the mixer to use to adjust output volume. Default is 0. The mixer is fully identified by the combination of the mixer_control_name and the mixer_control_index, e.g. "PCM",0 would be such a specification.
//	mixer_device = "default"; // the mixer_device default is whatever the output_device is. Normally you wouldn't have to use this.

//	output_rate = "auto"; // can be "auto", 44100, 88200, 176400 or 352800, but the device must have the capability.
//	output_format = "auto"; // can be "auto", "U8", "S8", "S16", "S16_LE", "S16_BE", "S24", "S24_LE", "S24_BE", "S24_3LE", "S24_3BE", "S32", "S32_LE" or "S32_BE" but the device must have the capability. Except where stated using (*LE or *BE), endianness matches that of the processor.

//	disable_synchronization = "no"; // Set to "yes" to disable synchronization. Default is "no" This is really meant for troubleshootingG.

//	period_size = <number>; // Use this optional advanced setting to set the alsa period size near to this value
//	buffer_size = <number>; // Use this optional advanced setting to set the alsa buffer size near to this value
//	use_mmap_if_available = "yes"; // Use this optional advanced setting to control whether MMAP-based output is used to communicate  with the DAC. Default is "yes"
//	use_hardware_mute_if_available = "no"; // Use this optional advanced setting to control whether the hardware in the DAC is used for muting. Default is "no", for compatibility with other audio players.
//	maximum_stall_time = 0.200; // Use this optional advanced setting to control how long to wait for data to be consumed by the output device before considering it an error. It should never approach 200 ms.
//	use_precision_timing = "auto"; // Use this optional advanced setting to control how Shairport Sync gathers timing information. When set to "auto", if the output device is a real hardware device, precision timing will be used. Choose "no" for more compatible standard timing, choose "yes" to force the use of precision timing, which may cause problems.

//	disable_standby_mode = "never"; // This setting prevents the DAC from entering the standby mode. Some DACs make small "popping" noises when they go in and out of standby mode. Settings can be: "always", "auto" or "never". Default is "never", but only for backwards compatibility. The "auto" setting prevents entry to standby mode while Shairport Sync is in the "active" mode. You can use "yes" instead of "always" and "no" instead of "never".
//	disable_standby_mode_silence_threshold = 0.040; // Use this optional advanced setting to control how little audio should remain in the output buffer before the disable_standby code should start sending silence to the output device.
//	disable_standby_mode_silence_scan_interval = 0.004; // Use this optional advanced setting to control how often the amount of audio remaining in the output buffer should be checked.
};

// Parameters for the "pipe" audio back end, a back end that directs raw CD-format audio output to a pipe. No interpolation is done.
pipe =
{
//	name = "/tmp/shairport-sync-audio"; // this is the default
};

// There are no configuration file parameters for the "stdout" audio back end. No interpolation is done.

// How to deal with metadata, including artwork
metadata =
{
//	enabled = "yes"; // set this to yes to get Shairport Sync to solicit metadata from the source and to pass it on via a pipe
//	include_cover_art = "yes"; // set to "yes" to get Shairport Sync to solicit cover art from the source and pass it via the pipe. You must also set "enabled" to "yes".
//	cover_art_cache_directory = "/tmp/shairport-sync/.cache/coverart"; // artwork will be  stored in this directory if the dbus or MPRIS interfaces are enabled or if the MQTT client is in use. Set it to "" to prevent caching, which may be useful on some systems
//	pipe_name = "/tmp/shairport-sync-metadata";
//	pipe_timeout = 5000; // wait for this number of milliseconds for a blocked pipe to unblock before giving up
//	progress_interval = 0.0; // if non-zero, progress 'phbt' messages will be sent at the interval specified in seconds. A 'phb0' message will also be sent when the first audio frame of a play session is about to be played.
//		Each message consists of the RTPtime of a a frame of audio and the exact system time when it is to be played. The system time, in nanoseconds, is based the CLOCK_MONOTONIC_RAW of the machine -- if available -- or CLOCK_MONOTONIC otherwise.
//		Messages are sent when the frame is placed in the output device's buffer, thus, they will be _approximately_ 'audio_backend_buffer_desired_length_in_seconds' (default 0.2 seconds) ahead of time.
//	socket_address = "226.0.0.1"; // if set to a host name or IP address, UDP packets containing metadata will be sent to this address. May be a multicast address. "socket-port" must be non-zero and "enabled" must be set to yes"
//	socket_port = 5555; // if socket_address is set, the port to send UDP packets to
//	socket_msglength = 65000; // the maximum packet size for any UDP metadata. This will be clipped to be between 500 or 65000. The default is 500.
};

// How to enable the MQTT-metadata/remote-service
// Note that, for compatability with many MQTT brokers and applications,
// every message that has no extra data is given a
// payload consisting of the string "--".
// You can change this or you can enable empty payloads -- see below.
mqtt =
{
//	enabled = "no"; // set this to yes to enable the mqtt-metadata-service
//	hostname = "iot.eclipse.org"; // Hostname of the MQTT Broker
//	port = 1883; // Port on the MQTT Broker to connect to
//	username = NULL; //set this to a string to your username in order to enable username authentication
//	password = NULL; //set this to a string you your password in order to enable username & password authentication
//	capath = NULL; //set this to the folder with the CA-Certificates to be accepted for the server certificate. If not set, TLS is not used
//	cafile = NULL; //this may be used as an (exclusive) alternative to capath with a single file for all ca-certificates
//	certfile = NULL; //set this to a string to a user certificate to enable MQTT Client certificates. keyfile must also be set!
//	keyfile = NULL; //private key for MQTT Client authentication
//	topic = NULL; //MQTT topic where this instance of shairport-sync should publish. If not set, the general.name value is used.
//	publish_raw = "no"; //whether to publish all available metadata under the codes given in the 'metadata' docs.
//	publish_parsed = "no"; //whether to publish a small (but useful) subset of metadata under human-understandable topics
//	empty_payload_substitute = "--"; // MQTT messages with empty payloads often are invisible or have special significance to MQTT brokers and readers.
//    To avoid empty payload problems, the string here is used instead of any empty payload. Set it to the empty string -- "" -- to leave the payload empty.
//	Currently published topics:artist,album,title,genre,format,songalbum,volume,client_ip,
//	Additionally, messages at the topics play_start,play_end,play_flush,play_resume are published
//	publish_cover = "no"; //whether to publish the cover over mqtt in binary form. This may lead to a bit of load on the broker
//	enable_remote = "no"; //whether to remote control via MQTT. RC is available under `topic`/remote.
//	Available commands are "command", "beginff", "beginrew", "mutetoggle", "nextitem", "previtem", "pause", "playpause", "play", "stop", "playresume", "shuffle_songs", "volumedown", "volumeup"
};

// Diagnostic settings. These are for diagnostic and debugging only. Normally you should leave them commented out
diagnostics =
{
//	disable_resend_requests = "no"; // set this to yes to stop Shairport Sync from requesting the retransmission of missing packets. Default is "no".
//	log_output_to = "syslog"; // set this to "syslog" (default), "stderr" or "stdout" or a file or pipe path to specify were all logs, statistics and diagnostic messages are written to. If there's anything wrong with the file spec, output will be to "stderr".
//	statistics = "no"; // set to "yes" to print statistics in the log
//	log_verbosity = 0; // "0" means no debug verbosity, "3" is most verbose.
//	log_show_file_and_line = "yes"; // set this to yes if you want the file and line number of the message source in the log file
//	log_show_time_since_startup = "no"; // set this to yes if you want the time since startup in the debug message -- seconds down to nanoseconds
//	log_show_time_since_last_message = "yes"; // set this to yes if you want the time since the last debug message in the debug message -- seconds down to nanoseconds
//	drop_this_fraction_of_audio_packets = 0.0; // use this to simulate a noisy network where this fraction of UDP packets are lost in transmission. E.g. a value of 0.001 would mean an average of 0.1% of packets are lost, which is actually quite a high figure.
//	retain_cover_art = "no"; // artwork is deleted when its corresponding track has been played. Set this to "yes" to retain all artwork permanently. Warning -- your directory might fill up.
};
_EOF_

# Control files

# - conffiles
echo "/usr/local/etc/$name.conf" > "$DIR/DEBIAN/conffiles"

# - postinst
cat << _EOF_ > "$DIR/DEBIAN/postinst"
#!/bin/sh
if [ -d '/run/systemd/system' ]
then
	if getent passwd $name > /dev/null
	then
		echo 'Configuring $name_pretty service user ...'
		usermod -aG audio -d /nonexistent -s /usr/sbin/nologin $name
	else
		echo 'Creating $name_pretty service user ...'
		useradd -rMU -G audio -d /nonexistent -s /usr/sbin/nologin $name
	fi

	echo 'Configuring $name_pretty systemd service ...'
	systemctl unmask $name
	systemctl enable --now $name
fi
_EOF_

# - prerm
cat << _EOF_ > "$DIR/DEBIAN/prerm"
#!/bin/sh
if [ "\$1" = 'remove' ] && [ -d '/run/systemd/system' ] && [ -f '/lib/systemd/system/$name.service' ]
then
	echo 'Deconfiguring $name_pretty systemd service ...'
	systemctl unmask $name
	systemctl disable --now $name
fi
_EOF_

# - postrm
cat << _EOF_ > "$DIR/DEBIAN/postrm"
#!/bin/sh
if [ "\$1" = 'purge' ]
then
	if [ -d '/etc/systemd/system/$name.service.d' ]
	then
		echo 'Removing $name_pretty systemd service overrides ...'
		rm -Rv /etc/systemd/system/$name.service.d
	fi

	if getent passwd $name > /dev/null
	then
		echo 'Removing $name_pretty service user ...'
		userdel $name
	fi

	if getent group $name > /dev/null
	then
		echo 'Removing $name_pretty service group ...'
		groupdel $name
	fi
fi
_EOF_

G_EXEC chmod +x "$DIR/DEBIAN/"{postinst,prerm,postrm}

# - md5sums
find "$DIR" ! \( -path "$DIR/DEBIAN" -prune \) -type f -exec md5sum {} + | sed "s|$DIR/||" > "$DIR/DEBIAN/md5sums"

# - Obtain DEB dependency versions
DEPS_APT_VERSIONED=
for i in "${adeps[@]}"
do
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Sid: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || i+='t64'
	DEPS_APT_VERSIONED+=" $i (>= $(dpkg-query -Wf '${VERSION}' "$i")),"
done
DEPS_APT_VERSIONED=${DEPS_APT_VERSIONED%,}
# shellcheck disable=SC2001
[[ $G_HW_ARCH_NAME == 'armv6l' ]] && DEPS_APT_VERSIONED=$(sed 's/+rp[it][0-9]\+[^)]*)/)/g' <<< "$DEPS_APT_VERSIONED") || DEPS_APT_VERSIONED=$(sed 's/+b[0-9]\+)/)/g' <<< "$DEPS_APT_VERSIONED")

# - Obtain version suffix
G_EXEC curl -sSfo package.deb "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/${name}_$G_HW_ARCH_NAME.deb"
old_version=$(dpkg-deb -f package.deb Version)
G_EXEC rm package.deb
suffix=${old_version#*-dietpi}
[[ $old_version == "$version-"* ]] && suffix="dietpi$((suffix+1))" || suffix="dietpi1"

# - control
cat << _EOF_ > "$DIR/DEBIAN/control"
Package: $name
Version: $version-$suffix
Architecture: $(dpkg --print-architecture)
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -u '+%a, %d %b %Y %T %z')
Standards-Version: 4.6.2.0
Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')
Depends:$DEPS_APT_VERSIONED
Conflicts: $name-airplay2
Section: sound
Priority: optional
Homepage: $repo
Vcs-Git: $repo.git
Vcs-Browser: $repo
Description: AirPlay audio player
 Plays audio streamed from iTunes, iOS devices and third-party AirPlay
 sources such as ForkedDaapd and others. Audio played by a Shairport
 Sync-powered device stays synchronised with the source and hence with
 similar devices playing the same source. In this way, synchronised
 multi-room audio is possible without difficulty.
 .
 Shairport Sync does not support AirPlay video or photo streaming.
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"

# -------------------------
# ------- AirPlay 2 -------
# -------------------------

# NQPTP
G_EXEC cd /tmp
G_EXEC_OUTPUT=1 G_EXEC git clone 'https://github.com/mikebrady/nqptp'
G_EXEC cd nqptp
G_EXEC_OUTPUT=1 G_EXEC autoreconf -fiW all
CFLAGS='-g0 -O3' CXXFLAGS='-g0 -O3' G_EXEC_OUTPUT=1 G_EXEC ./configure --with-systemd-startup
G_EXEC_OUTPUT=1 G_EXEC make
G_EXEC strip --remove-section=.comment --remove-section=.note nqptp

# Compile
G_EXEC cd "../$name-$version"
G_EXEC_OUTPUT=1 G_EXEC make clean
G_EXEC_OUTPUT=1 G_EXEC autoreconf -fiW all
CFLAGS='-g0 -O3' CXXFLAGS='-g0 -O3' G_EXEC_OUTPUT=1 G_EXEC ./configure --with-alsa --with-avahi --with-ssl=openssl --with-soxr --with-metadata --with-systemd --with-dbus-interface --with-mpris-interface --with-mqtt-client --with-pipe --with-stdout --with-airplay-2
G_EXEC_OUTPUT=1 G_EXEC make
G_EXEC strip --remove-section=.comment --remove-section=.note "$name"

# Package dir
G_EXEC cd /tmp
G_EXEC mv "$DIR" "${DIR/sync_/sync-airplay2_}"
DIR=${DIR/sync_/sync-airplay2_}

# Binary
G_EXEC cp -a "$name-$version/$name" "$DIR/usr/local/bin/"

# NQPTP
G_EXEC cp -a nqptp/nqptp "$DIR/usr/local/bin/"
G_EXEC cp nqptp/nqptp.service "$DIR/lib/systemd/system/"

# Control files
# - postinst
cat << _EOF_ > "$DIR/DEBIAN/postinst"
#!/bin/sh
if [ -d '/run/systemd/system' ]
then
	if getent passwd $name > /dev/null
	then
		echo 'Configuring $name_pretty service user ...'
		usermod -aG audio -d /nonexistent -s /usr/sbin/nologin $name
	else
		echo 'Creating $name_pretty service user ...'
		useradd -rMU -G audio -d /nonexistent -s /usr/sbin/nologin $name
	fi

	if getent passwd nqptp > /dev/null
	then
		echo 'Configuring NQPTP service user ...'
		usermod -d /nonexistent -s /usr/sbin/nologin nqptp
	else
		echo 'Creating NQPTP service user ...'
		useradd -rMU -d /nonexistent -s /usr/sbin/nologin nqptp
	fi

	echo 'Configuring NQPTP systemd service ...'
	systemctl unmask nqptp
	systemctl enable --now nqptp

	echo 'Configuring $name_pretty systemd service ...'
	systemctl unmask $name
	systemctl enable --now $name
fi
_EOF_

# - prerm
cat << _EOF_ > "$DIR/DEBIAN/prerm"
#!/bin/sh
if [ "$1" = 'remove' ] && [ -d '/run/systemd/system' ]
then
	if [ -f '/lib/systemd/system/$name.service' ]
	then
		echo 'Deconfiguring $name_pretty systemd service ...'
		systemctl unmask $name
		systemctl disable --now $name
	fi

	if [ -f '/lib/systemd/system/nqptp.service' ]
	then
		echo 'Deconfiguring NQPTP systemd service ...'
		systemctl unmask nqptp
		systemctl disable --now nqptp
	fi
fi
_EOF_

# - postrm
cat << _EOF_ > "$DIR/DEBIAN/postrm"
#!/bin/sh
if [ "$1" = 'purge' ]
then
	if [ -d '/etc/systemd/system/$name.service.d' ]
	then
		echo 'Removing $name_pretty systemd service overrides ...'
		rm -Rv /etc/systemd/system/$name.service.d
	fi

	if [ -d '/etc/systemd/system/nqptp.service.d' ]
	then
		echo 'Removing NQPTP systemd service overrides ...'
		rm -Rv /etc/systemd/system/nqptp.service.d
	fi

	if getent passwd $name > /dev/null
	then
		echo 'Removing $name_pretty service user ...'
		userdel $name
	fi

	if getent group $name > /dev/null
	then
		echo 'Removing $name_pretty service group ...'
		groupdel $name
	fi

	if getent passwd nqptp > /dev/null
	then
		echo 'Removing NQPTP service user ...'
		userdel nqptp
	fi

	if getent group nqptp > /dev/null
	then
		echo 'Removing NQPTP service group ...'
		groupdel nqptp
	fi
fi
_EOF_

# - md5sums
find "$DIR" ! \( -path "$DIR/DEBIAN" -prune \) -type f -exec md5sum {} + | sed "s|$DIR/||" > "$DIR/DEBIAN/md5sums"

# - Obtain DEB dependency versions
for i in "${adeps2[@]}"
do
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Sid: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || i+='t64'
	DEPS_APT_VERSIONED+=", $i (>= $(dpkg-query -Wf '${VERSION}' "$i"))"
done
# shellcheck disable=SC2001
[[ $G_HW_ARCH_NAME == 'armv6l' ]] && DEPS_APT_VERSIONED=$(sed 's/+rp[it][0-9]\+[^)]*)/)/g' <<< "$DEPS_APT_VERSIONED") || DEPS_APT_VERSIONED=$(sed 's/+b[0-9]\+)/)/g' <<< "$DEPS_APT_VERSIONED")

# - control
cat << _EOF_ > "$DIR/DEBIAN/control"
Package: $name-airplay2
Version: $version-$suffix
Architecture: $(dpkg --print-architecture)
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -uR)
Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')
Depends:$DEPS_APT_VERSIONED
Conflicts: $name
Section: sound
Priority: optional
Homepage: $repo
Description: AirPlay audio player
 Plays audio streamed from iTunes, iOS devices and third-party AirPlay
 sources such as ForkedDaapd and others. Audio played by a Shairport
 Sync-powered device stays synchronised with the source and hence with
 similar devices playing the same source. In this way, synchronised
 multi-room audio is possible without difficulty.
 .
 This package was built with AirPlay 2 support and contains the required
 NQPTP daemon. For details and limitations read the following info:
 https://github.com/mikebrady/shairport-sync/blob/master/AIRPLAY2.md
 .
 Shairport Sync does not support AirPlay video or photo streaming.
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"

# Cleanup
G_EXEC rm -R "$name-$version" nqptp "$DIR"

exit 0
}
