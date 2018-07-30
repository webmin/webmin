#!/usr/local/bin/perl
# index.cgi
# Display installed perl modules and a form for installing new ones

require './cpan-lib.pl';
$ver = &get_nice_perl_version();
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		 undef, undef, undef, &text('index_pversion', $ver));
&ReadParse();

# Check if Perl is installed from a global zone
if (&shared_perl_root()) {
	print "<b>$text{'index_ezone'}</b><p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}
$formno = 0;

# Start tabs
@mods = &list_perl_modules();
@tabs = (
	  [ 'install', $text{'index_tabinstall'}, 'index.cgi?mode=install' ],
	  [ 'mods', $text{'index_tabmods'}, 'index.cgi?mode=mods' ],
	  [ 'suggest', $text{'index_tabsuggest'}, 'index.cgi?mode=suggest' ],
	);
$in{'mode'} ||= 'install';
print &ui_tabs_start(\@tabs, 'mode', $in{'mode'}, 1);

# Display install form
print &ui_tabs_start_tab('mode', 'install');
print "$text{'index_installmsg'}<p>\n";
print &ui_form_start("download.cgi", "form-data");

# Work out of packages should be refreshed
@st = stat($packages_file);
if (@st) {
	$now = time();
	$refreshopt = "<br>".&ui_checkbox("refresh", 1, $text{'index_refresh'},
			$st[9]+$config{'refresh_days'}*24*60*60 < $now);
	}
if ($config{'incyum'} && &can_list_packaged_modules()) {
	$cpanopt = "<br>".&ui_checkbox("forcecpan", 1,
				       $text{'index_forcecpan'}, 0);
	}

@opts = ( [ 3, $text{'index_cpan'},
	    &ui_textbox("cpan", undef, 50)." ".
	    &ui_button("...", undef, 0, "onClick='window.ifield = document.forms[$formno].cpan; chooser = window.open(\"cpan.cgi\", \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=800,height=500\"); chooser.ifield = window.ifield;'").
	    $refreshopt.$cpanopt ],
	  [ 0, $text{'index_local'},
	    &ui_textbox("local", undef, 50)." ".
	    &file_chooser_button("local", 0) ],
	  [ 1, $text{'index_uploaded'},
	    &ui_upload("upload", 50) ],
	  [ 2, $text{'index_ftp'},
	    &ui_textbox("url", undef, 50) ]
	 );
print &ui_radio_table("source", 3, \@opts);
print &ui_form_end([ [ undef, $text{'index_installok'} ] ]);
print &ui_tabs_end_tab();

# Display perl modules
print &ui_tabs_start_tab('mode', 'mods');
if (@mods) {
	print &ui_form_start("uninstall_mods.cgi", "post");
	print &select_all_link("d", 1),"\n";
	print &select_invert_link("d", 1),"<br>\n";
	@tds = ( "width=5", undef, undef, undef, undef, "nowrap" );
	print &ui_columns_start([ "",
				  $text{'index_name'},
				  $text{'index_sub'},
				  $text{'index_desc'},
				  $text{'index_ver'},
				  $text{'index_date'} ], 100, 0, \@tds);
	foreach $m (sort { lc($a->{'mods'}->[$a->{'master'}]) cmp
			   lc($b->{'mods'}->[$b->{'master'}]) } @mods) {
		local $mi = $m->{'master'};
		local @cols;
		local $master = $m->{'mods'}->[$mi];
		local $name = &html_escape($master);
		if ($m->{'pkg'}) {
			$name = "<b>$name</b>";
			}
		push(@cols, "<a href='edit_mod.cgi?idx=$m->{'index'}&".
			    "midx=$mi&name=$mod->{'name'}'>$name</a>");
		push(@cols, @{$m->{'mods'}} - 1);
		local ($desc, $ver) = &module_desc($m, $mi);
		push(@cols, &html_escape($desc));
		push(@cols, $ver);
		push(@cols, &make_date($m->{'time'}));
		print &ui_checked_columns_row(\@cols, \@tds, "d", $m->{'name'});
		}
	print &ui_columns_end();
	print &select_all_link("d", 1),"\n";
	print &select_invert_link("d", 1),"<br>\n";
	print &ui_form_end([ [ "delete", $text{'index_delete'} ],
			     [ "upgrade", $text{'index_upgrade'} ] ]);
	$formno++;
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}
print &ui_tabs_end_tab();

# Show button to install recommended Perl modules
print &ui_tabs_start_tab('mode', 'suggest');
@allrecs = &get_recommended_modules();
@recs = grep { eval "use $_->[0]"; $@ } @allrecs;
if (@recs) {
	print &ui_form_start("download.cgi");
	print &ui_hidden("source", 3),"\n";
	print "$text{'index_recs'}<p>\n";
	print &ui_multi_select("cpan",
		 [ map { [ $_->[0],
			   &text('index_user', $_->[0], $_->[1]->{'desc'}) ] }
		       @recs ],
		 [ map { [ $_->[0],
			   &text('index_user', $_->[0], $_->[1]->{'desc'}) ] }
		       @recs ],
		 20, 1, 0,
		 $text{'index_allmods2'}, $text{'index_wantmods'}, 300),"<br>\n";
	print &ui_submit($text{'index_recsok'});
	print &ui_form_end();
	}
elsif (@allrecs) {
	print &text('index_recsgot',"<tt>".join(" ", map { $_->[0] } @allrecs)."</tt>"),"<p>\n";
	}
print &ui_tabs_end_tab();

print &ui_tabs_end(1);

&ui_print_footer("/", $text{'index'});

