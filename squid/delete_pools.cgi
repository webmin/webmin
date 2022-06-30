#!/usr/local/bin/perl
# Delete a bunch of delay pools

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
&error_setup($text{'dpool_err'});
$access{'delay'} || &error($text{'delay_ecannot'});
&ReadParse();
my @d = split(/\0/, $in{'d'});
@d || &error($text{'dpool_enone'});

# Get the current settings
&lock_file($config{'squid_conf'});
my $conf = &get_config();
my @pools = &find_config("delay_class", $conf);
my @params = &find_config("delay_parameters", $conf);
my @access = &find_config("delay_access", $conf);
my $pools = &find_config("delay_pools", $conf);

# Do the deletion, highest first
foreach my $d (sort { $b <=> $a } @d) {
	my ($pool) = grep { $_->{'values'}->[0] == $d } @pools;
	my ($param) = grep { $_->{'values'}->[0] == $d } @params;
	@access = grep { $_->{'values'}->[0] != $d } @access;
	@pools = grep { $_ ne $pool } @pools;
	@params = grep { $_ ne $param } @params;
	map { $_->{'values'}->[0]-- if ($_->{'values'}->[0] > $d) } 
		(@access, @pools, @params);
	&save_directive($conf, "delay_class", \@pools);
	&save_directive($conf, "delay_parameters", \@params);
	&save_directive($conf, "delay_access", \@access);
	$pools->{'values'}->[0]--;
	&save_directive($conf, "delay_pools", [ $pools ]);
	}

&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("delete", "pools", scalar(@d));
&redirect("edit_delay.cgi");



