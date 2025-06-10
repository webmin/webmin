#!/usr/local/bin/perl
# edit_share.cgi
# Display a form for editing a shared directory

require './dfs-lib.pl';
$access{'view'} && &error($text{'ecannot'});
$s = $ARGV[0];

if (defined($s)) {
	&ui_print_header(undef, $text{'edit_title1'}, "", "edit_share");
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "", "create_share");
	}

print &ui_form_start("save_share.cgi", "post");
if (defined($s)) {
	print &ui_hidden("idx", $s),"\n";
	@shlist = &list_shares();
	$share = $shlist[$s];
	}

# Directory and description section
print &ui_table_start($text{'edit_header1'}, "width=100%", 2);

print &ui_table_row(&hlink($text{'edit_dir'}, "dir"),
		    &ui_textbox("directory", $share->{'dir'}, 60)." ".
		    &file_chooser_button("directory", 1));

print &ui_table_row(&hlink($text{'edit_desc'}, "desc"),
		    &ui_textbox("desc", $share->{'desc'}, 60));

print &ui_table_end(),"<p>\n";

print "<table width=100% border>\n";
&parse_options($share->{'opts'});
print "<tr $tb>\n";
print "<td>",&hlink("<b>$text{'edit_ro'}</b>","ro"),"</td>\n";
print "<td>",&hlink("<b>$text{'edit_rw'}</b>","rw"),"</td>\n";
print "<td>",&hlink("<b>$text{'edit_root'}</b>","root"),"</td> </tr>\n";

# $fn = "<font size=-2>"; $efn = "</font>";
print "<tr $cb>\n";
print "<td valign=top>",
      &ui_radio("readonly", !defined($options{"ro"}) ? 0 :
			    $options{"ro"} ? 2 : 1,
		[ [ 0, $text{'edit_none'}."<br>" ],
		  [ 1, $text{'edit_all'}."<br>" ],
		  [ 2, $text{'edit_listed'}."<br>" ] ])."\n".
      &ui_textarea("rolist", join("\n", split(/:/, $options{"ro"})), 8, 25),
      "</td>\n";

print "<td valign=top>",
      &ui_radio("readwrite", !defined($options{"rw"}) ? 0 :
			    $options{"rw"} ? 2 : 1,
		[ [ 0, $text{'edit_none'}."<br>" ],
		  [ 1, $text{'edit_all'}."<br>" ],
		  [ 2, $text{'edit_listed'}."<br>" ] ])."\n".
      &ui_textarea("rwlist", join("\n", split(/:/, $options{"rw"})), 8, 25),
      "</td>\n";

print "<td valign=top>",
      &ui_radio("root", !defined($options{"root"}) ? 0 :
			$options{"root"} ? 2 : 1,
		[ [ 0, $text{'edit_none'}."<br>&nbsp;<br>" ],
		  [ 2, $text{'edit_listed'}."<br>" ] ])."\n".
      &ui_textarea("rtlist", join("\n", split(/:/, $options{"root"})), 8, 25),
      "</td>\n";
print "</tr></table><p>\n";

if (!$access{'simple'}) {
	print &ui_table_start($text{'edit_header2'}, "width=100%", 4);

	print &ui_table_row(&hlink($text{'edit_nosub'}, "sub"),
		    &ui_radio("nosub", defined($options{"nosub"}) ? 1 : 0,
			      [ [ 0, $text{'yes'} ],
				[ 1, $text{'no'} ] ]));

	print &ui_table_row(&hlink($text{'edit_nosuid'}, "suid"),
		    &ui_radio("nosuid", defined($options{"nosuid"}) ? 1 : 0,
			      [ [ 0, $text{'yes'} ],
				[ 1, $text{'no'} ] ]));

	print &ui_table_row(&hlink($text{'edit_des'}, "des"),
		    &ui_radio("secure", defined($options{"secure"}) ? 1 : 0,
			      [ [ 1, $text{'yes'} ],
				[ 0, $text{'no'} ] ]));

	print &ui_table_row(&hlink($text{'edit_kerberos'}, "kerberos"),
		    &ui_radio("kerberos", defined($options{"kerberos"}) ? 1 : 0,
			      [ [ 1, $text{'yes'} ],
				[ 0, $text{'no'} ] ]));

	$user = defined($options{"anon"}) && $options{"anon"} != -1 ?
			getpwuid($options{'anon'}) : undef;
	print &ui_table_row(&hlink($text{'edit_anon'}, "anon"),
		    &ui_radio("anon_m", !defined($options{"anon"}) ? 0 :
					$options{"anon"} == -1 ? 1 : 2,
			      [ [ 0, $text{'edit_anon0'} ],
				[ 1, $text{'edit_anon1'} ],
				[ 2, &ui_user_textbox("anon", $user) ] ]));

	print &ui_table_row(&hlink($text{'edit_aclok'}, "aclok"),
		    &ui_radio("aclok", defined($options{"aclok"}) ? 1 : 0,
			      [ [ 1, $text{'yes'} ],
				[ 0, $text{'no'} ] ]));

	if ($gconfig{'os_version'} >= 7) {
		print &ui_table_row(&hlink($text{'edit_public'}, "public"),
		    &ui_radio("public", defined($options{"public"}) ? 1 : 0,
			      [ [ 1, $text{'yes'} ],
				[ 0, $text{'no'} ] ]));

		print &ui_table_row(&hlink($text{'edit_index'}, "index"),
		    &ui_opt_textbox("index", $options{"index"}, 15,
				    $text{'edit_none'}));
		}

	print &ui_table_end();
	}

if ($s ne "") {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
&ui_print_footer("", $text{'index_return'});


