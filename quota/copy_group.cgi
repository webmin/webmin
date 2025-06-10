#!/usr/local/bin/perl
# copy_group.cgi
# Copy some group's quota to a number of others

require './quota-lib.pl';
&ReadParse();
$whatfailed = $text{'cgroup_efail'};
$access{'filesys'} eq "*" ||
	&error($text{'cgroup_ecannot'});
&can_edit_group($in{'group'}) ||
	&error($text{'cgroup_egallow'});
$access{'ro'} && &error($text{'cgroup_egallow'});

if ($in{'dest'} == 0) {
	# Copy to all groups
	setgrent();
	while(@ginfo = getgrent()) { push(@copyto, $ginfo[0]); }
	endgrent() if ($gconfig{'os_type'} ne 'hpux');
	}
elsif ($in{'dest'} == 1) {
	# Copy to selected groups
	@copyto = split(/\s+/, $in{'groups'});
	}
elsif ($in{'dest'} == 2) {
	# Copy to groups containing users
	foreach $u (split(/\s+/, $in{'users'})) {
		@uinfo = getpwnam($u);
		@ginfo = getgrgid($uinfo[3]);
		push(@copyto, $ginfo[0]);
		$user{$u}++;
		}
	setgrent();
	while(@ginfo = getgrent()) {
		foreach $m (split(/\s+/, $ginfo[3])) {
			if ($user{$m}) {
				push(@copyto, $ginfo[0]);
				last;
				}
			}
		}
	endgrent() if ($gconfig{'os_type'} ne 'hpux');
	}
@copyto = &unique(@copyto);
@copyto = grep { $_ ne $in{'group'} } @copyto;
if (!@copyto) { &error($text{'cgroup_enogroup'}); }
foreach $c (@copyto) {
	&can_edit_group($c) ||
		&error(&text('cgroup_eallowto', $c));
	}

# Do the copy
&copy_group_quota($in{'group'}, @copyto);
&webmin_log("copy", "group", $in{'group'}, \%in);
&redirect("group_filesys.cgi?group=$in{'group'}");

