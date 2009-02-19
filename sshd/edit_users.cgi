#!/usr/local/bin/perl
# edit_users.cgi
# Display user and group related SSHd options

require './sshd-lib.pl';
&ui_print_header(undef, $text{'users_title'}, "", "users");
$conf = &get_sshd_config();

print &ui_form_start("save_users.cgi", "post");
print &ui_table_start($text{'users_header'}, "width=100%", 2);

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	# Days before account expires to warn
	$expire = &find_value("AccountExpireWarningDays", $conf);
	print &ui_table_row($text{'users_expire'},
		&ui_opt_textbox("expire", $expire, 5,
				$text{'users_expire_def'}));
	}

# Notify users of new email
$mail = &find_value("CheckMail", $conf);
if ($version{'type'} eq 'ssh') {
	print &ui_table_row($text{'users_mail'},
		&ui_yesno_radio("mail", lc($mail) ne 'no'));
	}
elsif ($version{'number'} < 3.1) {
	print &ui_table_row($text{'users_mail'},
		&ui_yesno_radio("mail", lc($mail) eq 'yes'));
	}

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	# Days before password expires to warn
	$pexpire = &find_value("PasswordExpireWarningDays", $conf);
	print &ui_table_row($text{'users_pexpire'},
		&ui_opt_textbox("pexpire", $pexpire, 5,
				$text{'users_pexpire_def'}));
	}

if ($version{'type'} ne 'ssh' || $version{'number'} < 3) {
	# Allow password authentication?
	$auth = &find_value("PasswordAuthentication", $conf);
	print &ui_table_row($text{'users_auth'},
		&ui_yesno_radio("auth", lc($auth) ne 'no'));
	}

# Allow empty passwords?
$pempty = &find_value("PermitEmptyPasswords", $conf);
if ($version{'type'} eq 'ssh') {
	print &ui_table_row($text{'users_pempty'},
		&ui_yesno_radio("pempty", lc($pempty) ne 'no'));
	}
else {
	print &ui_table_row($text{'users_pempty'},
		&ui_yesno_radio("pempty", lc($pempty) eq 'yes'));
	}

# Allow logins by root
$root = &find_value("PermitRootLogin", $conf);
if (!$root) {
	# Default ways seems to be 'yes'
	$root = "yes";
	}
@opts = ( [ 'yes', $text{'yes'} ],
	  [ 'no', $text{'no'} ] );
if ($version{'type'} eq 'ssh') {
	push(@opts, [ 'nopwd', $text{'users_nopwd'} ]);
	}
else {
	push(@opts, [ 'without-password', $text{'users_nopwd'} ]);
	if ($version{'number'} >= 2) {
		push(@opts, [ 'forced-commands-only', $text{'users_fcmd'} ]);
		}
	}
print "</select></td>\n";
print &ui_table_row($text{'users_root'},
	&ui_select("root", lc($root), \@opts));

# SSH 1 RSA authentication
if ($version{'type'} ne 'ssh' || $version{'number'} < 3) {
	$rsa = &find_value("RSAAuthentication", $conf);
	print &ui_table_row($text{'users_rsa'},
		&ui_yesno_radio('rsa', lc($rsa) ne 'no'));
	}

# SSH 2 DSA authentication
if ($version{'type'} eq 'openssh' && $version{'number'} >= 3) {
	$rsa = &find_value("PubkeyAuthentication", $conf);
	print &ui_table_row($text{'users_dsa'},
		&ui_yesno_radio('dsa', lc($dsa) ne 'no'));
	}

# Strictly check permissions
$strict = &find_value("StrictModes", $conf);
print &ui_table_row($text{'users_strict'},
	&ui_yesno_radio('strict', lc($strict) ne 'no'));

# Show message of the day
$motd = &find_value("PrintMotd", $conf);
print &ui_table_row($text{'users_motd'},
	&ui_yesno_radio('motd', lc($motd) ne 'no'));

if ($version{'type'} eq 'openssh') {
	&scmd();
	$known = &find_value("IgnoreUserKnownHosts", $conf);
	print "<td><b>$text{'users_known'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=known value=1 %s> %s\n",
		lc($known) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=known value=0 %s> %s</td>\n",
		lc($known) eq 'yes' ? "" : "checked", $text{'no'};
	&ecmd();

	if ($version{'number'} > 2.3) {
		&scmd(1);
		$banner = &find_value("Banner", $conf);
		print "<td><b>$text{'users_banner'}</b></td> <td colspan=3>\n";
		printf "<input type=radio name=banner_def value=1 %s> %s\n",
			$banner ? "" : "checked", $text{'users_banner_def'};
		printf "<input type=radio name=banner_def value=0 %s>\n",
			$banner ? "checked" : "";
		print "<input name=banner size=40 value='$banner'>\n",
		      &file_chooser_button("banner"),"</td>\n";
		&ecmd();
		}
	}
