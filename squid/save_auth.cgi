#!/usr/local/bin/perl
# save_auth.cgi
# Save authentication options

require './squid-lib.pl';
$access{'proxyauth'} || &error($text{'eauth_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();
$whatfailed = $text{'sauth_ftsao'};

if ($in{'authfile_def'}) {
	&save_directive($conf, "proxy_auth", [ ]);
	}
else {
	$in{'authfile'} =~ /^\// || &error($text{'sauth_iomuf'});
	if (!-r $in{'authfile'}) {
		&open_tempfile(AUTH, ">$in{'authfile'}");
		&close_tempfile(AUTH);
		($user, $group) = &get_squid_user($conf);
		if ($user) {
			@uinfo = getpwnam($user);
			@ginfo = getgrnam($group);
			chown($uinfo[2], $ginfo[2], $in{'authfile'});
			chmod(0644, $in{'authfile'});
			}
		}
	push(@vals, $in{'authfile'});
	if (!$in{'authdom_def'}) {
		$in{'authdom'}=~/^\S+$/ || &error($text{'sauth_iomd'});
		push(@vals, $in{'authdom'});
		}
	&save_directive($conf, "proxy_auth",
			[ { 'name' => 'proxy_auth',
			    'values' => \@vals } ]);
	}
&flush_file_lines();

# check if the proxy_auth directive is supported
$out = `$config{'squid_path'} -f $config{'squid_conf'} -k check 2>&1`;
if ($out =~ /proxy_auth/) {
	# it isn't .. roll back
	&save_directive($conf, "proxy_auth", [ ]);
	&flush_file_lines();
	&error($text{'sauth_msg1'});
	}
&unlock_file($config{'squid_conf'});
&redirect("");

