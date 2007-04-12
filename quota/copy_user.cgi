#!/usr/local/bin/perl
# copy_user.cgi
# Copy some user's quota to a number of others

require './quota-lib.pl';
&ReadParse();
$whatfailed = $text{'cuser_efail'};
$access{'filesys'} eq "*" ||
	&error($text{'cuser_ecannot'});
&can_edit_user($in{'user'}) ||
	&error($text{'cuser_euallow'});
$access{'ro'} && &error($text{'cuser_euallow'});

if ($in{'dest'} == 0) {
	# Copy to all users
	setpwent();
	while(@uinfo = getpwent()) {
		push(@copyto, $uinfo[0]);
		}
	endpwent() if ($gconfig{'os_type'} ne 'hpux');
	}
elsif ($in{'dest'} == 1) {
	# Copy to selected users
	@copyto = split(/\s+/, $in{'users'});
	}
elsif ($in{'dest'} == 2) {
	# Copy to members of groups
	setpwent();
	while(@uinfo = getpwent()) { $ingroup{$uinfo[3]} .= "$uinfo[0] "; }
	endpwent() if ($gconfig{'os_type'} ne 'hpux');
	foreach $g (split(/\s+/, $in{'groups'})) {
		@ginfo = getgrnam($g);
		push(@copyto, split(/\s+/, $ingroup{$ginfo[2]}));
		push(@copyto, split(/\s+/, $ginfo[3]));
		}
	}
@copyto = &unique(@copyto);
@copyto = grep { $_ ne $in{'user'} } @copyto;
if (!@copyto) { &error($text{'cuser_enouser'}); }
foreach $c (@copyto) {
	&can_edit_user($c) ||
		&error(&text('cuser_eallowto', $c));
	}

# Do the copy
&copy_user_quota($in{'user'}, @copyto);
&webmin_log("copy", "user", $in{'user'}, \%in);
&redirect("user_filesys.cgi?user=$in{'user'}");

