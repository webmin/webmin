#!/usr/local/bin/perl
# save_netmasks.cgi
# Create, update or delete a netmask

require './nis-lib.pl';
&ReadParse();

($t, $lnums, $netmask) = &table_edit_setup($in{'table'}, $in{'line'}, '\s+');
if ($in{'delete'}) {
	# Just delete the ether
	&table_delete($t, $lnums);
	}
else {
	# Validate inputs and save the host
	&error_setup($text{'netmasks_err'});
	&check_ipaddress($in{'net'}) || &error($text{'netmasks_enet'});
	&check_ipaddress($in{'mask'}) || &error($text{'netmasks_emask'});
	@netmask = ( $in{'net'}, $in{'mask'} );
	if ($in{'line'} eq '') {
		&table_add($t, "\t", \@netmask);
		}
	else {
		&table_update($t, $lnums, "\t", \@netmask);
		}
	}
&apply_table_changes() if (!$config{'manual_build'});
&redirect("edit_tables.cgi?table=$in{'table'}");

