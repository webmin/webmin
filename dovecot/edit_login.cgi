#!/usr/local/bin/perl
# Show user and login options

require './dovecot-lib.pl';
&ui_print_header(undef, $text{'login_title'}, "");
$conf = &get_config();

print &ui_form_start("save_login.cgi", "post");
print &ui_table_start($text{'login_header'}, "width=100%", 4);

# SASL authentication realms
$realms = &find_value("auth_realms", $conf);
print &ui_table_row($text{'login_realms'},
	    &ui_opt_textbox("realms", $realms, 40, $text{'login_none'}), 3);

# Default authentication realm
$realm = &find_value(
	&version_atleast("2.4")
		? "auth_default_domain"
		: "auth_default_realm",
	$conf);
print &ui_table_row($text{'login_realm'},
	    &ui_opt_textbox("realm", $realm, 10, $text{'default'}));

# Authentication mechanisms (MD5, etc..)
if (&find("auth_mechanisms", $conf, 2)) {
	# Version 0.99 and 2.0 format
	@mechs = split(/\s+/, &find_value("auth_mechanisms", $conf));
	}
else {
	# version 1.0 format
	@mechs = split(/\s+/, &find_value("mechanisms", $conf, undef,
					  "auth", "default"));
	}
print &ui_table_row($text{'login_mechs'},
    &ui_select("mechs", \@mechs,
	[ map { [ $_, $text{'login_'.$_} || uc($_) ] } @supported_auths ],
	4, 1, 1));

print &ui_table_hr();

# User database, for mapping usernames to UIDs and homes
if (&find("auth_userdb", $conf, 2)) {
	# Version 0.99 format
	$userdb = &find_value("auth_userdb", $conf);
	}
elsif ($usec = &find_section("userdb", $conf, undef, "auth", "default")) {
	# Version 1.0.alpha format
	$userdb = $usec->{'value'};
	$args = &find_value("args", $conf, undef, "userdb", $usec->{'value'});
	$userdb .= " $args" if ($args);
	}
elsif (&find_value("driver", $conf, 2, "userdb")) {
	# Version 2.0 format
	$userdb = &find_value("driver", $conf, undef, "userdb");
	$args = &find_value("args", $conf, undef, "userdb");
	$userdb .= " ".$args if ($args);
	}
else {
	# Version 1.0 format
	$userdb = &find_value("userdb", $conf, undef, "auth", "default");
	}
if ($userdb eq "passwd") {
	$usermode = "passwd";
	}
elsif ($userdb =~ /^passwd-file\s+(.*)/) {
	$usermode = "passwd-file";
	$passwdfile = $1;
	}
elsif ($userdb =~ /^static\s+uid=(\d+)\s+gid=(\d+)\s+home=(.*)/) {
	$usermode = "static";
	$uid = $1;
	$gid = $2;
	$home = $3;
	}
elsif ($userdb eq "vpopmail") {
	$usermode = "vpopmail";
	}
elsif ($userdb =~ /^ldap\s+(.*)/) {
	$usermode = "ldap";
	$ldap = $1;
	}
elsif ($userdb =~ /^pgsql\s+(.*)/) {
	$usermode = "pgsql";
	$pgsql = $1;
	}
elsif ($userdb =~ /^sql\s+(.*)/) {
	$usermode = "sql";
	$sql = $1;
	}
else {
	$other = $userdb;
	}
if (&version_below("2.4")) {
	print &ui_table_row($text{'login_userdb'},
	&ui_radio("usermode", $usermode,
		[ [ "passwd", $text{'login_passwd'}."<br>" ],
		[ "passwd-file", &text('login_passwdfile',
			&ui_textbox("passwdfile", $passwdfile, 30))."<br>" ],
		[ "static", &text('login_static',
			&ui_textbox("uid", $uid, 6),
			&ui_textbox("gid", $gid, 6),
			&ui_textbox("home", $home, 20))."<br>" ],
		[ "vpopmail", $text{'login_vpopmail'}."<br>" ],
		[ "ldap", &text('login_ldap',
			&ui_textbox("ldap", $ldap, 30))."<br>" ],
		[ "pgsql", &text('login_pgsql',
			&ui_textbox("pgsql", $pgsql, 30))."<br>" ],
		[ "sql", &text('login_sql',
			&ui_textbox("sql", $sql, 30))."<br>" ],
		[ "", &text('login_other',
			&ui_textbox("other", $other, 30))."<br>" ],
		]), 3);
	}

# Password authentication system
if (&find("auth_passdb", $conf, 2)) {
	# Version 0.99 format
	$passdb = &find_value("auth_passdb", $conf);
	}
elsif ($psec = &find_section("passdb", $conf, undef, "auth", "default")) {
	# Version 1.0.alpha format
	$passdb = $psec->{'value'};
	$args = &find_value("args", $conf, undef, "passdb", $psec->{'value'});
	$passdb .= " $args" if ($args);
	$alpha_opts = 1;
	}
elsif (&find_value("driver", $conf, 2, "passdb")) {
	# Version 2.0 format
	$passdb = &find_value("driver", $conf, undef, "passdb");
	$args = &find_value("args", $conf, undef, "passdb");
	$passdb .= " ".$args if ($args);
	}
else {
	# Version 1.0 format
	$passdb = &find_value("passdb", $conf, undef, "auth", "default");
	}
if ($passdb eq "passwd") {
	$passmode = "passwd";
	}
