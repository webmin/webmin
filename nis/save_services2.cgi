#!/usr/local/bin/perl
# save_services2.cgi
# Create, update or delete a service

require './nis-lib.pl';
&ReadParse();

($t, $lnums, $service) = &table_edit_setup($in{'table'}, $in{'line'}, '\s+');
if ($in{'delete'}) {
	# Just delete the service
	&table_delete($t, $lnums);
	}
else {
	# Validate inputs and save the service
	&error_setup($text{'services_err'});
	$in{'name'} =~ /^[A-Za-z0-9\_\-]+$/ || &error($text{'services_ename'});
	$in{'port'} =~ /^\d+$/ || &error($text{'services_eport'});
	@service = ( "$in{'name'}/$in{'proto'}", $in{'port'} );
	if ($in{'line'} eq '') {
		&table_add($t, "\t", \@service);
		}
	else {
		&table_update($t, $lnums, "\t", \@service);
		}
	}
&apply_table_changes() if (!$config{'manual_build'});
&redirect("edit_tables.cgi?table=$in{'table'}");

