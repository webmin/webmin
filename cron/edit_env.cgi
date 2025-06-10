#!/usr/local/bin/perl
# edit_env.cgi
# Edit an existing or new environment variable

require './cron-lib.pl';
&ReadParse();

if (!$in{'new'}) {
	@jobs = &list_cron_jobs();
	$env = $jobs[$in{'idx'}];
	&can_edit_user(\%access, $env->{'user'}) ||
		&error($text{'edit_ecannot'});
	&ui_print_header(undef, $text{'env_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'env_title2'}, "");
	$env = { 'active' => 1 };
	}

print "$text{'env_order'}<p>\n";

print &ui_form_start("save_env.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'env_details'}, "width=100%", 2);

# Under user
if ($access{'mode'} == 1) {
	$usel = &ui_select("user", $env->{'user'},
		[ split(/\s+/, $access{'users'}) ]);
	}
elsif ($access{'mode'} == 3) {
	$usel = "<tt>$remote_user</tt>";
	print &ui_hidden("user", $remote_user);
	}
else {
	$usel = &ui_user_textbox("user", $env->{'user'});
	}
print &ui_table_row($text{'env_user'}, $usel);

# Active or now
print &ui_table_row($text{'env_active'},
	&ui_yesno_radio("active", $env->{'active'} ? 1 : 0));

# Variable name
print &ui_table_row($text{'env_name'},
	&ui_textbox("name", $env->{'name'}, 50));

# Variable value
print &ui_table_row($text{'env_value'},
	&ui_textbox("value", $env->{'value'}, 50));

if ($in{'new'}) {
	# Location for new variable
	print &ui_table_row($text{'env_where'},
	      &ui_radio("where", 1, [ [ 1, $text{'env_top'} ],
				      [ 0, $text{'env_bot'} ] ]));
	}
elsif ($env->{'index'}) {
	# Location for existing
	print &ui_table_row($text{'env_where2'},
	      &ui_radio("where", 0, [ [ 1, $text{'env_top'} ],
				      [ 0, $text{'env_leave'} ]]));
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

