#!/usr/local/bin/perl
# save_protocols.cgi
# Create, update or delete a protocol

require './nis-lib.pl';
&ReadParse();

($t, $lnums, $protocol) = &table_edit_setup($in{'table'}, $in{'line'}, '\s+');
if ($in{'delete'}) {
	# Just delete the service
	&table_delete($t, $lnums);
	}
else {
	# Validate inputs and save the protocol
	&error_setup($text{'protocols_err'});
	$in{'name'} =~ /^[A-Za-z0-9\_\-]+$/ || &error($text{'protocols_ename'});
	$in{'number'} =~ /^\d+$/ || &error($text{'protocols_enumber'});
	@protocol = ( $in{'name'}, $in{'number'}, split(/\s+/, $in{'aliases'}) );
	if ($in{'line'} eq '') {
		&table_add($t, "\t", \@protocol);
		}
	else {
		&table_update($t, $lnums, "\t", \@protocol);
		}
	}
&apply_table_changes() if (!$config{'manual_build'});
&redirect("edit_tables.cgi?table=$in{'table'}");

