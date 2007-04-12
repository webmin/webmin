#!/usr/local/bin/perl
# Delete a bunch of delay pools

require './squid-lib.pl';
&error_setup($text{'dpool_err'});
$access{'delay'} || &error($text{'delay_ecannot'});
&ReadParse();
@d = split(/\0/, $in{'d'});
@d || &error($text{'dpool_enone'});

# Get the current settings
&lock_file($config{'squid_conf'});
$conf = &get_config();
@pools = &find_config("delay_class", $conf);
@params = &find_config("delay_parameters", $conf);
@access = &find_config("delay_access", $conf);
$pools = &find_config("delay_pools", $conf);

# Do the deletion, highest first
foreach $d (sort { $b <=> $a } @d) {
	($pool) = grep { $_->{'values'}->[0] == $d } @pools;
	($param) = grep { $_->{'values'}->[0] == $d } @params;
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



