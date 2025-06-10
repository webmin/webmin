#!/usr/local/bin/perl
# htaccess_index.cgi
# Display a menu of icons for a per-directory options file

require './apache-lib.pl';
&ReadParse();
$access{'global'} || &error($text{'htaccess_ecannot'});
&allowed_auth_file($in{'file'}) ||
	&error($text{'htindex_ecannot'});
$conf = &get_htaccess_config($in{'file'});
$desc = &html_escape($in{'file'});
&ui_print_header($desc, $text{'htindex_title'}, "",
	undef, undef, undef, undef, &ui_link("delete_htaccess.cgi?file=".
	&urlize($in{'file'}), $text{'htindex_delete'}) );

$sw_icon = { "icon" => "images/show.gif",
	     "name" => $text{'htindex_show'},
	     "link" => "show.cgi?file=".&urlize($in{'file'}) };
if ($access{'types'} eq '*') {
	$ed_icon = { "icon" => "images/edit.gif",
		     "name" => $text{'htindex_edit'},
		     "link" => "manual_form.cgi?file=".&urlize($in{'file'}) };
	}
&config_icons("htaccess", "edit_htaccess.cgi?file=".&urlize($in{'file'})."&",
	      $sw_icon, $ed_icon ? ( $ed_icon ) : ( ));

@file = ( &find_directive_struct("Files", $conf),
          &find_directive_struct("FilesMatch", $conf) );
if (@file && $httpd_modules{'core'} >= 1.2) {
	# Files sub-directives
	print &ui_hr();
	print &ui_subheading($text{'htindex_file'});
	foreach $f (@file) {
		$what = &dir_name($f);
		substr($what, 0, 1) = uc(substr($what, 0, 1));
		push(@links, "files_index.cgi?idx=".&indexof($f, @$conf).
                             "&file=".&urlize($in{'file'}));
		push(@titles, $what);
		push(@icons, "images/dir.gif");
		push(@types, $f->{'name'});
		}
	if ($config{'show_list'}) {
		# Show as list
		print &ui_columns_start([ $text{'virt_path'},
					  $text{'virt_type'} ]);
		for($i=0; $i<@links; $i++) {
			print &ui_columns_row([
			  &ui_link($links[$i], $titles[$i]),
			  $text{'virt_'.$types[$i]} ]);
			}
		print &ui_columns_end();
		}
	else {
		&icons_table(\@links, \@titles, \@icons, 3);
		}
	print "<p>\n";
	}

if ($httpd_modules{'core'} >= 1.2) {
	print &ui_form_start("create_files.cgi");
	print &ui_hidden("file", $in{'file'});
	print &ui_table_start($text{'htindex_create'}, undef, 2);

	print &ui_table_row($text{'htindex_regexp'},
		&ui_radio("regexp", 0,
			  [ [ 0, $text{'htindex_exact'} ],
			    [ 1, $text{'htindex_re'} ] ]));

	print &ui_table_row($text{'htindex_path'},
		&ui_textbox("path", undef, 50));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("htaccess.cgi", $text{'htaccess_return'});


