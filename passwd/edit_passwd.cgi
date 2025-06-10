#!/usr/local/bin/perl
# Show password change form

require './passwd-lib.pl';
&ReadParse();
&error_setup($text{'passwd_err'});

@user = getpwnam($in{'user'});
@user || &error($text{'passwd_euser'});
&can_edit_passwd(\@user) || &error($text{'passwd_ecannot'});
&ui_print_header(undef, $text{'passwd_title'}, "");

print &ui_form_start("save_passwd.cgi", "post");
print &ui_hidden("user", $user[0]);
print &ui_hidden("one", $in{'one'});
print &ui_table_start($text{'passwd_header'}, undef, 2);

# Login and real name
%uconfig = &foreign_config("useradmin");
$user[6] =~ s/,.*$// if ($uconfig{'extra_real'});
$user[6] =~ s/,+$//;
print &ui_table_row($text{'passwd_for'},
	&html_escape($user[0].( $user[6] ? " ($user[6])" : "" )));

# Old password field
if ($access{'old'} == 1 ||
    $access{'old'} == 2 && $user[0] ne $remote_user) {
	print &ui_table_row($text{'passwd_old'},
		&ui_password("old", undef, 30));
	}

# New password
print &ui_table_row($text{'passwd_new'},
	&ui_password("new", undef, 30));

# New password again
if ($access{'repeat'}) {
	print &ui_table_row($text{'passwd_repeat'},
		&ui_password("repeat", undef, 30));
	}

# Force change at next login
if (!$config{'passwd_cmd'} && $access{'expire'}) {
	&foreign_require("useradmin", "user-lib.pl");
	$pft = &useradmin::passfiles_type();
	($uuser) = grep { $_->{'user'} eq $in{'user'} }
			&useradmin::list_users();
	if ($uuser->{'max'} && ($pft == 2 || $pft == 5)) {
		print &ui_table_row(" ",
			&ui_checkbox("expire", 1, $text{'passwd_expire'}, 0));
		}
	}

# Change in other modules
if ($access{'others'} == 2) {
	print &ui_table_row(" ",
		&ui_checkbox("others", 1, $text{'passwd_others'}, 1));
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'passwd_change'} ] ]);

&ui_print_footer($in{'one'} ? ( "/", $text{'index'} ) :
			      ( "", $text{'index_return'} ));

