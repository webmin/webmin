#!/usr/local/bin/perl
# Save timeout options

use strict;
use warnings;
require './iscsi-client-lib.pl';
our (%text, %config, %in);
&ReadParse();
&lock_file($config{'config_file'});
my $conf = &get_iscsi_config();
&error_setup($text{'timeout_err'});

# Session re-establishment timeout
my $timeout = $in{'timeout_def'} == 1 ? undef :
	      $in{'timeout_def'} == 2 ? 0 :
	      $in{'timeout_def'} == 3 ? -1 : $in{'timeout'};
$timeout =~ /^\-?\d+$/ || &error($text{'timeout_etimeout'});
&save_directive($conf, "node.session.timeo.replacement_timeout", $timeout);

# Other connection timeouts
foreach my $t ("login_timeout", "logout_timeout", "noop_out_interval",
	       "noop_out_timeout") {
	my $v = $in{$t."_def"} ? undef : $in{$t};
	!defined($v) || $v =~ /^\d+$/ || &error($text{'timeout_e'.$t});
	&save_directive($conf, "node.conn[0].timeo.$t", $v);
	}

# Other error timeouts
foreach my $t ("abort_timeout", "lu_reset_timeout", "tgt_reset_timeout") {
	my $v = $in{$t."_def"} ? undef : $in{$t};
	!defined($v) || $v =~ /^\d+$/ || &error($text{'timeout_e'.$t});
	&save_directive($conf, "node.session.err_timeo.$t", $v);
	}

&flush_file_lines($config{'targets_file'});
&unlock_file($config{'config_file'});
&webmin_log("timeout");
&redirect("");

