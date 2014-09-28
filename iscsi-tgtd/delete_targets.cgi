#!/usr/local/bin/perl
# Delete multiple targets

use strict;
use warnings;
require './iscsi-tgtd-lib.pl';
our (%text, %in, %config);
&ReadParse();
&error_setup($text{'dtargets_err'});
&lock_file($config{'config_file'});
my $conf = &get_tgtd_config();

# Find the targets
my @d = split(/\0/, $in{'d'});
my @deltargets;
my @locks;
foreach my $d (@d) {
	my ($target) = grep { $_->{'value'} eq $d } &find($conf, "target");
	push(@deltargets, $target) if ($target);
	push(@locks, $target->{'file'});
	}
@deltargets || &error($text{'dtargets_enone'});
@locks = &unique(@locks);

# Delete them, in reverse order
foreach my $l (@locks) {
	&lock_file($l);
	}
foreach my $target (reverse(@deltargets)) {
	&save_directive($conf, $target, undef);
	&flush_file_lines($target->{'file'});
	&delete_if_empty($target->{'file'});
	}
foreach my $l (@locks) {
	&unlock_file($l);
	}

&webmin_log('delete', 'targets', scalar(@deltargets));
&redirect("");
