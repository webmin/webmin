#!/usr/local/bin/perl
# Show a table of all user attributes

require './rbac-lib.pl';
&ui_print_header(undef, $text{'users_title'}, "", "users");

$users = &list_user_attrs();
@canusers = grep { &can_edit_user($_) } @$users;
if (@canusers) {
	print &ui_link("edit_user.cgi?new=1",$text{'users_add'}),"<br>\n";
	print &ui_columns_start(
		[ $text{'users_user'},
		  $text{'users_type'},
		  $text{'users_role'},
		  $text{'users_project'},
		  $text{'users_profiles'},
		  $text{'users_auths'} ]);
	foreach $u (sort { $a->{'user'} cmp $b->{'user'} } @canusers) {
		print &ui_columns_row(
			[ &ui_link("edit_user.cgi?idx=$u->{'index'}",$u->{'user'}),
			  $text{'user_t'.$u->{'attr'}->{'type'}} ||
			    $u->{'attr'}->{'type'} ||
			    $text{'user_tnormal'},
			  &nice_comma_list($u->{'attr'}->{'roles'}),
			  $u->{'attr'}->{'project'},
			  &nice_comma_list($u->{'attr'}->{'profiles'}),
			  &nice_comma_list($u->{'attr'}->{'auths'}),
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'users_none'}</b><p>\n";
	}
print &ui_link("edit_user.cgi?new=1",$text{'users_add'}),"<br>\n";

&ui_print_footer("", $text{"index_return"});
