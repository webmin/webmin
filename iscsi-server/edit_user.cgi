#!/usr/local/bin/perl
# Show a form to edit or create a user

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text, %in);
&ReadParse();

# Get the user, or create a new one
my $user;
if ($in{'new'}) {
	&ui_print_header(undef, $text{'user_create'}, "");
	$user = { 'mode' => 'chap' };
	}
else {
	&ui_print_header(undef, $text{'user_edit'}, "");
	($user) = grep { $_->{'user'} eq $in{'user'} } &list_iscsi_users();
	$user || &error($text{'user_egone'});
	}

# Show editing form
print &ui_form_start("save_user.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("old", $in{'user'});
print &ui_table_start($text{'user_header'}, undef, 2);

# Username
print &ui_table_row($text{'user_user'},
	&ui_textbox("iuser", $user->{'user'}, 40));

# Authentication method
print &ui_table_row($text{'user_mode'},
	&ui_select("imode", lc($user->{'mode'}),
		   [ [ "none", $text{'user_modenone'} ],
		     [ "chap", "CHAP" ] ], 1, 0, 1));

# Password
print &ui_table_row($text{'user_pass'},
	&ui_textbox("ipass", $user->{'pass'}, 20));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_users.cgi", $text{'users_return'});
