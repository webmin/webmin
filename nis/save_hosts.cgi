#!/usr/local/bin/perl
# save_hosts.cgi
# Create, update or delete a host

require './nis-lib.pl';
&ReadParse();

($t, $lnums, $host) = &table_edit_setup($in{'table'}, $in{'line'}, '\s+');
if ($in{'delete'}) {
	# Just delete the host
	&table_delete($t, $lnums);
	}
else {
	# Validate inputs and save the host
	&error_setup($text{'hosts_err'});
	&check_ipaddress($in{'ip'}) || &error($text{'hosts_eip'});
	$in{'name'} =~ /^[A-Za-z0-9\.\-]+$/ || &error($text{'hosts_ename'});
	@host = ( $in{'ip'}, $in{'name'}, split(/\s+/, $in{'aliases'}) );
	if ($in{'line'} eq '') {
		&table_add($t, "\t", \@host);
		}
	else {
		&table_update($t, $lnums, "\t", \@host);
		}
	}
&apply_table_changes() if (!$config{'manual_build'});
&redirect("edit_tables.cgi?table=$in{'table'}");

