#!/usr/local/bin/perl
# save_file.cgi
# Save the files of a manually edited NIS table

require './nis-lib.pl';
&ReadParseMime();
@tables = &list_nis_tables();
$table = $tables[$in{'table'}];
$fnum = 0;
foreach $f (@{$table->{'files'}}) {
	$in{"data_$fnum"} =~ s/\r//g;
	if ($in{"data_$fnum"} =~ /\S/) {
		$in{"data_$fnum"} =~ s/\s*$/\n/;
		}
	else {
		$in{"data_$fnum"} = "";
		}
	&open_tempfile(FILE, ">$f");
	&print_tempfile(FILE, $in{"data_$fnum"});
	&close_tempfile(FILE);
	$fnum++;
	}
&apply_table_changes() if (!$config{'manual_build'});
&redirect("edit_tables.cgi?table=$in{'table'}");

