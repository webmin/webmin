#!/usr/local/bin/perl
# Show form for creating or editing a user

use strict;
use warnings;
require './nginx-lib.pl';
&foreign_require("htaccess-htpasswd");
our (%text, %in, %access);
&ReadParse();
$in{'file'} || &error($text{'users_efile'});

&switch_write_user(1);
my $users = &htaccess_htpasswd::list_users($in{'file'});
&switch_write_user(0);
my $desc = "<tt>".&html_escape($in{'file'})."</tt>";
my $user;
if ($in{'new'}) {
	&ui_print_header($desc, $text{'user_create'}, "");
	$user = { 'enabled' => 1 };
	}
else {
	&ui_print_header($desc, $text{'user_edit'}, "");
	($user) = grep { $_->{'user'} eq $in{'user'} } @$users;
	$user || &error($text{'user_egone'});
	}

print &ui_form_start("save_user.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("file", $in{'file'});
print &ui_hidden("old", $in{'user'});
print &ui_hidden("id", $in{'id'});
print &ui_hidden("path", $in{'path'});
print &ui_table_start($text{'user_header'}, undef, 2);

# Username
print &ui_table_row($text{'user_user'},
	            &ui_textbox("htuser", $user->{'user'}, 30));

# Password
if ($in{'new'}) {
	print &ui_table_row($text{'user_pass'},
			    &ui_textbox("htpass", undef, 20));
	}
else {
	print &ui_table_row($text{'user_pass'},
			    &ui_opt_textbox("htpass", undef, 20,
			      $text{'user_passleave'}, $text{'user_passset'}));
	}

# Enabled?
print &ui_table_row($text{'user_enabled'},
		    &ui_yesno_radio("enabled", $user->{'enabled'}));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_users.cgi?file=".&urlize($in{'file'}).
	  	   "&id=".&urlize($in{'id'})."&path=".&urlize($in{'path'}),
		 $text{'users_return'});

