#!/usr/local/bin/perl
# dir_index.cgi
# Display a menu of icons for per-directory options

require './apache-lib.pl';
&ReadParse();
($conf, $v) = &get_virtual_config($in{'virt'});
&can_edit_virt($v) || &error($text{'virt_ecannot'});
$d = $conf->[$in{'idx'}];
$desc = &text('dir_header', &dir_name($d), &virtual_name($v));
&ui_print_header($desc, $text{'dir_title'}, "",
	undef, undef, undef, undef, &restart_button());

$sw_icon = { "icon" => "images/show.gif",
	     "name" => $text{'dir_show'},
	     "link" => "show.cgi?virt=$in{'virt'}&idx=$in{'idx'}" };
if ($access{'types'} eq '*') {
	$ed_icon = { "icon" => "images/edit.gif",
		     "name" => $text{'dir_edit'},
		     "link" =>
			"manual_form.cgi?virt=$in{'virt'}&idx=$in{'idx'}" };
	}
&config_icons("directory", "edit_dir.cgi?virt=$in{'virt'}&idx=$in{'idx'}&",
	      $sw_icon, $ed_icon ? ( $ed_icon) : ( ));

print &ui_hr();
print &ui_form_start("change_dir.cgi", "post");
print &ui_hidden("virt", $in{'virt'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'dir_opts'}, undef, 2);

$dname = $d->{'name'};
$dname =~ s/Match$//;
print &ui_table_row($text{'dir_type'},
	&ui_select("type", $dname,
	  [ map { [ $_, $text{'virt_'.$_} ] }
		  $httpd_modules{'core'} >= 2.0 ?
			( "Directory", "Files", "Location", "Proxy" ) :
		  $httpd_modules{'core'} >= 1.2 ?
			( "Directory", "Files", "Location" ) :
			( "Directory", "Location" ) ]));

if ($httpd_modules{'core'} >= 1.2) {
	$re = $d->{'words'}->[0] eq "~" || $d->{'name'} =~ /Match/i ? 1 : 0;
	print &ui_table_row($text{'dir_regexp'},
		&ui_radio("regexp", $re, [ [ 0, $text{'virt_exact'} ],
					   [ 1, $text{'virt_re'} ] ]));
	}

print &ui_table_row($text{'dir_path'},
	&ui_textbox("path", $d->{'words'}->[0] eq "~" ? $d->{'words'}->[1]
						  : $d->{'words'}->[0], 50));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'save'} ],
		     [ "delete", $text{'delete'} ] ]);

&ui_print_footer("virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'});


