#!/usr/local/bin/perl
# save_unix.cgi
# Save automatic unix user authentication options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';    ## no critic
our (%in, %text, %config, %access);
&ReadParse();
&error_setup($text{'unix_err'});
$access{'unix'} && $access{'create'} && $access{'delete'} ||
	&error($text{'unix_ecannot'});

# Parse Unix auth table
my (@unix, @rows, %lastrow);
if (!$in{'unix_def'}) {
	for(my $i=0; defined(my $mode = $in{"mode_$i"}); $i++) {
		next if (!$mode);
		my $who = $in{"who_$i"};
		if ($mode eq '2' && !length($who)) {
			&error(&text('unix_ewhogroup', $i+1));
			}
		elsif ($mode eq '3' && !length($who)) {
			&error(&text('unix_ewhouser', $i+1));
			}
		my $to = $in{"to_$i"};
		# MiniServ separates rows with whitespace and uses the last
		# equals sign to separate a Unix name from its Webmin user.
		$mode =~ /\A[123]\z/ && $to =~ /\A[^\s=\0]+\z/ &&
		    ($mode eq '1' || $who =~ /\A[^\s\0]+\z/) &&
		    ($mode ne '3' || $who ne '*' && $who !~ /^\@/) ||
			&error(&text('unix_emapping', $i+1));
		my $from = $mode eq '1' ? "*" : $mode eq '2' ? "\@$who" : $who;
		push(@unix, [ $from, $to ]);
		push(@rows, $i+1);
		$lastrow{$from} = $i+1;
		}
	@unix || &error($text{'unix_enone'});
	}

# Parse list of allowed users
my @users = split(/\s+/, $in{"users"});
if ($in{"access"}) {
	foreach my $u (@users) {
		if ($u =~ /^\@(\S+)$/) {
			defined(getgrnam($1)) ||
				&error(&text('unix_egroup', "$1"));
			}
		elsif ($u =~ /^(\d*)-(\d*)$/ && ($1 || $2)) {
			# Assume UIDs are ok
			}
		else {
			defined(getpwnam($u)) ||
				&error(&text('unix_euser', $u));
			}
		}
	}
if ($in{'shells_deny'}) {
	-r $in{'shells'} || &error($text{'unix_eshells'});
	}

&lock_file($ENV{'MINISERV_CONFIG'});
my %miniserv;
&get_miniserv_config(\%miniserv);
my (%saved, %active);
foreach my $map (&get_unixauth(\%miniserv)) {
	my ($from, $to) = @$map;
	$saved{$from}{$to} = 1;
	$active{$from} = $to;
	}
for(my $j=0; $j<@unix; $j++) {
	my ($from, $to) = @{$unix[$j]};
	# MiniServ uses the last row for each Unix name. An existing row
	# may stay, but making it active is a new grant.
	next if ($saved{$from}{$to} &&
		 ($rows[$j] != $lastrow{$from} || $active{$from} eq $to));
	&get_user($to) && &can_edit_user($to) ||
		&error(&text('unix_eto', $rows[$j]));
	}
if ($in{'pamany'}) {
	# MiniServ trims leading and trailing whitespace from config values.
	my $to = $in{'pamany_user'};
	length($to) && $to !~ /\A\s|\s\z|[\r\n\0]/ &&
	    ($to eq $miniserv{'pamany'} || &get_user($to) && &can_edit_user($to)) ||
		&error($text{'unix_epamany'});
	}
my $oldsudo = $miniserv{'sudo'};
&save_unixauth(\%miniserv, \@unix);
delete($miniserv{"allowusers"});
delete($miniserv{"denyusers"});
if ($in{"access"} == 1) { $miniserv{"allowusers"} = join(' ', @users); }
elsif ($in{"access"} == 2) { $miniserv{"denyusers"} = join(' ', @users); }
if ($in{'shells_deny'}) {
	$miniserv{'shells_deny'} = $in{'shells'};
	}
else {
	delete($miniserv{'shells_deny'});
	}
if ($in{'sudo'}) {
	&has_command("sudo") || &error(&text('unix_esudo', "<tt>sudo</tt>"));
	eval { require IO::Pty; IO::Pty->import; 1 };
	$@ && &error(&text('unix_esudomod', "<tt>IO::Pty</tt>"));
	}
$miniserv{'sudo'} = $in{'sudo'};
$miniserv{'pamany'} = $in{'pamany'} ? $in{'pamany_user'} : undef;
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});
if ($oldsudo != $in{'sudo'}) {
	&restart_miniserv();
	}
else {
	&reload_miniserv();
	}
&webmin_log("unix");
&redirect("");

