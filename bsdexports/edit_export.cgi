#!/usr/local/bin/perl
# edit_export.cgi
# Display a form for editing or creating an export

require './bsdexports-lib.pl';
&ReadParse();

if (defined($in{'index'})) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	@exp = &list_exports();
	%exp = %{$exp[$in{'index'}]};
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "");
	}

print &ui_form_start("save_export.cgi", "post");
if (%exp) {
	print &ui_hidden("index", $in{'index'}),"\n";
	}
print &ui_table_start($text{'edit_header1'}, "width=100%", 4);

print "<tr> <td valign=top rowspan=3><b>$text{'edit_dirs'}</b></td>\n";
print "<td rowspan=3>",
      &ui_textarea("dirs", join("\n", @{$exp{'dirs'}}), 4, 30),"</td>\n";

print "<td><b>$text{'edit_alldirs'}</b></td>\n";
print "<td>",&ui_yesno_radio("alldirs", $exp{'alldirs'} ? 1 : 0),
      "</td> </tr>\n";

print "<tr> <td><b>$text{'edit_ro'}</b></td>\n";
print "<td>",&ui_yesno_radio("ro", $exp{'ro'} ? 1 : 0),
      "</td> </tr>\n";

print "<tr> <td><b>$text{'edit_kerb'}</b></td>\n";
print "<td>",&ui_yesno_radio("kerb", $exp{'kerb'} ? 1 : 0),
      "</td> </tr>\n";

print &ui_table_end();

print &ui_table_start($text{'edit_header2'}, "width=100%", 2);

$user = $exp{'maproot'} =~ /^([^:]+)/ ? $1 : "";
$groups = $exp{'maproot'} =~ /:(.*)$/ ? join(' ', split(/:/, $1)) : "";
print &ui_table_row($text{'edit_maproot'},
		    &ui_radio("maproot_def", $exp{'maproot'} ? 0 : 1,
			      [ [ 1, $text{'edit_unpriv'}."<br>" ],
				[ 0, $text{'edit_uid'} ] ])."\n".
		    &ui_textbox("maproot", $user, 8)."\n".
		    &ui_checkbox("maprootg_def", 1, $text{'edit_gids'},
				 $exp{'maproot'} =~ /:/)."\n".
		    &ui_textbox("maprootg", $groups, 30));

$user = $exp{'mapall'} =~ /^([^:]+)/ ? $1 : "";
$groups = $exp{'mapall'} =~ /:(.*)$/ ? join(' ', split(/:/, $1)) : "";
print &ui_table_row($text{'edit_mapall'},
		    &ui_radio("mapall_def", $exp{'mapall'} ? 0 : 1,
			      [ [ 1, $text{'edit_unpriv'}."<br>" ],
				[ 0, $text{'edit_uid'} ] ])."\n".
		    &ui_textbox("mapall", $user, 8)."\n".
		    &ui_checkbox("mapallg_def", 1, $text{'edit_gids'},
				 $exp{'mapall'} =~ /:/)."\n".
		    &ui_textbox("mapallg", $groups, 30));

print &ui_table_end();

print &ui_table_start($text{'edit_header3'}, "width=100%", 2);

print &ui_table_row($text{'edit_clients'},
    &ui_radio("cmode", $exp{'mask'} ? 1 : 0,
	      [ [ 0, $text{'edit_hosts'}." ".
		     &ui_textbox("hosts", join(' ', @{$exp{'hosts'}}), 40).
		     "<br>" ],
		[ 1, $text{'edit_network'}." ".
		     &ui_textbox("network", $exp{'network'}, 20)." ".
		     $text{'edit_mask'}." ".
		     &ui_textbox("mask", $exp{'mask'}, 20) ] ]));

print &ui_table_end();

if (%exp) {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

