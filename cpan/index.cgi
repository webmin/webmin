#!/usr/local/bin/perl
# index.cgi
# Display installed perl modules and a form for installing new ones

require './cpan-lib.pl';
$ver = join(".", map { ord($_) } split(//, $^V));
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		 undef, undef, undef, &text('index_pversion', $ver));

# Display perl modules
@mods = &list_perl_modules();
if (@mods) {
	print &ui_form_start("uninstall_mods.cgi", "post");
	print &select_all_link("d", 0),"\n";
	print &select_invert_link("d", 0),"<br>\n";
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
	print &select_all_link("d", 0),"\n";
	print &select_invert_link("d", 0),"<br>\n";
	print &ui_form_end([ [ "delete", $text{'index_delete'} ],
			     [ "upgrade", $text{'index_upgrade'} ] ]);
	print "<hr>\n";
	}

# Display install form
print "$text{'index_installmsg'}<p>\n";
print "<form action=download.cgi method=post enctype=multipart/form-data>\n";
print "<input type=radio name=source value=3 checked> $text{'index_cpan'}\n";
print "<input name=cpan size=40>\n";
print "<input type=button onClick='window.ifield = document.forms[0].cpan; chooser = window.open(\"cpan.cgi\", \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=400,height=300\")' value=\"...\">\n";
@st = stat($packages_file);
if (@st) {
	$now = time();
	print "<br>&nbsp;&nbsp;&nbsp;\n";
	printf "<input type=checkbox name=refresh value=1 %s> %s\n",
		$st[9]+$config{'refresh_days'}*24*60*60 < $now ? "checked" : "",
		$text{'index_refresh'};
	}
print "<br>\n";

print "<input type=radio name=source value=0> $text{'index_local'}\n";
print "<input name=local size=50>\n";
print &file_chooser_button("local", 0); print "<br>\n";

print "<input type=radio name=source value=1> $text{'index_uploaded'}\n";
print "<input type=file name=upload size=20><br>\n";

print "<input type=radio name=source value=2> $text{'index_ftp'}\n";
print "<input name=url size=50><br>\n";
print "<input type=submit value=\"$text{'index_installok'}\">\n";
print "</form>\n";

# Show button to install recommended Perl modules
@allrecs = &get_recommended_modules();
@recs = grep { eval "use $_->[0]"; $@ } @allrecs;
if (@recs) {
	print "<hr>\n";
	print &ui_form_start("download.cgi");
	print &ui_hidden("source", 3),"\n";
	print "$text{'index_recs'}<p>\n";
	print &ui_select("cpan", [ map { $_->[0] } @recs ],
		 [ map { [ $_->[0], "$_->[0] ($_->[1]->{'desc'})" ] } @allrecs],
		 5, 1),"<br>\n";
	print &ui_submit($text{'index_recsok'});
	print &ui_form_end();
	}
elsif (@allrecs) {
	print "<hr>\n";
	print &text('index_recsgot',"<tt>".join(" ", map { $_->[0] } @allrecs)."</tt>"),"<p>\n";
	}

&ui_print_footer("/", $text{'index'});

