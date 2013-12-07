#!/usr/local/bin/perl
# activate.cgi
# Turn quotas on or off for some filesystem

require './quota-lib.pl';
&ReadParse();
&can_edit_filesys($in{'dir'}) && $access{'enable'} ||
	&error($text{'activate_eallow'});

if ($in{'active'} == 0) {
	# Turn on quotas
	&error_setup($text{'activate_eon'});
	@list = &list_filesystems();
	($fs) = grep { $_->[0] eq $in{'dir'} } @list;
	if (!$fs->[4] && $fs->[6]) {
		# Try to enable in /etc/fstab
		$error = &quota_make_possible($in{'dir'}, $fs->[6]);
		&error($error) if ($error);
		&webmin_log("support", undef, $in{'dir'}, \%in);
		}
	else {
		# Try to turn on
		$error = &quotaon($in{'dir'}, $in{'mode'});
		&error($error) if ($error);
		&webmin_log("activate", undef, $in{'dir'}, \%in);
		}
	}
else {
	# Turn off quotas
	&error_setup($text{'activate_eoff'});
	if ($error = &quotaoff($in{'dir'}, $in{'mode'})) {
		&error($error);
		}
	&webmin_log("deactivate", undef, $in{'dir'}, \%in);
	}
&redirect("");

