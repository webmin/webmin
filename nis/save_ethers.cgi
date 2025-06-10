#!/usr/local/bin/perl
# save_ethers.cgi
# Create, update or delete an ethernet address

require './nis-lib.pl';
&ReadParse();

($t, $lnums, $ether) = &table_edit_setup($in{'table'}, $in{'line'}, '\s+');
if ($in{'delete'}) {
	# Just delete the ether
	&table_delete($t, $lnums);
	}
else {
	# Validate inputs and save the host
	&error_setup($text{'ethers_err'});
	lc($in{'mac'}) =~ /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/ ||
		&error($text{'ethers_emac'});
	&to_ipaddress($in{'ip'}) || &to_ip6address($in{'ip'}) ||
		&error($text{'ethers_eip'});
	@ether = ( $in{'mac'}, $in{'ip'} );
	if ($in{'line'} eq '') {
		&table_add($t, "\t", \@ether);
		}
	else {
		&table_update($t, $lnums, "\t", \@ether);
		}
	}
&apply_table_changes() if (!$config{'manual_build'});
&redirect("edit_tables.cgi?table=$in{'table'}");

