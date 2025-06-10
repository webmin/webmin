#!/usr/local/bin/perl
# Show a list of all sets of files to backup

require './bacula-backup-lib.pl';
&ui_print_header(undef, $text{'filesets_title'}, "", "filesets");

$conf = &get_director_config();
@filesets = &find("FileSet", $conf);
&sort_by_name(\@filesets);
if (@filesets) {
	print &ui_form_start("delete_filesets.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit_fileset.cgi?new=1",$text{'filesets_add'}),
		 );
	print &ui_links_row(\@links);
	@tds = ( "width=5", "width=20%", "width=80%" );
	print &ui_columns_start([ "", $text{'filesets_name'},
				  $text{'filesets_files'} ], "100%", 0, \@tds);
	foreach $f (@filesets) {
		$name = &find_value("Name", $f->{'members'});
		$inc = &find("Include", $f->{'members'});
		@files = $inc ? &find_value("File", $inc->{'members'}) : ( );
		if (@files > 4) {
			@files = ( @files[0..3], "..." );
			}
		print &ui_checked_columns_row([
			&ui_link("edit_fileset.cgi?name=".&urlize($name),$name),
			join(" , ", @files),
			], \@tds, "d", $name);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'filesets_delete'} ] ]);
	}
else {
	print "<b>$text{'filesets_none'}</b><p>\n";
	print &ui_link("edit_fileset.cgi?new=1",$text{'filesets_add'}),"<br>\n";
	}

&ui_print_footer("", $text{'index_return'});

