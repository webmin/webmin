#!/usr/local/bin/perl
# edit_user.cgi
# Display a form for editing or creating a htpasswd user

require './htaccess-lib.pl';
&ReadParse();
@dirs = &list_directories();
($dir) = grep { $_->[0] eq $in{'dir'} } @dirs;
&can_access_dir($dir->[0]) || &error($text{'dir_ecannot'});
&switch_user();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	$user = { 'enabled' => 1 };
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "");
	$users = $dir->[2] == 3 ? &list_digest_users($dir->[1])
				: &list_users($dir->[1]);
	$user = $users->[$in{'idx'}];
	}

print &ui_form_start("save_user.cgi", "post");
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("new", $in{'new'});
print &ui_hidden("dir", $in{'dir'});
print &ui_table_start($text{'edit_header'}, undef, 2);

# Username
print &ui_table_row($text{'edit_user'},
	&ui_textbox("htuser", $user->{'user'}, 40));

# User enabled?
print &ui_table_row($text{'edit_enabled'},
	&ui_yesno_radio("enabled", $user->{'enabled'} ? 1 : 0));

# Password
if ($in{'new'}) {
	print &ui_table_row($text{'edit_pass'},
		&ui_textbox("htpass", undef, 20));
	}
else {
	print &ui_table_row($text{'edit_pass'},
		&ui_opt_textbox("htpass", undef, 20, $text{'edit_pass1'},
				$text{'edit_pass0'}));
	}

if ($dir->[2] == 3) {
	# Digest realm
	print &ui_table_row($text{'edit_dom'},
		&ui_textbox("dom", $user->{'dom'}, 40));
	}

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