elsif ($passdb eq "shadow") {
	$passmode = "shadow";
	}
elsif ($passdb eq "pam") {
	$passmode = "dpam";
	}
elsif ($passdb =~ /^pam(\s+\-session)?(\s+cache_key=(\S+))?\s+(\S*)$/) {
	$passmode = "pam";
	$ppam = $4;
	$psession = $1 ? 1 : 0;
	$pckey = $3;
	}
elsif ($passdb =~ /^passwd-file\s+(.*)/) {
	$passmode = "passwd-file";
	$ppasswdfile = $1;
	}
elsif ($passdb eq "vpopmail") {
	$passmode = "vpopmail";
	}
elsif ($passdb =~ /^ldap\s+(.*)/) {
	$passmode = "ldap";
	$pldap = $1;
	}
elsif ($passdb =~ /^pgsql\s+(.*)/) {
	$passmode = "pgsql";
	$ppgsql = $1;
	}
elsif ($passdb =~ /^sql\s+(.*)/) {
	$passmode = "sql";
	$psql = $1;
	}
elsif ($passdb =~ /^bsdauth(\s+cache_key=(\S+))?$/) {
	$passmode = "bsdauth";
	$pbckey = $2;
	}
elsif ($passdb =~ /^checkpassword\s+(.*)$/) {
	$passmode = "checkpassword";
	$checkpassword = $1;
	}
else {
	$pother = $passdb;
	}

if (&version_below("2.4")) {
	print &ui_table_row($text{'login_passdb'},
	&ui_radio("passmode", $passmode,
		[ [ "passwd", $text{'login_passwd2'}."<br>" ],
		[ "shadow", $text{'login_shadow'}."<br>" ],
		[ "dpam", &text('login_dpam')."<br>" ],
		$alpha_opts ?
		( [ "pam", &text('login_pam2',
			&ui_textbox("ppam", $ppam, 10),
			&ui_checkbox("ppam_session", 1,
				$text{'login_session'}, $psession),
			&ui_opt_textbox("ppam_ckey", $pckey, 10,
					$text{'login_none'}))."<br>" ]
		) :
		( [ "pam", &text('login_pam',
			&ui_textbox("ppam", $ppam, 10))."<br>" ]
		),
		[ "passwd-file", &text('login_passwdfile',
			&ui_textbox("ppasswdfile", $ppasswdfile, 30))."<br>" ],
		[ "vpopmail", $text{'login_vpopmail'}."<br>" ],
		[ "ldap", &text('login_ldap',
			&ui_textbox("pldap", $pldap, 30))."<br>" ],
		[ "pgsql", &text('login_pgsql',
			&ui_textbox("ppgsql", $ppgsql, 30))."<br>" ],
		[ "sql", &text('login_sql',
			&ui_textbox("psql", $psql, 30))."<br>" ],
		$alpha_opts ?
		( [ "bsdauth",
			&text('login_bsdauth',
			&ui_opt_textbox("bsdauth_ckey", $pbckey, 10,
					$text{'login_none'}))."<br>" ],
		[ "checkpassword",
			&text('login_checkpassword',
			&ui_textbox("checkpassword", $checkpassword, 40))."<br>" ],
		) :
		( ),
		[ "", &text('login_other',
			&ui_textbox("pother", $pother, 30))."<br>" ],
		]), 3);

	print &ui_table_hr();
	}

$fuid = &find_value("first_valid_uid", $conf);
print &ui_table_row($text{'login_fuid'},
    &ui_opt_textbox("fuid", $fuid, 6, &getdef("first_valid_uid")));

$luid = &find_value("last_valid_uid", $conf);
@mmap = ( [ 0, $text{'login_none'} ] );
print &ui_table_row($text{'login_luid'},
    &ui_opt_textbox("luid", $luid, 6, &getdef("last_valid_uid", \@mmap)));

$fgid = &find_value("first_valid_gid", $conf);
print &ui_table_row($text{'login_fgid'},
    &ui_opt_textbox("fgid", $fgid, 6, &getdef("first_valid_gid")));

$lgid = &find_value("last_valid_gid", $conf);
print &ui_table_row($text{'login_lgid'},
    &ui_opt_textbox("lgid", $lgid, 6, &getdef("last_valid_gid", \@mmap)));

$extra = &find_value(&version_atleast("2")
			? "mail_access_groups"
			: "mail_extra_groups",
		     $conf);

print &ui_table_row($text{'login_extra'},
	    &ui_opt_textbox("extra", $extra, 50, $text{'login_none'})."\n".
	    &group_chooser_button("extra", 1), 3);

$chroot = &find_value("mail_chroot", $conf);
print &ui_table_row($text{'login_chroot'},
	    &ui_opt_textbox("chroot", $chroot, 40, $text{'login_none'})."\n".
	    &file_chooser_button("chroot", 1), 3);

# Number of login processes
if (&find("login_max_processes_count", $conf, 2)) {
	print &ui_table_hr();
	$procs = &find_value("login_max_processes_count", $conf);
	print &ui_table_row($text{'login_procs'},
	    &ui_opt_textbox("procs", $procs, 6,
			    &getdef("login_max_processes_count")), 3);
	}
if (&find("login_processes_count", $conf, 2)) {
	$count = &find_value("login_processes_count", $conf);
	print &ui_table_row($text{'login_count'},
	    &ui_opt_textbox("count", $count, 6,
			    &getdef("login_processes_count")), 3);
	}


print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

