#!/usr/local/bin/perl
# edit_euser.cgi
# Edit an existing samba user

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pvusers'}")
        unless $access{'view_users'};
# display		
&ui_print_header(undef, $text{'euser_title'}, "");
@ulist = &list_users();
$u = $ulist[$in{'idx'}];

print &ui_form_start("save_euser.cgi", "post");
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'euser_title'}, undef, 2);

print &ui_table_row($text{'euser_name'},
	"<tt>".&html_escape($u->{'name'})."</tt>");

print &ui_table_row($text{'euser_uid'},
	&ui_textbox("uid", $u->{'uid'}, 6));

if ($samba_version >= 3) {
	# In the new Samba, the password field is not really used for locking
	# accounts any more, so don't both with the no access/no password
	# options.
	$pwfield = &ui_radio("ptype", 2,
			     [ [ 2, $text{'euser_currpw'} ],
			       [ 3, $text{'euser_newpw'}." ".
				    &ui_password("pass", undef, 20) ] ]);
	}
else {
	# In the old Samba, you can set the password to deny a login to the
	# account or allow logins without a password
	$locked = ($u->{'pass1'} eq ("X" x 32));
	$nopass = ($u->{'pass1'} =~ /^NO PASSWORD/);
	$pwfield = &ui_radio("ptype", $locked ? 0 : $nopass ? 1 : 2,
			     [ [ 0, $text{'euser_noaccess'} ],
			       [ 1, $text{'euser_nopw'} ],
			       [ 2, $text{'euser_currpw'} ],
			       [ 3, $text{'euser_newpw'}." ".
				    &ui_password("pass", undef, 20) ] ]);
	}
print &ui_table_row($text{'euser_passwd'}, $pwfield);

if (!$u->{'opts'}) {
	# Old-style samba user
	print &ui_table_row($text{'euser_realname'},
		&ui_textbox("realname", $u->{'real'}, 40));

	print &ui_table_row($text{'euser_homedir'},
		&ui_textbox("homedir", $u->{'home'}, 40));

	print &ui_table_row($text{'euser_shell'},
		&ui_textbox("shell", $u->{'shell'}, 15));
	}
else {
	# New-style samba user
	print &ui_hidden("new", 1);
	map { $opt{uc($_)}++ } @{$u->{'opts'}};
	@ol = ($text{'euser_normal'}, "U", $text{'euser_nopwrequired'}, "N",
	       $text{'euser_disable'}, "D", $text{'euser_locked'}, "L" ,$text{'euser_noexpire'}, "X", $text{'euser_trust'}, "W");
	for($i=0; $i<@ol; $i+=2) {
		push(@checks, &ui_checkbox("opts", $ol[$i+1], $ol[$i],
					   $opt{$ol[$i+1]}));
		delete($opt{$ol[$i+1]});
		}
	print &ui_table_row($text{'euser_option'},
		join("<br>\n", @checks));
	foreach $oo (keys %opt) {
		print &ui_hidden("opts", $oo);
		}
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ],
		     [ 'delete', $text{'delete'} ] ]);

&ui_print_footer("edit_epass.cgi", $text{'index_userlist'},
	"", $text{'index_sharelist'});

