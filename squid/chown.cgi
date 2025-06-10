#!/usr/local/bin/perl
# chown.cgi
# Change permissions on cache/log/pid files after a user change

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'admopts'} || &error($text{'eadm_ecannot'});

&ui_print_unbuffered_header(undef, $text{'chown_header'}, "");
my $conf = &get_config();

# Stop squid
my $pid = &is_squid_running();
my $stopped = 0;
if ($pid && kill(0, $pid)) {
	print "<p>$text{'chown_stop'}<br>\n";
	system("$config{'squid_path'} -f $config{'squid_conf'} ".
	       "-k shutdown >/dev/null 2>&1");
	for(my $i=0; $i<40; $i++) {
		if (!kill(0, $pid)) { last; }
		sleep(1);
		}
	print "$text{'chown_done'}<br>\n";
	$stopped++;
	}

# Change ownership
print "<p>$text{'chown_chown'}<br>\n";
my ($user, $group) = &get_squid_user($conf);
&chown_files($user, $group, $conf);
print "$text{'chown_done'}<br>\n";

# Re-start Squid
if ($stopped) {
	print "<p>$text{'chown_restart'}<br>\n";
	my $temp = &transname();
	system("$config{'squid_path'} -sY -f $config{'squid_conf'} >$temp 2>&1 </dev/null &");
	sleep(3);
	my $errs = &read_file_contents($temp);
	unlink($temp);
	if ($errs) {
		system("$config{'squid_path'} -k shutdown -f $config{'squid_conf'} >/dev/null 2>&1");
		print "$text{'chown_failrestart'}<br>\n";
		print "<pre>$errs</pre>\n";
		}
	print "$text{'chown_done'}<br>\n";
	}

&ui_print_footer("", $text{'chown_return'});

