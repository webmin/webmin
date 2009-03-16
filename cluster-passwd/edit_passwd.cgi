#!/usr/local/bin/perl
# edit_passwd.cgi

require './cluster-passwd-lib.pl';
&ReadParse();
&error_setup($text{'passwd_err'});

@ulist = &get_all_users();
($user) = grep { $_->{'user'} eq $in{'user'} } @ulist;
$user || &error($text{'passwd_euser'});

&can_edit_passwd($user) || &error($passwd::text{'passwd_ecannot'});

# Show password change form
&ui_print_header(undef, $passwd::text{'passwd_title'}, "");

print &ui_form_start("save_passwd.cgi", "post");
print &ui_hidden("user", $user->{'user'});
print &ui_hidden("one", $in{'one'});
print &ui_table_start($passwd::text{'passwd_header'}, undef, 2);

$user->{'real'} =~ s/,.*$//;
print &ui_table_row($passwd::text{'passwd_for'},
		    $user->{'user'}.
	            ($user->{'real'} ? " ($user->{'real'})" : ""));

if ($access{'old'} == 1 ||
    $access{'old'} == 2 && $user->{'user'} ne $remote_user) {
	print &ui_table_row($passwd::text{'passwd_old'},
			    &ui_password("old", undef, 25));
	}

print &ui_table_row($passwd::text{'passwd_new'},
		    &ui_password("new", undef, 25));

if ($access{'repeat'}) {
	print &ui_table_row($passwd::text{'passwd_repeat'},
			    &ui_password("repeat", undef, 25));
	}

if ($access{'others'} == 2) {
	print &ui_table_row(undef,
	    &ui_checkbox("others", 1, $passwd::text{'passwd_others'}, 1), 2);
	}

print &ui_table_row(undef,
		    &ui_submit($passwd::text{'passwd_change'})."\n".
		    &ui_reset($passwd::text{'passwd_reset'}), 2);
print &ui_table_end();
print &ui_form_end();

&ui_print_footer($in{'one'} ? ( "/", $text{'index'} )
			    : ( "", $passwd::text{'index_return'} ));

