#!/usr/local/bin/perl
# edit_unix.cgi
# Save automatic unix user authentication options

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access);
&ReadParse();
&error_setup($text{'unix_err'});
$access{'unix'} && $access{'create'} && $access{'delete'} ||
	&error($text{'unix_ecannot'});

# Parse Unix auth table
my @unix;
if (!$in{'unix_def'}) {
	for(my $i=0; defined(my $mode = $in{"mode_$i"}); $i++) {
		next if (!$mode);
		my $who = $in{"who_$i"};
		if ($mode == 2 && !$who) {
			&error(&text('unix_ewhogroup', $i+1));
			}
		elsif ($mode == 3 && !$who) {
			&error(&text('unix_ewhouser', $i+1));
			}
		my $to = $in{"to_$i"};
		push(@unix, [ $mode == 1 ? "*" :
			      $mode == 2 ? "\@$who" : $who, $to ]);
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
	-r $in{'shells'} || &error($text{'unix_eshell'});
	}

&lock_file($ENV{'MINISERV_CONFIG'});
my %miniserv;
&get_miniserv_config(\%miniserv);
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
	eval "use IO::Pty";
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

