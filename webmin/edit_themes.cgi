#!/usr/local/bin/perl
# edit_themes.cgi
# Display all themes, and allow installation of a new one

require './webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'themes_title'}, "");

# Display change form
@themes = &list_themes();
if (@themes) {
	print "$text{'themes_desc'}<br>\n";
	print "<form action=change_theme.cgi>\n";
	print "<b>$text{'themes_sel'}</b> <select name=theme>\n";
	foreach $t ( { 'desc' => $text{'themes_default'} },
		     &list_themes() ) {
		printf "<option value='%s' %s>%s\n",
			$t->{'dir'},
			$gconfig{'theme'} eq $t->{'dir'} ? 'selected' : '',
			$t->{'desc'};
		}
	print "</select>\n";
	print "<input type=submit value='$text{'themes_change'}'></form>\n";
	}

if (!&shared_root_directory()) {
	# Display install form
	print &ui_hr();
	print "$text{'themes_installdesc'}<br>\n";
	print "<form action=install_theme.cgi method=post enctype=multipart/form-data>\n";
	print "<input type=radio name=source value=0 checked> $text{'mods_local'}\n";
	print "<input name=file size=40>\n";
	print &file_chooser_button("file", 0, 1),"<br>\n";
	print "<input type=radio name=source value=1> $text{'mods_uploaded'}\n";
	print "<input name=upload type=file size=30><br>\n";
	print "<input type=radio name=source value=2> $text{'mods_ftp'}\n";
	print "<input name=url size=40><br>\n";
	print "<input type=submit value=\"$text{'themes_installok'}\"></form>\n";

	# Display deletion form
	@themes = grep { $gconfig{'theme'} ne $_->{'dir'} } @themes;
	if (@themes) {
		print &ui_hr();
		print "$text{'themes_delete'}<br>\n";
		print "<form action=delete_mod.cgi>\n";
		print "<b>$text{'themes_delok'}</b>\n";
		print "<select name=mod>\n";
		foreach $t (@themes) {
			printf "<option value=%s>%s\n",
				$t->{'dir'}, $t->{'desc'};
			}
		print "</select>\n";
		print "<input type=submit value='$text{'delete'}'></form>\n";
		}
	}

# Display export form
print &ui_hr();
print "$text{'themes_desc4'}<p>\n";

print &ui_form_start("export_mod.cgi/theme.wbt.gz");
print "<table>\n";

print "<tr> <td valign=top><b>$text{'themes_exportmods'}</b></td>\n";
print "<td>",&ui_select("mod", undef,
	[ map { [ $_->{'dir'}, $_->{'desc'} ] } @themes ], 5, 1),
	"</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'mods_exportto'}</b></td>\n";
print "<td>",&ui_radio("to", 0,
	[ [ 0, $text{'mods_exportshow'}."<br>" ],
	  [ 1, &text('mods_exportfile',
		     &ui_textbox("file", undef, 40)) ] ]),"</td> </tr>\n";

print "</table>\n";
print &ui_form_end([ [ "ok", $text{'themes_exportok'} ] ]);

&ui_print_footer("", $text{'index_return'});

