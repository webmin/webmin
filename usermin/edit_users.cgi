#!/usr/local/bin/perl
# edit_users.cgi
# Display user access control form

require './usermin-lib.pl';
$access{'users'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'users_title'}, "");
&get_usermin_miniserv_config(\%miniserv);

print $text{'users_desc'}," ",$text{'users_desc2'},"<p>\n";

print &ui_form_start("change_users.cgi", "post");
print &ui_table_start($text{'users_header'}, undef, 2);

$txt = $miniserv{"allowusers"} ?
		join("\n", split(/\s+/, $miniserv{"allowusers"})) :
       $miniserv{"denyusers"} ?
		join("\n", split(/\s+/, $miniserv{"denyusers"})) : "";
print &ui_table_row(undef,
	&ui_radio("access", $miniserv{"denyusers"} ? 2 :
			    $miniserv{"allowusers"} ? 1 : 0,
		  [ [ 0, $text{'users_all'} ],
		    [ 1, $text{'users_allow'} ],
		    [ 2, $text{'users_deny'} ] ])."<br>\n".
	&ui_textarea("user", $txt, 6, 60));

if (&get_usermin_version() > 0.95) {
	print &ui_table_row(undef,
		&ui_checkbox("shells_deny", 1, $text{'users_shells'},
			     $miniserv{'shells_deny'})." ".
		&ui_filebox("shells", $miniserv{'shells_deny'} || "/etc/shells",
			    40));
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

