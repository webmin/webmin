#!/usr/local/bin/perl
# files_index.cgi
# Display a menu of icons for per-files options

require './apache-lib.pl';
&ReadParse();
$access{'global'} || &error($text{'htaccess_ecannot'});
&allowed_auth_file($in{'file'}) ||
	&error($text{'htindex_ecannot'});
$conf = &get_htaccess_config($in{'file'});
$d = $conf->[$in{'idx'}];
$desc = &text('htfile_header', &dir_name($d), "<tt>$in{'file'}</tt>");
&ui_print_header($desc, $text{'htfile_title'}, "");

$sw_icon = { "icon" => "images/show.gif",
	     "name" => $text{'htfile_show'},
	     "link" => "show.cgi?file=".&urlize($in{'file'})."&idx=$in{'idx'}" };
if ($access{'types'} eq '*') {
	$ed_icon = { "icon" => "images/edit.gif",
		     "name" => $text{'htfile_edit'},
		     "link" =>
			"manual_form.cgi?file=".&urlize($in{'file'})."&idx=$in{'idx'}" };
	}
&config_icons("directory", "edit_files.cgi?file=".&urlize($in{'file'})."&idx=$in{'idx'}&",
	      $sw_icon, $ed_icon ? ( $ed_icon ) : ( ));

print &ui_hr();
print &ui_form_start("change_files.cgi", "post");
print &ui_hidden("file", $in{'file'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'htfile_apply'}, undef, 2);

$regexp = $d->{'words'}->[0] eq "~" || $d->{'name'} =~ /Match/;
print &ui_table_row($text{'htindex_regexp'},
	&ui_radio("regexp", $regexp ? 1 : 0,
		  [ [ 0, $text{'htindex_exact'} ],
		    [ 1, $text{'htindex_re'} ] ]));

print &ui_table_row($text{'htindex_path'},
	&ui_textbox("path", 
		$d->{'words'}->[0] eq "~" ? $d->{'words'}->[1]
					  : $d->{'words'}->[0], 50));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ],
		     [ 'delete', $text{'delete'} ] ]);

&ui_print_footer("htaccess_index.cgi?file=".&urlize($in{'file'}), $text{'htindex_return'});


