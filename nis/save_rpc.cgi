#!/usr/local/bin/perl
# save_rpc.cgi
# Create, update or delete an rpc program

require './nis-lib.pl';
&ReadParse();

($t, $lnums, $rpc) = &table_edit_setup($in{'table'}, $in{'line'}, '\s+');
if ($in{'delete'}) {
	# Just delete the host
	&table_delete($t, $lnums);
	}
else {
	# Validate inputs and save the host
	&error_setup($text{'rpc_err'});
	$in{'name'} =~ /^\S+$/ || &error($text{'rpc_ename'});
	$in{'number'} =~ /^\d+$/ || &error($text{'rpc_enumber'});
	@rpc = ( $in{'name'}, $in{'number'}, split(/\s+/, $in{'aliases'}) );
	if ($in{'line'} eq '') {
		&table_add($t, "\t", \@rpc);
		}
	else {
		&table_update($t, $lnums, "\t", \@rpc);
		}
	}
&apply_table_changes() if (!$config{'manual_build'});
&redirect("edit_tables.cgi?table=$in{'table'}");

