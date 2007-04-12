#!/usr/local/bin/perl
# Show one RBAC user

require './rbac-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'user_title1'}, "");
	$access{'users'} || $access{'roles'} || &error($text{'user_ecannot'});
	}
else {
	$users = &list_user_attrs();
	$user = $users->[$in{'idx'}];
	&can_edit_user($user) || &error($text{'user_ecannot'});
	&ui_print_header(undef, $text{'user_title2'}, "");
	}

print &ui_form_start("save_user.cgi", "post");
print &ui_hidden("idx", $in{'idx'}),"\n";
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_table_start($text{'user_header'}, "width=100%", 2);

print &ui_table_row($text{'user_user'},
		    &ui_user_textbox("user", $user->{'user'}));

if ($access{'users'} && $access{'roles'}) {
	print &ui_table_row($text{'user_type'},
			    &ui_select("type", $user->{'attr'}->{'type'},
				       [ [ "", $text{'user_tdefault'} ],
					 [ "normal", $text{'user_tnormal'} ],
					 [ "role", $text{'user_trole'} ] ]));
	}

print &ui_table_row($text{'user_profiles'},
	    &profiles_input("profiles", $user->{'attr'}->{'profiles'}, 1));

if (!$access{'authassign'}) {
	# Can only view auths
	print &ui_table_row($text{'user_auths'},
		    join("<br>", map { "<tt>$_</tt>" }
				     split(/,/, $user->{'attr'}->{'auths'})) ||
		    $text{'user_project1'});
	}
else {
	# Can select them
	print &ui_table_row($text{'user_auths'},
		    &auths_input("auths", $user->{'attr'}->{'auths'}));
	}

print &ui_table_row($text{'user_roles'},
	    &attr_input("roles", $user->{'attr'}->{'roles'}, "role", 1));

$p = $user->{'attr'}->{'project'};
print &ui_table_row($text{'user_project'},
		    &ui_radio("project_def", $p ? 0 : 1,
			      [ [ 1, $text{'user_project1'} ],
				[ 0, $text{'user_project0'} ] ])."\n".
		    &project_input("project", $p));

print &ui_table_row($text{'user_lock'},
		    &ui_radio("lock", $user->{'attr'}->{'lock_after_retries'},
			       [ [ "", $text{'user_ldefault'} ],
				 [ "yes", $text{'yes'} ],
				 [ "no", $text{'no'} ] ]));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("list_users.cgi", $text{'users_return'});