elsif ($version{'type'} eq 'ssh' && $version{'number'} >= 2) {
	&scmd(1);
	$banner = &find_value("BannerMessageFile", $conf);
	print "<td><b>$text{'users_banner'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=banner_def value=1 %s> %s\n",
		$banner ? "" : "checked", $text{'users_banner_def'};
	printf "<input type=radio name=banner_def value=0 %s>\n",
		$banner ? "checked" : "";
	print "<input name=banner size=40 value='$banner'>\n",
	      &file_chooser_button("banner"),"</td>\n";
	&ecmd();
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 3) {
	&scmd(1);
	$authkeys = &find_value("AuthorizedKeysFile", $conf);
	print "<td><b>$text{'users_authkeys'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=authkeys_def value=1 %s> %s\n",
		$authkeys ? "" : "checked", $text{'users_authkeys_def'};
	printf "<input type=radio name=authkeys_def value=0 %s>\n",
		$authkeys ? "checked" : "";
	print "<input name=authkeys size=40 value='$authkeys'></td>\n";
	&ecmd();
	}

&scmd(1);
print "<td colspan=4><hr></td>\n";
&ecmd();

if ($version{'type'} eq 'openssh' && $version{'number'} < 3.7 ||
    $version{'type'} eq 'ssh' && $version{'number'} < 2) {
	&scmd();
	$rhostsauth = &find_value("RhostsAuthentication", $conf);
	print "<td><b>$text{'users_rhostsauth'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=rhostsauth value=1 %s> %s\n",
		lc($rhostsauth) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=rhostsauth value=0 %s> %s</td>\n",
		lc($rhostsauth) eq 'yes' ? "" : "checked", $text{'no'};
	&ecmd();

	&scmd();
	$rhostsrsa = &find_value("RhostsRSAAuthentication", $conf);
	print "<td><b>$text{'users_rhostsrsa'}</b></td> <td nowrap>\n";
	if ($version{'type'} eq 'ssh') {
		printf "<input type=radio name=rhostsrsa value=1 %s> %s\n",
			lc($rhostsrsa) eq 'no' ? "" : "checked", $text{'yes'};
		printf "<input type=radio name=rhostsrsa value=0 %s> %s</td>\n",
			lc($rhostsrsa) eq 'no' ? "checked" : "", $text{'no'};
		}
	else {
		printf "<input type=radio name=rhostsrsa value=1 %s> %s\n",
			lc($rhostsrsa) eq 'yes' ? "checked" : "", $text{'yes'};
		printf "<input type=radio name=rhostsrsa value=0 %s> %s</td>\n",
			lc($rhostsrsa) eq 'yes' ? "" : "checked", $text{'no'};
		}
	&ecmd();
	}

&scmd();
$rhosts = &find_value("IgnoreRhosts", $conf);
print "<td><b>$text{'users_rhosts'}</b></td> <td nowrap>\n";
if ($version{'type'} eq 'ssh') {
	printf "<input type=radio name=rhosts value=1 %s> %s\n",
		lc($rhosts) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=rhosts value=0 %s> %s</td>\n",
		lc($rhosts) eq 'yes' ? "" : "checked", $text{'no'};
	}
else {
	printf "<input type=radio name=rhosts value=1 %s> %s\n",
		lc($rhosts) eq 'no' ? "" : "checked", $text{'yes'};
	printf "<input type=radio name=rhosts value=0 %s> %s</td>\n",
		lc($rhosts) eq 'no' ? "checked" : "", $text{'no'};
	}
&ecmd();

if ($version{'type'} eq 'ssh') {
	&scmd(1);
	$rrhosts = &find_value("IgnoreRootRhosts", $conf);
	print "<td><b>$text{'users_rrhosts'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=rrhosts value=1 %s> %s\n",
		lc($rrhosts) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=rrhosts value=0 %s> %s\n",
		lc($rrhosts) eq 'no' ? "checked" : "", $text{'no'};
	printf "<input type=radio name=rrhosts value=-1 %s> %s</td>\n",
		$rrhosts ? "" : "checked", $text{'users_rrdef'};
	&ecmd();
	}

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

