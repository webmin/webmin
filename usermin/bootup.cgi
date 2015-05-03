#!/usr/local/bin/perl
# bootup.cgi
# Create, enable or disable usermin startup at boot time

require './usermin-lib.pl';
$access{'bootup'} || &error($text{'bootup_ecannot'});
&foreign_require("init");
&ReadParse();

if ($in{'boot'}) {
	# Enable starting at boot
	$start = "$config{'usermin_dir'}/start";
	if ($init::init_mode eq "launchd") {
		# Launchd forks automatically
		$start .= " --nofork";
		}
	$stop = "$config{'usermin_dir'}/stop";
	$status = <<EOF;
pidfile=`grep "^pidfile=" $config{'usermin_dir'}/miniserv.conf | sed -e 's/pidfile=//g'`
if [ -s \$pidfile ]; then
	pid=`cat \$pidfile`
	kill -0 \$pid >/dev/null 2>&1
	if [ "\$?" = "0" ]; then
		echo "usermin (pid \$pid) is running"
		RETVAL=0
	else
		echo "usermin is stopped"
		RETVAL=1
	fi
else
	echo "usermin is stopped"
	RETVAL=1
fi
EOF
	&init::enable_at_boot("usermin", "Start or stop Usermin",
			      $start, $stop, $status);
	}
else {
	# Disable starting at boot
	&init::disable_at_boot("usermin");
	}
&redirect("");

