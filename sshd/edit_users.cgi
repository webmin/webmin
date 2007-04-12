#!/usr/local/bin/perl
# edit_users.cgi
# Display user and group related SSHd options

require './sshd-lib.pl';
&ui_print_header(undef, $text{'users_title'}, "", "users");
$conf = &get_sshd_config();

print "<form action=save_users.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'users_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	&scmd();
	$expire = &find_value("AccountExpireWarningDays", $conf);
	print "<td><b>$text{'users_expire'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=expire_def value=1 %s> %s\n",
		$expire ? "" : "checked", $text{'users_expire_def'};
	printf "<input type=radio name=expire_def value=0 %s>\n",
		$expire ? "checked" : "";
	print "<input name=expire size=3 value='$expire'></td>\n";
	&ecmd();
	}

$mail = &find_value("CheckMail", $conf);
if ($version{'type'} eq 'ssh') {
	&scmd();
	print "<td><b>$text{'users_mail'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=mail value=1 %s> %s\n",
		lc($mail) eq 'no' ? "" : "checked", $text{'yes'};
	printf "<input type=radio name=mail value=0 %s> %s</td>\n",
		lc($mail) eq 'no' ? "checked" : "", $text{'no'};
	&ecmd();
	}
elsif ($version{'number'} < 3.1) {
	&scmd();
	print "<td><b>$text{'users_mail'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=mail value=1 %s> %s\n",
		lc($mail) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=mail value=0 %s> %s</td>\n",
		lc($mail) eq 'yes' ? "" : "checked", $text{'no'};
	&ecmd();
	}

# XXX are these supported?
#$empty = &find_value("ForcedEmptyPasswdChange", $conf);
#print "<tr> <td><b>$text{'users_empty'}</b></td> <td>\n";
#printf "<input type=radio name=empty value=1 %s> %s\n",
#	lc($empty) eq 'yes' ? "checked" : "", $text{'yes'};
#printf "<input type=radio name=empty value=0 %s> %s</td>\n",
#	lc($empty) eq 'yes' ? "" : "checked", $text{'no'};

#$passwd = &find_value("ForcedPasswdChange", $conf);
#print "<td><b>$text{'users_passwd'}</b></td> <td>\n";
#printf "<input type=radio name=passwd value=1 %s> %s\n",
#	lc($passwd) eq 'no' ? "" : "checked", $text{'yes'};
#printf "<input type=radio name=passwd value=0 %s> %s</td> </tr>\n",
#	lc($passwd) eq 'no' ? "checked" : "", $text{'no'};

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	&scmd();
	$pexpire = &find_value("PasswordExpireWarningDays", $conf);
	print "<td><b>$text{'users_pexpire'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=pexpire_def value=1 %s> %s\n",
		$pexpire ? "" : "checked", $text{'users_pexpire_def'};
	printf "<input type=radio name=pexpire_def value=0 %s>\n",
		$pexpire ? "checked" : "";
	print "<input name=pexpire size=3 value='$pexpire'></td>\n";
	&ecmd();
	}

if ($version{'type'} ne 'ssh' || $version{'number'} < 3) {
	&scmd();
	$auth = &find_value("PasswordAuthentication", $conf);
	print "<td><b>$text{'users_auth'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=auth value=1 %s> %s\n",
		lc($auth) eq 'no' ? "" : "checked", $text{'yes'};
	printf "<input type=radio name=auth value=0 %s> %s</td>\n",
		lc($auth) eq 'no' ? "checked" : "", $text{'no'};
	&ecmd();
	}

&scmd();
$pempty = &find_value("PermitEmptyPasswords", $conf);
print "<td><b>$text{'users_pempty'}</b></td> <td nowrap>\n";
if ($version{'type'} eq 'ssh') {
	printf "<input type=radio name=pempty value=1 %s> %s\n",
		lc($pempty) eq 'no' ? "" : "checked", $text{'yes'};
	printf "<input type=radio name=pempty value=0 %s> %s</td>\n",
		lc($pempty) eq 'no' ? "checked" : "", $text{'no'};
	}
else {
	printf "<input type=radio name=pempty value=1 %s> %s\n",
		lc($pempty) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=pempty value=0 %s> %s</td>\n",
		lc($pempty) eq 'yes' ? "" : "checked", $text{'no'};
	}
&ecmd();

&scmd();
$root = &find_value("PermitRootLogin", $conf);
if (!$root) {
	# Default ways seems to be 'yes'
	$root = "yes";
	}
print "<td><b>$text{'users_root'}</b></td> <td nowrap><select name=root>\n";
printf "<option value=yes %s> %s\n",
	lc($root) eq 'yes' || !$root ? "selected" : "", $text{'yes'};
printf "<option value=no %s> %s\n",
	lc($root) eq 'no' ? "selected" : "", $text{'no'};
if ($version{'type'} eq 'ssh') {
	printf "<option value=nopwd %s> %s\n",
		lc($root) eq 'nopwd' ? "selected" : "", $text{'users_nopwd'};
	}
else {
	printf "<option value=without-password %s> %s\n",
		lc($root) eq 'without-password' ? "selected" : "",
		$text{'users_nopwd'};
	if ($version{'number'} >= 2) {
		printf "<option value=forced-commands-only %s> %s\n",
			lc($root) eq 'forced-commands-only' ? "selected" : "",
			$text{'users_fcmd'};
		}
	}
print "</select></td>\n";
&ecmd();

if ($version{'type'} ne 'ssh' || $version{'number'} < 3) {
	&scmd();
	$rsa = &find_value("RSAAuthentication", $conf);
	print "<td><b>$text{'users_rsa'}</b></td> <td nowrap>\n";
	printf "<input type=radio name=rsa value=1 %s> %s\n",
		lc($rsa) eq 'no' ? "" : "checked", $text{'yes'};
	printf "<input type=radio name=rsa value=0 %s> %s</td>\n",
		lc($rsa) eq 'no' ? "checked" : "", $text{'no'};
	&ecmd();
	}

&scmd();
$strict = &find_value("StrictModes", $conf);
print "<td><b>$text{'users_strict'}</b></td> <td nowrap>\n";
printf "<input type=radio name=strict value=1 %s> %s\n",
	lc($strict) eq 'no' ? "" : "checked", $text{'yes'};
printf "<input type=radio name=strict value=0 %s> %s</td>\n",
	lc($strict) eq 'no' ? "checked" : "", $text{'no'};
&ecmd();

&scmd();
$motd = &find_value("PrintMotd", $conf);
print "<td><b>$text{'users_motd'}</b></td> <td nowrap>\n";
printf "<input type=radio name=motd value=1 %s> %s\n",
	lc($motd) eq 'no' ? "" : "checked", $text{'yes'};
printf "<input type=radio name=motd value=0 %s> %s</td>\n",
	lc($motd) eq 'no' ? "checked" : "", $text{'no'};
&ecmd();

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

