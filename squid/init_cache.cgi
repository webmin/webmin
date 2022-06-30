#!/usr/local/bin/perl
# init_cache.cgi
# Initialize the cache by running squid with the -z option

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'rebuild'} || &error($text{'icache_ecannot'});
&ReadParse();
&error_setup($text{'icache_ftic'});

&lock_file($config{'squid_conf'});
my $conf = &get_config();

# Set user to run squid as..
if (!$in{'nouser'}) {
	$in{'user'} || &error($text{'icache_ymcautrsa'});
	my @uinfo = getpwnam($in{'user'});
	scalar(@uinfo) || &error($text{'icache_euser'});
	my @ginfo = getgrgid($uinfo[3]);
	if ($squid_version < 2) {
		my $dir = { 'name' => 'cache_effective_user',
			    'values' => [ $in{'user'}, $ginfo[0] ] };
		&save_directive($conf, "cache_effective_user", [ $dir ]);
		}
	else {
		my $dir = { 'name' => 'cache_effective_user',
			    'values' => [ $in{'user'} ] };
		&save_directive($conf, "cache_effective_user", [ $dir ]);
		$dir = { 'name' => 'cache_effective_group',
			 'values' => [ $ginfo[0] ] };
		&save_directive($conf, "cache_effective_group", [ $dir ]);
		}
	&flush_file_lines();
	}

# If cache_dir is set but disabled, enable it by un-commenting (but only the
# valid directives)
my @cachestruct = &find_config("cache_dir", $conf, 2);
if ($squid_version >= 2.3) {
	@cachestruct = grep { $_->{'values'}->[1] =~ /^\// &&
			      -d $_->{'values'}->[1] } @cachestruct;
	}
else {
	@cachestruct = grep { $_->{'values'}->[0] } @cachestruct;
	}
if (@cachestruct) {
	&save_directive($conf, "cache_dir", \@cachestruct);
	&flush_file_lines();
	}

&unlock_file($config{'squid_conf'});

# Stop squid (if running)
&ui_print_unbuffered_header(undef, $text{'icache_title'}, "");
my $pid = &is_squid_running();
my $stopped = 0;
if ($pid && kill(0, $pid)) {
	print "<p>$text{'clear_stop'}<br>\n";
	&system_logged("$config{'squid_path'} -f $config{'squid_conf'} ".
	               "-k shutdown >/dev/null 2>&1");
	for(my $i=0; $i<40; $i++) {
		if (!kill(0, $pid)) { last; }
		sleep(1);
		}
	print "$text{'clear_done'}<br>\n";
	$stopped++;
	}

# Initialize the cache
my ($user, $group) = &get_squid_user($conf);
if ($user) {
	foreach my $c (split(/\s+/, $in{'caches'})) {
		&make_dir($c, 0755);
		}
	}
&chown_files($user, $group, $conf);
my $cmd = "$config{'squid_path'} -f $config{'squid_conf'} -z";
print "<p>", &text('icache_itscwtc',$cmd), "<br>\n";
print "<pre>\n";
&additional_log('exec', undef, $cmd);
my $fh;
open($fh, "$cmd 2>&1 |");
while(<$fh>) {
	print &html_escape($_);
	}
close($fh);
print "</pre>\n";

# Try to re-start squid (if it was running before)
if ($stopped) {
	my $temp = &transname();
	&system_logged("$config{'squid_path'} -sY -f $config{'squid_conf'} >$temp 2>&1 </dev/null &");
	sleep(3);
	my $errs = &read_file_contents($temp);
	unlink($temp);
	if ($errs) {
		&system_logged("$config{'squid_path'} -k shutdown -f $config{'squid_conf'} >/dev/null 2>&1");
		print "$text{'clear_failrestart'}<br>\n";
		print "<pre>".&html_escape($errs)."</pre>\n";
		}
	}

&webmin_log("init");
&ui_print_footer("", $text{'icache_return'});

