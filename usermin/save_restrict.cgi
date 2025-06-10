#!/usr/local/bin/perl
# save_restrict.cgi
# Create, update or delete a user or group module restriction

require './usermin-lib.pl';
$access{'restrict'} || &error($text{'acl_ecannot'});
&ReadParse();
@usermods = &list_usermin_usermods();
$um = $usermods[$in{'idx'}] if (!$in{'new'});

&lock_file("$config{'usermin_dir'}/usermin.mods");
if ($in{'delete'}) {
	# Just delete this restriction
	@usermods = grep { $_ ne $um } @usermods;
	}
else {
	# Validate inputs
	&error_setup($text{'restrict_err'});
	if ($in{'umode'} == 0) {
		defined(getpwnam($in{'user'})) ||
			&error($text{'restrict_euser'});
		$um->[0] = $in{'user'};
		}
	elsif ($in{'umode'} == 1) {
		defined(getgrnam($in{'group'})) ||
			&error($text{'restrict_egroup'});
		$um->[0] = "\@".$in{'group'};
		}
	elsif ($in{'umode'} == 3) {
		$in{'file'} =~ /^\// && -r $in{'file'} ||
			&error($text{'restrict_efile'});
		$um->[0] = $in{'file'};
		}
	else {
		$um->[0] = "*";
		}
	$um->[1] = $in{'mmode'} == 0 ? "" :
		   $in{'mmode'} == 1 ? "+" : "-";
	$um->[2] = [ split(/\0/, $in{'mod'}) ];

	# Save the restriction
	if ($in{'new'}) {
		push(@usermods, $um);
		}
	}
&save_usermin_usermods(\@usermods);
&unlock_file("$config{'usermin_dir'}/usermin.mods");
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "restrict", $um->[0]);
&redirect("list_restrict.cgi");

