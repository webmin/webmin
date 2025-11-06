#!/usr/local/bin/perl
# edit_themes.cgi
# Display all themes, and allow installation of a new one

require './usermin-lib.pl';
$access{'themes'} || &error($text{'acl_ecannot'});
&ReadParse();
&ui_print_header(undef, $text{'themes_title'}, "");

&get_usermin_config(\%uconfig);
@themes = &list_visible_themes($uconfig{'theme'});
$prog = "edit_themes.cgi?mode=";

($gtheme) = split(/\s+/, $gconfig{'theme'});
$curr_theme_selected = $gconfig{"theme_$base_remote_user"} || $gtheme;
($curr_theme) = grep { $_->{'dir'} eq $curr_theme_selected } @themes;

# Start tabs
if (@themes) {
        @tabs = ( [ "change", $text{'themes_tabchange'}, $prog."change" ] );
        }
push(@tabs, [ "install", $text{'themes_tabinstall'}, $prog."install" ]);
if (@themes) {
        push(@tabs, [ "delete", $text{'themes_tabdelete'}, $prog."delete" ]);
        }
if (@themes) {
        push(@tabs, [ "export", $text{'themes_tabexport'}, $prog."export" ] );
        }
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || $tabs[0]->[0], 1);

if (@themes) {
        print &ui_tabs_start_tab("mode", "change");
        print "$text{'themes_desc'}<p>\n";
        print &ui_form_start("change_theme.cgi");
        print "<b>$text{'themes_sel'}</b>&nbsp;&nbsp;\n";
        print &ui_select("theme", $uconfig{'theme'},
                [ !$uconfig{'theme'} ? [ '', $text{'themes_default'} ] : (),
                map { [ $_->{'dir'}, &html_escape($_->{'desc'}) ] } @themes ]);
	if ($curr_theme->{'config_link'} &&
	    $uconfig{'theme'} eq $curr_theme->{'dir'}) {
		print &ui_link(
			"@{[&get_webprefix()]}/$curr_theme->{'config_link'}",
			&ui_tag('span', '⚙', 
				{ class => 'theme-config-char',
				  title => $text{'themes_configure'} }),
			'text-link');
		}
        print &ui_form_end([ [ undef, $text{'themes_change'} ] ]);
        print &ui_tabs_end_tab("mode", "change");
	}

# Display install form
print &ui_tabs_start_tab("mode", "install");
print "$text{'themes_installdesc'}<p>\n";
print &ui_form_start("install_theme.cgi", "form-data");
print &ui_radio_table("source", 0,
	[ [ 0, $text{'mods_local'}, &ui_filebox("file", undef ,40) ],
	  [ 1, $text{'mods_uploaded'}, &ui_upload("upload") ],
	  [ 2, $text{'mods_ftp'}, &ui_textbox("url", undef, 40) ] ]);
print &ui_form_end([ [ undef, $text{'themes_installok'} ] ]);
print &ui_tabs_end_tab("mode", "install");

# Display deletion form (for themes not in use)
&get_usermin_config(\%uconfig);
foreach $c (keys %uconfig) {
	if ($c =~ /^theme_(\S+)$/) {
		$utheme{$uconfig{$c}}++ if (defined(getpwnam($1)));
		}
	}
@delthemes = grep { $_->{'dir'} ne $uconfig{'theme'} &&
		 !$utheme{$_->{'dir'}} } @themes;
if (@delthemes) {
	# Display deletion form
        print &ui_tabs_start_tab("mode", "delete");
        print "$text{'themes_delete'}<p>\n";
        print &ui_form_start("delete_mod.cgi");
        print "<b>$text{'themes_delok'}</b>&nbsp;&nbsp;\n";
        print &ui_select("mod", undef,
                [ map { [ $_->{'dir'}, &html_escape($_->{'desc'}) ] }
		      @delthemes ]),"<br>\n";
        print &ui_form_end([ [ undef, $text{'delete'} ] ]);
        print &ui_tabs_end_tab("mode", "delete");
	}

if (@themes) {
	# Display export form
	print &ui_tabs_start_tab("mode", "export");
	print "$text{'themes_desc4'}<p>\n";

	print &ui_form_start("export_mod.cgi/theme.ubt.gz");
	print &ui_table_start(undef, undef, 2);

	print &ui_table_row($text{'themes_exportmods'},
		&ui_select("mod", undef,
		[ map { [ $_->{'dir'}, &html_escape($_->{'desc'}) ] }
		      @themes ], 5, 1));

	print &ui_table_row($text{'mods_exportto'},
		&ui_radio("to", 0,
			[ [ 0, $text{'mods_exportshow'}."<br>" ],
			  [ 1, &text('mods_exportfile',
				     &ui_textbox("file", undef, 40)) ] ]));

	print &ui_table_end();
	print &ui_form_end([ [ "ok", $text{'themes_exportok'} ] ]);
	print &ui_tabs_end_tab("mode", "export");
	}

print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});

