#!/usr/local/bin/perl
# Save password quality and change restrictions

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access);
$access{'pass'} || &error($text{'pass_ecannot'});
&error_setup($text{'pass_err'});

my %miniserv;
&get_miniserv_config(\%miniserv);
&ReadParse();

# Validate and store inputs
if ($in{'minsize_def'}) {
	delete($miniserv{'pass_minsize'});
	}
else {
	$in{'minsize'} =~ /^\d+$/ || &error($text{'pass_eminsize'});
	$miniserv{'pass_minsize'} = $in{'minsize'};
	}
$miniserv{'pass_regexps'} = join("\t", split(/\r?\n/, $in{'regexps'}));
$miniserv{'pass_regdesc'} = $in{'regdesc'};
if ($in{'maxdays_def'}) {
	delete($miniserv{'pass_maxdays'});
	}
else {
	$in{'maxdays'} =~ /^\d+$/ || &error($text{'pass_emaxdays'});
	$miniserv{'pass_maxdays'} = $in{'maxdays'};
	}
if ($in{'lockdays_def'}) {
	delete($miniserv{'pass_lockdays'});
	}
else {
	$in{'lockdays'} =~ /^\d+$/ || &error($text{'pass_elockdays'});
	$miniserv{'pass_lockdays'} = $in{'lockdays'};
	}
$miniserv{'pass_nouser'} = $in{'nouser'};
$miniserv{'pass_nodict'} = $in{'nodict'};
if ($in{'oldblock_def'}) {
	delete($miniserv{'pass_oldblock'});
	}
else {
	$in{'oldblock'} =~ /^\d+$/ || &error($text{'pass_eoldblock'});
	$miniserv{'pass_oldblock'} = $in{'oldblock'};
	}
&lock_file($ENV{'MINISERV_CONFIG'});
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

# For any users with no last change time set, set it now
my $fixed = 0;
foreach my $user (&list_users()) {
	if ($miniserv{'pass_maxdays'} && !$user->{'lastchange'}) {
		$user->{'lastchange'} = time();
		&modify_user($user->{'name'}, $user);
		$fixed++;
		}
	}
if ($fixed) {
	&reload_miniserv();
	}

&webmin_log("pass");
&redirect("");

