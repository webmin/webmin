#!/usr/local/bin/perl
# edit_global.cgi
# Display a form for editing some kind of global options

require './apache-lib.pl';
&ReadParse();
$conf = &get_config();
@dirs = &editable_directives($in{'type'}, 'global');
$access{'global'}==1 || &error($text{'global_ecannot'});
$access_types{$in{'type'}} ||
	&error($text{'etype'});
&ui_print_header(undef, $text{"type_$in{'type'}"}, "",
	undef, undef, undef, undef, &restart_button());

print &ui_form_start("save_global.cgi", "post");
print &ui_hidden("type", $in{'type'});
print &ui_table_start($text{"type_$in{'type'}"}, "width=100%", 4);
&generate_inputs(\@dirs, $conf);
print &ui_table_end();
print &ui_form_end([ [ "", $text{'save'} ] ]);

if ($in{'type'} == 6) {
	$mfile = &find_directive("TypesConfig", $conf);
	if (!$mfile) { $mfile = $config{'mime_types'}; }
	if (!$mfile) { $mfile = &server_root("etc/mime.types", $conf); }
	if (!-r $mfile) { $mfile = &server_root("conf/mime.types", $conf); }
	$mfile = &server_root($mfile, $conf);
	print &ui_hr();
	print &ui_subheading($text{'global_mime'});
	print "$text{'global_mimedesc'}<p>\n";
	@links = ( &ui_link("edit_gmime_type.cgi?file=$mfile",
	           $text{'global_add'}) );
	print &ui_links_row(\@links);
	print &ui_columns_start([ $text{'global_type'},
				  $text{'global_ext'} ]);
	open(MIME, $mfile);
	$line = 0;
	while(<MIME>) {
		chop;
		s/#.*$//;
		if (/^\s*(\S+)\s*(.*)$/) {
			print &ui_columns_row([
				&ui_link("edit_gmime_type.cgi?line=$line".
				"&file=$mfile", $1), $2 ]);
			}
		$line++;
		}
	close(MIME);
	print &ui_columns_end();
	print &ui_links_row(\@links);
	}

&ui_print_footer("index.cgi?mode=global", $text{'index_return2'});
