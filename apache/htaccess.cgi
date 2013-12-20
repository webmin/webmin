#!/usr/local/bin/perl
# htaccess.cgi
# Display a list of per-directory config files

require './apache-lib.pl';
$access{'global'} || &error($text{'htaccess_ecannot'});
&ui_print_header(undef, $text{'htaccess_title'}, "");

print "$text{'htaccess_desc'} <p>\n";

# List of existing files
@htaccess_files = grep { &allowed_auth_file($_) } @htaccess_files;
if (@htaccess_files) {
	print &ui_columns_start([ $text{'htaccess_file'} ]);
	$i = 0;
	foreach $f (@htaccess_files) {
		print &ui_columns_row([
			&ui_link("htaccess_index.cgi?file=".&urlize($htaccess_files[$i]), $htaccess_files[$i])
			]);
		$i++;
		}
	print &ui_columns_end();
	}

# Form to create
print &ui_form_start("create_htaccess.cgi");
print &ui_submit($text{'htaccess_create'}),"\n";
print &ui_textbox("file", undef, 30)." ".
	&file_chooser_button("file", 0, 0);
print &ui_form_end();

# Form to find
print &ui_form_start("find_htaccess.cgi");
print &ui_submit($text{'htaccess_find'}),"\n";

if ($access{'dir'} eq '/') {
	print &ui_radio("from", 0, [ [ 0, $text{'htaccess_auto'} ],
				     [ 1, $text{'htaccess_from'} ] ]);
	}
else {
	print "$text{'htaccess_from'}\n";
	}
print &ui_textbox("dir", $access{'dir'}, 30)." ".
	&file_chooser_button("dir", 1, 1);
print &ui_form_end();

&ui_print_footer("index.cgi?mode=global", $text{'index_return2'});
