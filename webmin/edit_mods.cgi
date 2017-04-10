#!/usr/local/bin/perl
# edit_mods.cgi
# Form for installing and removing modules

require './webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'mods_title'}, "");
@mlist = sort { $a->{'desc'} cmp $b->{'desc'} }
	      grep { &check_os_support($_) } &get_all_module_infos();
$version = &get_webmin_version();

if (&shared_root_directory()) {
	&ui_print_endpage($text{'mods_eroot'});
	}

# Show tabs
@tabs = ( [ "install", $text{'mods_tabinstall'}, "edit_mods.cgi?mode=install" ],
	  [ "clone", $text{'mods_tabclone'}, "edit_mods.cgi?mode=clone" ],
	  [ "delete", $text{'mods_tabdelete'}, "edit_mods.cgi?mode=delete" ],
	  [ "export", $text{'mods_tabexport'}, "edit_mods.cgi?mode=export" ],
	);
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "install", 1);

# Display installation form
print &ui_tabs_start_tab("mode", "install");
print "$text{'mods_desc1'}<p>\n";

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
		    &ui_textbox("url", undef, 40) ],
		  [ 3, $config{'standard_url'} ? $text{'mods_standard2'} :
			 &text('mods_standard',
			       "http://www.webmin.com/standard.html"),
		    &ui_textbox("standard", undef, 20)." ".
		    &standard_chooser_button("standard") ],
		  [ 4, $text{'mods_third'},
		    &ui_textbox("third", undef, 40)." ".
		    &third_chooser_button("third") ] ]));

print &ui_table_row($text{'mods_nodeps'},
	&ui_yesno_radio("nodeps", 0));

print &ui_table_row($text{'mods_grantto'},
	&ui_radio("grant", 0,
		  [ [ 0, $text{'mods_grant2'}." ".
			 &ui_textbox("grantto", $base_remote_user, 30)."<br>" ],
		    [ 1, $text{'mods_grant1'} ] ]));

print &ui_table_row($text{'mods_checksig'},
	&ui_yesno_radio("checksig", 0));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'mods_installok'} ] ]);
print &ui_tabs_end_tab();

# Display cloning form
print &ui_tabs_start_tab("mode", "clone");
print "$text{'mods_desc2'}<p>";

print &ui_form_start("clone_mod.cgi", "post");
print &ui_table_start($text{'mods_clone'}, undef, 2);

# Source module
print &ui_table_row($text{'mods_cname'},
	&ui_select("mod", undef,
		[ map { [ $_->{'dir'}, $_->{'desc'} ] }
		      grep { $_->{'dir'} ne 'webmin' && !$_->{'clone'} }
			   @mlist ]));

# New description
print &ui_table_row($text{'mods_cnew'},
	&ui_textbox("desc", undef, 40));

# New category
%cats = &list_categories(\@mlist, 1);
print &ui_table_row($text{'mods_ccat'},
	&ui_select("cat", "*",
		[ [ "*", $text{'mods_csame'} ],
		  map { [ $_, $cats{$_} ] }
		      sort { lc($a) cmp lc($b) } (keys %cats) ]));

print &ui_table_row($text{'mods_creset'},
	&ui_yesno_radio("creset", 0));

print &ui_table_end();
print &ui_form_end([ [ "", $text{'mods_cloneok'} ] ]);
print &ui_tabs_end_tab();

# Display deletion form
print &ui_tabs_start_tab("mode", "delete");
print "$text{'mods_desc3'}<p>\n";

print &ui_form_start("delete_mod.cgi", "post");
print &ui_table_start($text{'mods_delete'}, undef, 2);

my $home = $root_directory eq '/usr/local/webadmin';
@opts = ( );
foreach $m (@mlist) {
	if ($m->{'dir'} ne 'webmin' && &check_os_support($m)) {
		my @st = stat(&module_root_directory($m->{'dir'}));
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
		[ map { [ $_->{'dir'},
			  $_->{'desc'}.($_->{'version'} == $version ? "" :
				$_->{'version'} ? "(v. $_->{'version'})" : "")
			] } @mlist ], 10, 1));

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

