#!/usr/local/bin/perl
# index.cgi
# Display burn profiles and icons for global options

require './burner-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("cdrecord mkisofs", "man", "doc"));

if (!&has_command($config{'cdrecord'})) {
	print "<p>",&text('index_ecdrecord', "<tt>$config{'cdrecord'}</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}

print &ui_subheading($text{'index_profiles'});
@allprofiles = &list_profiles();
@profiles = grep { &can_use_profile($_) } @allprofiles;
if (@profiles) {
	#&show_button();
	@tds = ( "width=5" );
	print &ui_form_start("delete_profiles.cgi", "post");
	@links = ( &select_all_link("d", 1),
		   &select_invert_link("d", 1) );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'index_name'},
				  $text{'index_type'},
				  $text{'index_files'} ], 100, 0, \@tds);
	foreach $p (@profiles) {
		local @cols;
		push(@cols, &ui_link("edit_profile.cgi?id=$p->{'id'}","$p->{'name'}"));
		push(@cols, $text{'index_type'.$p->{'type'}});
		if ($p->{'type'} == 1) {
			push(@cols, $p->{'iso'});
			}
		elsif ($p->{'type'} == 4) {
			push(@cols, $p->{'sdesc'});
			}
		else {
			$sources = "";
			for($i=0; defined($p->{"source_$i"}); $i++) {
				$sources .= "&nbsp;|&nbsp;\n" if ($i);
				$sources .= $p->{"source_$i"};
				}
			push(@cols, $sources);
			}
		print &ui_checked_columns_row(\@cols, \@tds, "d", $p->{'id'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}
elsif (@allprofiles) {
	print "<b>$text{'index_noaccess'}</b><p>\n";
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}
&show_button();

if ($access{'global'}) {
	print &ui_hr();
	@links = ( "edit_mkisofs.cgi", "edit_dev.cgi" );
	@titles = ( $text{'mkisofs_title'}, $text{'dev_title'} );
	@icons = ( "images/mkisofs.gif", "images/dev.gif" );
	&icons_table(\@links, \@titles, \@icons);
	}

&ui_print_footer("/", $text{'index'});

sub show_button
{
if ($access{'create'}) {
	print "<form action=edit_profile.cgi>\n";
	print "<input type=submit value='$text{'index_add'}'>\n";
	print "<select name=type>\n";
	print "<option value=1 checked>$text{'index_type1'}</option>\n";
	print "<option value=2>$text{'index_type2'}</option>\n";
	print "<option value=3>$text{'index_type3'}</option>\n";
	print "<option value=4>$text{'index_type4'}</option>\n";
	print "</select></form>\n";
	}
}

