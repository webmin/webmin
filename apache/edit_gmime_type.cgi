#!/usr/local/bin/perl
# edit_gmime_type.cgi
# Display a form for editing a MIME type from the global list

require './apache-lib.pl';
&ReadParse();
$access{'global'}==1 || &error($text{'mime_ecannot'});
if (defined($in{'line'})) {
	&ui_print_header(undef, $text{'mime_edit'}, "");
	open(MIME, $in{'file'});
	for($i=0; $i<=$in{'line'}; $i++) {
		$line = <MIME>;
		}
	close(MIME);
	$line =~ s/#.*$//;
	$line =~ /^\s*(\S+)\s*(.*)$/;
	$type = $1; @exts = split(/\s+/, $2);
	}
else {
	&ui_print_header(undef, $text{'mime_add'}, "");
	}

print &ui_form_start("save_gmime_type.cgi");
print &ui_hidden("file", $in{'file'});
if ($type) {
	print &ui_hidden("line", $in{'line'});
	}
print &ui_table_start($text{'mime_header'}, undef, 2);

print &ui_table_row($text{'mime_type'},
	&ui_textbox("type", $type, 40));

print &ui_table_row($text{'mime_ext'},
	&ui_textarea("exts", join("\n", @exts), 5, 15));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'save'} ] ]);

&ui_print_footer("edit_global.cgi?type=6", $text{'global_return'});

