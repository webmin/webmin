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
$rldef = $version{'number'} >= 7 ? 'prohibit-password' : 'yes';
$root = $rldef if ($root eq "without-password" || !$root);
$deflbl = " (".lc($text{'default'}).")";
@opts = ( [ 'yes', $text{'users_yes'}.
	($rldef eq 'yes' ? $deflbl : "") ] );
if ($version{'type'} eq 'ssh') {
	push(@opts, [ 'nopwd', $text{'users_nopwd'} ]);
	}
else {
	push(@opts, [ 'prohibit-password', $text{'users_nopwd'}.
		($rldef eq 'prohibit-password' ? $deflbl : "") ]);
	if ($version{'number'} >= 2) {
		push(@opts, [ 'forced-commands-only', $text{'users_fcmd'} ]);
		}
	}
push(@opts, [ 'no', $text{'users_no'} ]);
print &ui_table_row($text{'users_root'},
	&ui_select("root", lc($root), \@opts));

# SSH 1 RSA authentication
if (($version{'type'} eq 'ssh' && $version{'number'} < 3) ||
    ($version{'type'} eq 'openssh' && $version{'number'} < 7.3)) {
	$rsa = &find_value("RSAAuthentication", $conf);
	print &ui_table_row($text{'users_rsa'},
		&ui_yesno_radio('rsa', lc($rsa) ne 'no'));
	}

# SSH 2 DSA authentication
if ($version{'type'} eq 'openssh' && $version{'number'} >= 3) {
	$dsa = &find_value("PubkeyAuthentication", $conf);
	print &ui_table_row($text{'users_pkeyauth'},
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
	# Ignore known_hosts files
	$known = &find_value("IgnoreUserKnownHosts", $conf);
	print &ui_table_row($text{'users_known'},
		&ui_yesno_radio("known", lc($known) eq 'yes'));

	if ($version{'number'} > 2.3) {
		# Show login banner from file
		$banner = &find_value("Banner", $conf);
		print &ui_table_row($text{'users_banner'},
			&ui_opt_textbox("banner", $banner, 50,
					$text{'users_banner_def'})." ".
			&file_chooser_button("banner"));
		}
	}
elsif ($version{'type'} eq 'ssh' && $version{'number'} >= 2) {
	# Show login banner from file
	$banner = &find_value("BannerMessageFile", $conf);
	print &ui_table_row($text{'users_banner'},
		&ui_opt_textbox("banner", $banner, 50,
				$text{'users_banner_def'})." ".
		&file_chooser_button("banner"));
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 3) {
	# Authorized keys file (under home)
	$authkeys = &find_value("AuthorizedKeysFile", $conf);
	print &ui_table_row($text{'users_authkeys'},
		&ui_opt_textbox("authkeys", $authkeys, 20,
				$text{'users_authkeys_def'},
				$text{'users_authkeys_set'}));
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 5) {
	# Max login attempts
	$maxauthtries = &find_value("MaxAuthTries", $conf);
	print &ui_table_row($text{'users_maxauthtries'},
		&ui_opt_textbox("maxauthtries", $maxauthtries, 5,
				$text{'default'}." (6)"));
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 5) {
	# Challenge-response support
	my $chall_name = $version{'number'} >= 6.2 ?
		"KbdInteractiveAuthentication" : "ChallengeResponseAuthentication";
	$chal = &find_value($chall_name, $conf);
	my $chall_def = $version{'number'} >= 6.2 ?
		lc($chal) ne 'no' : lc($chal) eq 'yes';
	print &ui_table_row($text{'users_chal'},
		&ui_yesno_radio('chal', $chall_def));
	}

if ($version{'type'} eq 'openssh' && $version{'number'} < 3.7 ||
    $version{'type'} eq 'ssh' && $version{'number'} < 2) {
	# Allow rhosts file authentication?
	$rhostsauth = &find_value("RhostsAuthentication", $conf);
	print &ui_table_row($text{'users_rhostsauth'},
		&ui_yesno_radio("rhostsauth", lc($rhostsauth) eq 'yes'));

	# Allow RSA rhosts file authentication?
	$rhostsrsa = &find_value("RhostsRSAAuthentication", $conf);
	if ($version{'type'} eq 'ssh') {
		print &ui_table_row($text{'users_rhostsrsa'},
			&ui_yesno_radio("rhostsrsa", lc($rhostsrsa) ne 'no'));
		}
	else {
		print &ui_table_row($text{'users_rhostsrsa'},
			&ui_yesno_radio("rhostsrsa", lc($rhostsrsa) eq 'yes'));
		}
	}

# Ignore rhosts files?
$rhosts = &find_value("IgnoreRhosts", $conf);
if ($version{'type'} eq 'ssh') {
	print &ui_table_row($text{'users_rhosts'},
		&ui_yesno_radio("rhosts", lc($rhosts) eq 'yes'));
	}
else {
	print &ui_table_row($text{'users_rhosts'},
		&ui_yesno_radio("rhosts", lc($rhosts) ne 'no'));
	}

# Ignore root's rhosts file?
if ($version{'type'} eq 'ssh') {
	$rrhosts = &find_value("IgnoreRootRhosts", $conf);
	print &ui_table_row($text{'users_rrhosts'},
		&ui_radio("rrhosts", lc($rrhosts) eq 'yes' ? 1 :
				     lc($rrhosts) eq 'no' ? 0 : -1,
			  [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ],
			    [ -1, $text{'users_rrdef'} ] ]));
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

