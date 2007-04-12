#!/usr/local/bin/perl
# save_networks.cgi
# Create, update or delete a network

require './nis-lib.pl';
&ReadParse();

($t, $lnums, $network) = &table_edit_setup($in{'table'}, $in{'line'}, '\s+');
if ($in{'delete'}) {
	# Just delete the network
	&table_delete($t, $lnums);
	}
else {
	# Validate inputs and save the network
	&error_setup($text{'networks_err'});
	&check_ipaddress($in{'ip'}) || &error($text{'networks_eip'});
	$in{'name'} =~ /^[A-Za-z0-9\.\-]+$/ || &error($text{'networks_ename'});
	@network = ( $in{'name'}, $in{'ip'}, split(/\s+/, $in{'aliases'}) );
	if ($in{'line'} eq '') {
		&table_add($t, "\t", \@network);
		}
	else {
		&table_update($t, $lnums, "\t", \@network);
		}
	}
&apply_table_changes() if (!$config{'manual_build'});
&redirect("edit_tables.cgi?table=$in{'table'}");

