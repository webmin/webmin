#!/usr/local/bin/perl
# edit_access.cgi
# Display access control SSHd options

require './sshd-lib.pl';
&ui_print_header(undef, $text{'access_title'}, "", "access");
$conf = &get_sshd_config();

print &ui_form_start("save_access.cgi", "post");
print &ui_table_start($text{'access_header'}, "width=100%", 2);

if ($version{'type'} eq 'ssh') {
	# Allowed and denied hosts
	@allowh = &find_value("AllowHosts", $conf);
	print &ui_table_row($text{'access_allowh'},
		&ui_opt_textbox("allowh", join(" ", @allowh), 60,
				$text{'access_all'}));

	@denyh = &find_value("DenyHosts", $conf);
	print &ui_table_row($text{'access_denyh'},
		&ui_opt_textbox("denyh", join(" ", @denyh), 60,
				$text{'access_all'}));

	print &ui_table_hr();
	}

$commas = $version{'type'} eq 'ssh' && $version{'number'} >= 3.2;

# Allowed users
@allowu = &find_value("AllowUsers", $conf);
$allowu = $commas ? join(" ", split(/,/, $allowu[0]))
		  : join(" ", @allowu);
print &ui_table_row($text{'access_allowu'},
	&ui_opt_textbox("allowu", $allowu, 60, $text{'access_all'})." ".
	&user_chooser_button("allowu", 1));

# Allowed groups
@allowg = &find_value("AllowGroups", $conf);
$allowg = $commas ? join(" ", split(/,/, $allowg[0]))
		  : join(" ", @allowg);
print &ui_table_row($text{'access_allowg'},
	&ui_opt_textbox("allowg", $allowg, 60, $text{'access_all'})." ".
	&group_chooser_button("allowg", 1));

# Denied users
@denyu = &find_value("DenyUsers", $conf);
$denyu = $commas ? join(" ", split(/,/, $denyu[0]))
		 : join(" ", @denyu);
print &ui_table_row($text{'access_denyu'},
	&ui_opt_textbox("denyu", $denyu, 60, $text{'access_all'})." ".
	&user_chooser_button("denyu", 1));

# Denied groups
@denyg = &find_value("DenyGroups", $conf);
$denyg = $commas ? join(" ", split(/,/, $denyg[0]))
		 : join(" ", @denyg);
print &ui_table_row($text{'access_denyg'},
	&ui_opt_textbox("denyg", $denyg, 60, $text{'access_all'})." ".
	&group_chooser_button("denyg", 1));

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	print &ui_table_hr();

	# Silently deny users
	$silent = &find_value("SilentDeny", $conf);
	print &ui_table_row($text{'access_silent'},
		&ui_yesno_radio("silent", lc($silent) eq 'yes'));
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

