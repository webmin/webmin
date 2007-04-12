#!/usr/local/bin/perl
# init_cache.cgi
# Initialize the cache by running squid with the -z option

require './squid-lib.pl';
$access{'rebuild'} || &error($text{'icache_ecannot'});
&ReadParse();
$whatfailed = $text{'icache_ftic'};

# set user to run squid as..
&lock_file($config{'squid_conf'});
$conf = &get_config();
if (!$in{'nouser'}) {
	$in{'user'} || &error($text{'icache_ymcautrsa'});
	@uinfo = getpwnam($in{'user'});
	@ginfo = getgrgid($uinfo[3]);
	if ($squid_version < 2) {
		$dir = { 'name' => 'cache_effective_user',
			 'values' => [ $in{'user'}, $ginfo[0] ] };
		&save_directive($conf, "cache_effective_user", [ $dir ]);
		}
	else {
		$dir = { 'name' => 'cache_effective_user',
			 'values' => [ $in{'user'} ] };
		&save_directive($conf, "cache_effective_user", [ $dir ]);
		$dir = { 'name' => 'cache_effective_group',
			 'values' => [ $ginfo[0] ] };
		&save_directive($conf, "cache_effective_group", [ $dir ]);
		}
	&flush_file_lines();
	}
&unlock_file($config{'squid_conf'});

# Stop squid (if running)
&ui_print_unbuffered_header(undef, $text{'icache_title'}, "");
if ($pidstruct = &find_config("pid_filename", $conf)) {
	$pidfile = $pidstruct->{'values'}->[0];
	}
else { $pidfile = $config{'pid_file'}; }
if (open(PID, $pidfile)) {
	<PID> =~ /(\d+)/; $pid = $1;
	close(PID);
	}
if ($pid && kill(0, $pid)) {
	print "<p>$text{'clear_stop'}<br>\n";
	&system_logged("$config{'squid_path'} -f $config{'squid_conf'} ".
	               "-k shutdown >/dev/null 2>&1");
	for($i=0; $i<40; $i++) {
		if (!kill(0, $pid)) { last; }
		sleep(1);
		}
	print "$text{'clear_done'}<br>\n";
	$stopped++;
	}

# Initialize the cache
($user, $group) = &get_squid_user($conf);
if ($user) {
	foreach $c (split(/\s+/, $in{'caches'})) {
		mkdir($c, 0755);
		}
	}
&chown_files($user, $group, $conf);
$cmd = "$config{'squid_path'} -f $config{'squid_conf'} -z";
print "<p>", &text('icache_itscwtc',$cmd), "<br>\n";
print "<pre>\n";
&additional_log('exec', undef, $cmd);
open(INIT, "$cmd 2>&1 |");
while(<INIT>) {
	print;
	}
close(INIT);
print "</pre>\n";

# Try to re-start squid (if it was running before)
if ($stopped) {
	$temp = &transname();
	&system_logged("$config{'squid_path'} -sY -f $config{'squid_conf'} >$temp 2>&1 </dev/null &");
	sleep(3);
	$errs = `cat $temp`;
	unlink($temp);
	if ($errs) {
		&system_logged("$config{'squid_path'} -k shutdown -f $config{'squid_conf'} >/dev/null 2>&1");
		print "$text{'clear_failrestart'}<br>\n";
		print "<pre>$errs</pre>\n";
		}
	}

&webmin_log("init");
&ui_print_footer("", $text{'icache_return'});

