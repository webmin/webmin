#!/usr/local/bin/perl
# save_group_shadow.cgi
# Create, update or delete a group

require './nis-lib.pl';
&ReadParse();

($t, $lnums, $group, $shadow) =
	&table_edit_setup($in{'table'}, $in{'line'}, '\s+');
if ($in{'delete'}) {
	# Just delete the group
	&table_delete($t, $lnums);
	}
else {
	# Validate inputs and save the group
	&error_setup($text{'group_err'});
	$in{'name'} =~ /^[^:\s]+$/ || &error($text{'group_ename'});
	$in{'gid'} =~ /^\d+$/ || &error($text{'group_egid'});
	$salt = chr(int(rand(26))+65) . chr(int(rand(26))+65);
	@group = ( $in{'name'}, "x", $in{'gid'},
		   join(",", split(/\s+/, $in{'members'})) );
	@shadow = ( $in{'name'},
		    $in{'passmode'} == 0 ? "" :
		    $in{'passmode'} == 1 ? $in{'encpass'} :
					   &unix_crypt($in{'pass'}, $salt),
		    "", join(",", split(/\s+/, $in{'members'})) );
	if ($in{'line'} eq '') {
		&table_add($t, ":", \@group, \@shadow);
		}
	else {
		&table_update($t, $lnums, ":", \@group, \@shadow);
		}
	}
&apply_table_changes() if (!$config{'manual_build'});
&redirect("edit_tables.cgi?table=$in{'table'}");

