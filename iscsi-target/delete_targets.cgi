#!/usr/local/bin/perl
# Delete multiple targets

use strict;
use warnings;
require './iscsi-target-lib.pl';
our (%text, %in, %config);
&ReadParse();
&error_setup($text{'dtargets_err'});
&lock_file($config{'config_file'});
my $pconf = &get_iscsi_config_parent();
my $conf = $pconf->{'members'};

# Find the targets
my @d = split(/\0/, $in{'d'});
my @deltargets;
foreach my $d (@d) {
	my ($target) = grep { $_->{'value'} eq $d } &find($conf, "Target");
	push(@deltargets, $target) if ($target);
	}
@deltargets || &error($text{'dtargets_enone'});

# Delete them, in reverse order
foreach my $target (reverse(@deltargets)) {
	&save_directive($conf, $pconf, [ $target ], [ ]);
	}

&flush_file_lines($config{'config_file'});
&unlock_file($config{'config_file'});
&webmin_log('delete', 'targets', scalar(@deltargets));
&redirect("");
