#!/usr/local/bin/perl
# Remove out-dated DNSSEC verification options

use strict;
use warnings;
our (%access, %text, %in, %config);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'trusted_ecannot'});
&error_setup($text{'trusted_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
my $parent = &get_config_parent();
my $conf = $parent->{'members'};
my $options = &find("options", $conf);

# Switch to automatic lookaside mode
my @dlvs = ( { 'name' => 'dnssec-lookaside',
	       'values' => [ 'auto' ] } );
&save_directive($options, "dnssec-lookaside", \@dlvs, 1);

# Remove obsolete trusted keys
my $trusted = &find("trusted-keys", $conf);
if ($trusted) {
	my @oldkeys = @{$trusted->{'members'}};
	&save_directive($trusted, \@oldkeys, [ ], 1);
	}

&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
if (&is_bind_running()) {
	my $err = &restart_bind();
	&error($err) if ($err);
	}
&webmin_log("trusted");
&redirect("");

