#!/usr/local/bin/perl
# Display DAV server options

require './usermin-lib.pl';
&ui_print_header(undef, $text{'dav_title'}, "");
&get_usermin_miniserv_config(\%miniserv);

print $text{'dav_desc'},"<p>\n";

# Check for need Perl modules
foreach $m ("Filesys::Virtual::Plain", "Filesys::Virtual", "Net::DAV::Server",
	    "HTTP::Request") {
	eval "use $m";
	if ($@) {
		# Missing!
		print &text('dav_emodule', "<tt>$m</tt>"),"\n";
		if (&foreign_available("cpan")) {
			print &text('dav_cpan', "../cpan/download.cgi?source=3&cpan=$m&mode=2&return=/$module_name/&returndesc=".&urlize($text{'index_return'})),"\n";
			}
		print "<p>\n";
		&ui_print_footer("", $text{'index_return'});
		exit;
		}
	}

print &ui_form_start("save_dav.cgi", "post");
print &ui_table_start($text{'dav_header'}, undef, 2);

# Allowed paths
print &ui_table_row($text{'dav_path'},
	&ui_radio("path_def", $miniserv{'davpaths'} ? 0 : 1,
	  [ [ 1, $text{'dav_disabled'} ],
	    [ 0, &text('dav_enabled',
		   &ui_textbox("path", $miniserv{'davpaths'} || "/dav", 30)) ] ]
		));

# Root directory
$rmode = $miniserv{'dav_root'} eq '' ? 0 :
	 $miniserv{'dav_root'} eq '*' ? 1 : 2;
print &ui_table_row($text{'dav_root'},
	&ui_radio("root_def", $rmode,
	  [ [ 0, $text{'dav_root0'} ],
	    [ 1, $text{'dav_root1'} ],
	    [ 2, &text('dav_root2',
		&ui_textbox("root", $rmode == 2 ? $miniserv{'dav_root'} : undef,
			     30)) ] ]));

# Allowed users
print &ui_table_row($text{'dav_users'},
	&ui_radio("users_def", $miniserv{'dav_users'} ? 0 : 1,
		  [ [ 1, $text{'dav_users1'} ],
		    [ 0,  $text{'dav_users0'} ] ])."<br>\n".
	&ui_textarea("users", join("\n", split(/\s+/, $miniserv{'dav_users'})),
		     5, 40));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

