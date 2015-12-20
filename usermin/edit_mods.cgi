#!/usr/local/bin/perl
# edit_mods.cgi
# Form for installing and removing usermin modules

require './usermin-lib.pl';
$access{'umods'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'mods_title'}, "");

# Show tabs
@tabs = ( [ "install", $text{'mods_tabinstall'}, "edit_mods.cgi?mode=install" ],
          [ "clone", $text{'mods_tabclone'}, "edit_mods.cgi?mode=clone" ],
          [ "delete", $text{'mods_tabdelete'}, "edit_mods.cgi?mode=delete" ],
          [ "export", $text{'mods_tabexport'}, "edit_mods.cgi?mode=export" ],
        );
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "install", 1);

# Display installation form
print &ui_tabs_start_tab("mode", "install");
print "$text{'mods_desc1'}<p>";

print &ui_form_start("install_mod.cgi", "form-data");
print &ui_table_start($text{'mods_install'}, undef, 2);

print &ui_table_row($text{'mods_installsource'},
        &ui_radio_table("source", 0,
                [ [ 0, $text{'mods_local'},
                    &ui_textbox("file", undef, 40)." ".
                    &file_chooser_button("file", 0) ],
                  [ 1, $text{'mods_uploaded'},
                    &ui_upload("upload", 40) ],
                  [ 2, $text{'mods_ftp'},
                    &ui_textbox("url", undef, 40) ] ]));

print &ui_table_row($text{'mods_nodeps'},
        &ui_yesno_radio("nodeps", 0));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'mods_installok'} ] ]);
print &ui_tabs_end_tab();

# Display cloning form
print &ui_tabs_start_tab("mode", "clone");
@mlist = &list_modules();
print "$text{'mods_desc2'}<p>";

print &ui_form_start("clone_mod.cgi", "post");
print &ui_table_start($text{'mods_clone'}, undef, 2);

# Source module
print &ui_table_row($text{'mods_cname'},
        &ui_select("mod", undef,
                [ map { [ $_->{'dir'}, $_->{'desc'} ] }
                      grep { !$_->{'clone'} } @mlist ]));

# New description
print &ui_table_row($text{'mods_cnew'},
	&ui_textbox("desc", undef, 40));


# New category
&get_usermin_miniserv_config(\%miniserv);
&read_file("$miniserv{'root'}/lang/en", \%utext);
&read_file("$miniserv{'root'}/ulang/en", \%utext);
foreach $t (keys %utext) {
	if ($t =~ /^category_(.*)/) {
		$cats{$1} = $utext{$t};
		}
	}
&read_file("$config{'usermin_dir'}/webmin.catnames", \%catnames);
foreach $t (keys %catnames) {
	$cats{$t} = $catnames{$t};
	}
print &ui_table_row($text{'mods_ccat'},
        &ui_select("cat", "*",
                [ [ "*", $text{'mods_csame'} ],
                  map { [ $_, $cats{$_} ] }
                      sort { lc($a) cmp lc($b) } (keys %cats) ]));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'mods_cloneok'} ] ]);
print &ui_tabs_end_tab();

# Display deletion form
print &ui_tabs_start_tab("mode", "delete");
print "$text{'mods_desc3'}<p>\n";

print &ui_form_start("delete_mod.cgi", "post");
print &ui_table_start($text{'mods_delete'}, undef, 2);

$version = &get_usermin_version();
&get_usermin_miniserv_config(\%miniserv);
$home = $miniserv{'root'} eq '/usr/local/useradmin';
@opts = ( );
foreach $m (@mlist) {
        if (&check_usermin_os_support($m)) {
                my @st = stat("$miniserv{'root'}/$m->{'dir'}");
                my @tm = localtime($st[9]);
                my $vstr = $m->{'version'} == $version ? "" :
                              $m->{'version'} ? "(v. $m->{'version'})" :
                              $home ? "" :
                              sprintf "(%d/%d/%d)",
                                      $tm[3], $tm[4]+1, $tm[5]+1900;
                push(@opts, [ $m->{'dir'}, $m->{'desc'}." ".$vstr ]);
                }
        }
print &ui_table_row(undef,
        &ui_select("mod", undef, \@opts, 10, 1)."<br>\n".
        &ui_checkbox("nodeps", 1, $text{'mods_nodeps2'}, 0), 2);
print &ui_table_end();
print &ui_form_end([ [ "", $text{'mods_deleteok'} ] ]);
print &ui_tabs_end_tab();

# Display export form
print &ui_tabs_start_tab("mode", "export");
print "$text{'mods_desc4'}<p>\n";

print &ui_form_start("export_mod.cgi/module.wbm.gz");
print &ui_table_start($text{'mods_header4'}, undef, 2);

print &ui_table_row($text{'mods_exportmods'},
   	  &ui_select("mod", undef,
		[ map { [ $_->{'dir'}, $_->{'desc'} ] } @mlist ], 10, 1));

print &ui_table_row($text{'mods_exportto'},
	  &ui_radio("to", 0,
		[ [ 0, $text{'mods_exportshow'}."<br>" ],
		  [ 1, &text('mods_exportfile',
			     &ui_textbox("file", undef, 40)) ] ]));

print &ui_table_end();
print &ui_form_end([ [ "ok", $text{'mods_exportok'} ] ]);
print &ui_tabs_end_tab();

print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});

