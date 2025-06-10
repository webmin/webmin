#!/usr/local/bin/perl
# save_aliases.cgi
# Create, update or delete an alias

require './nis-lib.pl';
&ReadParse();

($t, $lnums, $alias) = &table_edit_setup($in{'table'}, $in{'line'}, '[\s:]+');
if ($in{'delete'}) {
	# Just delete the alias
	&table_delete($t, $lnums);
	}
else {
	# Validate inputs and save the alias
	&error_setup($text{'aliases_err'});
	$in{'from'} =~ /^[^:@ ]+$/ || &error($text{'aliases_efrom'});
	@to = split(/\s+/, $in{'to'});
	@to || &error($text{'aliases_eto'});
	@alias = ( $in{'from'}, join(",", @to) );
	if ($in{'line'} eq '') {
		&table_add($t, ":", \@alias);
		}
	else {
		&table_update($t, $lnums, ":", \@alias);
		}
	}
&apply_table_changes() if (!$config{'manual_build'});
&redirect("edit_tables.cgi?table=$in{'table'}");

