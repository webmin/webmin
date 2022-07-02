#!/usr/local/bin/perl
# clear.cgi
# Delete the cache, chown the directory to the correct user and re-run squid -z

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'rebuild'} || &error($text{'clear_ecannot'});
&ReadParse();
$config{'cache_dir'} =~ /^\/\S+/ || &error("Cache directory not set");
my $conf = &get_config();

if (!$in{'confirm'}) {
	# Ask the user if he is sure
	&ui_print_header(undef, $text{'clear_header'}, "");

	print &ui_confirmation_form(
		"clear.cgi",
		$text{'clear_msgclear'}."<br>".$text{'clear_msgclear2'},
		[],
		[ [ 'confirm', $text{'clear_buttclear'} ] ]);

	if (&has_command($config{'squidclient'})) {
		# Show form to clear just one URL
		print &ui_hr();
		print &ui_form_start("purge.cgi");
		print "<b>$text{'clear_url'}</b>\n";
		print &ui_textbox("url", undef, 50),"\n";
		print &ui_submit($text{'clear_ok'}),"<br>\n";
		print &ui_form_end();
		}

	&ui_print_footer("", $text{'clear_return'});
	exit;
	}

&ui_print_unbuffered_header(undef, $text{'clear_header'}, "");

# Stop squid (if running)
my $pid = &is_squid_running();
my $stopped = 0;
if ($pid && kill(0, $pid)) {
	print "$text{'clear_stop'}<br>\n";
	&system_logged("$config{'squid_path'} -f $config{'squid_conf'} ".
	               "-k shutdown >/dev/null 2>&1");
	for(my $i=0; $i<40; $i++) {
		if (!kill(0, $pid)) { last; }
		sleep(1);
		}
	print "$text{'clear_done'}<p>\n";
	$stopped++;
	}

# Get list of cache dirs
my @caches;
if (my @cachestruct = &find_config("cache_dir", $conf)) {
	if ($squid_version >= 2.3) {
		@caches = map { $_->{'values'}->[1] } @cachestruct;
		}
	else {
		@caches = map { $_->{'values'}->[0] } @cachestruct;
		}
	}
else {
	@caches = ( $config{'cache_dir'} );
	}

# Delete old cache files and re-create with same permissions!
print "$text{'clear_del'}<br>\n";
foreach my $c (@caches) {
	my @st = stat($c);
	if (@st) {
		&system_logged("rm -rf ".quotemeta($c)."/* >/dev/null 2>&1");
		#mkdir($c, 0755);	# only remove contents
		#chown($st[4], $st[5], $c);
		#chmod($st[2], $c);
		}
	}
print "$text{'clear_done'}<p>\n";

my $cmd = "$config{'squid_path'} -f $config{'squid_conf'} -z";
print &text('clear_init',$cmd)."<br>\n";
print "<pre>\n";
&additional_log('exec', undef, $cmd);
open(INIT, "$cmd 2>&1 |");
while(<INIT>) {
	print &html_escape($_);
	}
close(INIT);
print "</pre>\n";
print "$text{'clear_done'}<p>\n";

# Try to re-start squid
if ($stopped) {
	my $temp = &transname();
	&system_logged("$config{'squid_path'} -sY -f $config{'squid_conf'} >$temp 2>&1 </dev/null &");
	sleep(3);
	my $errs = &read_file_contents($temp);
	unlink($temp);
	if ($errs) {
		&system_logged("$config{'squid_path'} -k shutdown -f $config{'squid_conf'} >/dev/null 2>&1");
		print "$text{'clear_failrestart'}<br>\n";
		print "<pre>$errs</pre>\n";
		}
	}

&webmin_log("clear");
&ui_print_footer("", $text{'clear_return'});

