#!/usr/local/bin/perl
# Show the details of one fileset

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
@filesets = &find("FileSet", $conf);
if ($in{'new'}) {
	&ui_print_header(undef, $text{'fileset_title1'}, "");
	$mems = [ ];
	$fileset = { };
	}
else {
	&ui_print_header(undef, $text{'fileset_title2'}, "");
	$fileset = &find_by("Name", $in{'name'}, \@filesets);
	$fileset || &error($text{'fileset_egone'});
	$mems = $fileset->{'members'};
	}

# Show details
print &ui_form_start("save_fileset.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_table_start($text{'fileset_header'}, "width=100%", 4);

# File set name
print &ui_table_row($text{'fileset_name'},
	    &ui_textbox("name", $name=&find_value("Name", $mems), 40), 3);

# Included files
$inc = &find("Include", $mems);
@files = $inc ? &find_value("File", $inc->{'members'}) : ( );
print &ui_table_row($text{'fileset_include'},
		    &ui_textarea("include", join("\n", @files), 5, 60)."\n".
		    &file_chooser_button("include", 0, 0, undef, 1), 3);

# Options
$opts = $inc ? &find("Options", $inc->{'members'}) : undef;
$sig = $opts ? &find_value("signature", $opts->{'members'}) : undef;
print &ui_table_row($text{'fileset_sig'},
		    &ui_select("signature", $sig,
			[ [ "", $text{'fileset_none'} ],
			  [ "MD5" ], [ "SHA1" ] ], 1, 0, 1));

# Excluded files
$exc = &find("Exclude", $mems);
@files = $exc ? &find_value("File", $exc->{'members'}) : ( );
print &ui_table_row($text{'fileset_exclude'},
		    &ui_textarea("exclude", join("\n", @files), 5, 60)."\n".
		    &file_chooser_button("exclude", 0, 0, undef, 1), 3);

# Compression level
$comp = &find_value("Compression", $opts->{'members'});
print &ui_table_row($text{'fileset_comp'},
	&ui_select("comp", $comp,
		[ [ '', $text{'fileset_gzipdef'} ],
		  [ 'LZO', $text{'fileset_lzo'} ],
		  map { [ "GZIP".$_, &text('fileset_gzip', $_) ] }
		      (1..9) ]));

# Single filesystem?
print &ui_table_row($text{'fileset_onefs'},
	&bacula_yesno("onefs", "OneFS", $opts->{'members'}));

# All done
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_filesets.cgi", $text{'filesets_return'});

