#!/usr/local/bin/perl
# Save per-user and group logout times options

require './usermin-lib.pl';
&error_setup($text{'logout_err'});
$access{'logout'} || &error($text{'logout_ecannot'});
&get_usermin_miniserv_config(\%miniserv);
&ReadParse();

# Save to list
for($i=0; defined($type = $in{"type_$i"}); $i++) {
	next if (!$type);
	$who = $in{"who_$i"};
	$time = $in{"time_$i"};
	if ($type == 1) {
		$who =~ /^\S+$/ || &error(&text('logout_euser', $i+1));
		}
	elsif ($type == 2) {
		$who =~ /^\S+$/ || &error(&text('logout_egroup', $i+1));
		$who = "\@$who";
		}
	elsif ($type == 3) {
		-r $who && $who =~ /^\// || &error(&text('logout_efile', $i+1));
		}
	$time =~ /^\d+$/ || &error(&text('logout_etime', $i+1));
	push(@logout, [ $who, $time ]);
	}

# Update config
$miniserv{'logouttimes'} = join(" ", map { $_->[0]."=".$_->[1] } @logout);
&lock_file($usermin_miniserv_config);
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);
&reload_usermin_miniserv();
&webmin_log("logout");
&redirect("");

