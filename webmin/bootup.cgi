#!/usr/local/bin/perl
# bootup.cgi
# Create, enable or disable webmin startup at boot time

require './webmin-lib.pl';
&foreign_require("init");
&ReadParse();
my %miniserv;
&get_miniserv_config(\%miniserv);

if ($in{'boot'}) {
	# Enable starting at boot
	$start = "$config_directory/start";
	if ($init::init_mode eq "launchd") {
		# Launchd forks automatically
		$start .= " --nofork";
		$fork = 0;
		}
	else {
		$fork = 1;
		}
	$stop = "$config_directory/stop";
	$status = <<EOF;
pidfile=`grep "^pidfile=" $config_directory/miniserv.conf | sed -e 's/pidfile=//g'`
if [ -s \$pidfile ]; then
	pid=`cat \$pidfile`
	kill -0 \$pid >/dev/null 2>&1
	if [ "\$?" = "0" ]; then
		echo "webmin (pid \$pid) is running"
		RETVAL=0
	else
		echo "webmin is stopped"
		RETVAL=1
	fi
else
	echo "webmin is stopped"
	RETVAL=1
fi
EOF
	&init::enable_at_boot("webmin", "Start or stop Webmin",
			      $start, $stop, $status,
			      { 'fork' => $fork,
				'pidfile' => $miniserv{'pidfile'} });
	}
else {
	# Disable starting at boot
	&init::disable_at_boot("webmin");
	}
&redirect("");

