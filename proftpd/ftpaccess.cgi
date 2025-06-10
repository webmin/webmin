#!/usr/local/bin/perl
# ftpaccess.cgi
# Display a list of per-directory config files

require './proftpd-lib.pl';
&ui_print_header(undef, $text{'ftpaccess_title'}, "",
	undef, undef, undef, undef, &restart_button());

print "$text{'ftpaccess_desc'} <p>\n";
if (@ftpaccess_files) {
	foreach my $f (@ftpaccess_files) {
		push(@grid, &ui_link("ftpaccess_index.cgi?file=".&urlize($f),
				     &html_escape($f)));
		}
	print &ui_grid_table(\@grid, 4, "100%"),"<p>\n";
	}

print &ui_form_start("create_ftpaccess.cgi");
print &ui_submit($text{'ftpaccess_create'}),"\n";
print &ui_filebox("file", undef, 60);
print &ui_form_end(),"<p>\n";

print &ui_form_start("find_ftpaccess.cgi");
print &ui_submit($text{'ftpaccess_find'}),"\n";
print &ui_radio("from", 0, [ [ 0, $text{'ftpaccess_auto'} ],
			     [ 1, $text{'ftpaccess_from'} ] ]),"\n";
print &ui_filebox("dir", undef, 60, 0, undef, undef, 1);
print &ui_form_end(),"<p>\n";

&ui_print_footer("", $text{'index_return'});

