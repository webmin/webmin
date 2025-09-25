#!/usr/local/bin/perl
# Linked to from the forgotten password email

BEGIN { push(@INC, "."); };
use WebminCore;
$no_acl_check++;
$trust_unknown_referers = 1;
&init_config();
&ReadParse();
&load_theme_library();

&theme_forgot_handler($0) if (defined(&theme_forgot_handler));
&error_setup($text{'forgot_err'});
$gconfig{'forgot_pass'} || &error($text{'forgot_ecannot'});
my $timeout = $gconfig{'passreset_timeout'} || 15;
$remote_user && &error($text{'forgot_elogin'});
$ENV{'HTTPS'} eq 'ON' || $gconfig{'forgot_pass'} == 2 ||
        &error($text{'forgot_essl'});
$ENV{'SSL_CN_CERT'} == 1 ||
	&error(&text('forgot_esslhost',
		     &html_escape($ENV{'HTTP_HOST'} || $ENV{'SSL_CN'})))
			if ($ENV{'HTTPS'} eq 'ON');

# Check that the random ID is valid
$in{'id'} =~ /^[a-f0-9]+$/i || &error($text{'forgot_eid'});
my %link;
my $linkfile = $main::forgot_password_link_dir."/".$in{'id'};
&read_file($linkfile, \%link) || &error($text{'forgot_eid2'});
time() - $link{'time'} > 60*$timeout &&
	&error(&text('forgot_etime', $timeout));

# Check that the hostname in the original email matches the current hostname
my ($basehost) = &parse_http_url(&get_webmin_email_url());
if ($basehost ne $link{'host'}) {
	&error($text{'forgot_ehost'});
	}

# Get the Webmin user
&foreign_require("acl");
my ($wuser) = grep { $_->{'name'} eq $link{'user'} } &acl::list_users();

# Get the Virtualmin mail Unix user if Webmin user is not found
my ($muser, $muserdom);
if (!$wuser && $link{'muser'}) {
	# Probably Virtualmin mail user, so try to find it
	&foreign_require("virtual-server");
	my $d = &virtual_server::get_user_domain(lc($link{'muser'}));
	if ($d) {
		my @u = &virtual_server::list_domain_users($d, 0, 0, 1, 1, 0);
		($muser) = grep { $_->{'user'} eq lc($link{'muser'}) } @u;
		}
	}

# Show an error if neither user was found
!$muser && $link{'muser'} && &error(&text('forgot_euser3',
		"<tt>".&html_escape($link{'muser'})."</tt>"));
$wuser || $muser || &error(&text('forgot_euser2',
		"<tt>".&html_escape($link{'user'})."</tt>"));

# Set the username whichever is available
my $username = $link{'muser'} || $link{'uuser'} || $link{'user'};
my $email = $wuser ? $wuser->{'email'} : 
	    $muser ? $muser->{'recovery'} || $muser->{'email'} : undef;

&ui_print_header(undef, $text{'forgot_title'}, "", undef, undef, 1, 1);

if (defined($in{'newpass'})) {
	# Validate the password
	$in{'newpass'} =~ /\S/ || &error($text{'forgot_enewpass'});
	$in{'newpass'} eq $in{'newpass2'} ||
		&error($text{'forgot_enewpass2'});
	my $perr = &acl::check_password_restrictions(
			$wuser->{'name'}, $in{'newpass'});
	$perr && &error(&text('forgot_equality', $perr));

	# Actually update the password
	my $d;
	if (&foreign_check("virtual-server")) {
		# Is this a Virtualmin domain owner?
		&foreign_require("virtual-server");
		$d = &virtual_server::get_domain_by("user", $link{'user'},
						    "parent", "");
		$d && $d->{'disabled'} && &error($text{'forgot_edisabled'});
		}
	if ($d) {
		# Update in Virtualmin
		print &text('forgot_vdoing',
			&virtual_server::show_domain_name($d)),"<br>\n";
		&virtual_server::push_all_print();
		&virtual_server::set_all_null_print();
		foreach my $d (&virtual_server::get_domain_by("user", $link{'user'})) {
			&virtual_server::lock_domain($d);
			my $oldd = { %$d };
			$d->{'pass'} = $in{'newpass'};
			$d->{'pass_set'} = 1;
			&virtual_server::generate_domain_password_hashes($d, 0);

			# Update all features
			foreach my $f (&virtual_server::domain_features($d)) {
				if ($virtual_server::config{$f} && $d->{$f}) {
					my $mfunc = "virtual_server::modify_$f";
					&$mfunc($d, $oldd);
					}
				}

			# Update all plugins
			foreach my $f (&virtual_server::list_feature_plugins()) {
				if ($d->{$f}) {
					&virtual_server::plugin_call(
					    $f, "feature_modify", $d, $oldd);
					}
				}

			&virtual_server::save_domain($d);
			&virtual_server::unlock_domain($d);
			}
		&virtual_server::run_post_actions();
		&virtual_server::pop_all_print();
		print $text{'forgot_done'},"<p>\n";
		}
	elsif ($muser) {
		# Update in Virtualmin if this is a mail user
		my %oldmuser = %$muser;
		$muser->{'plainpass'} = $in{'newpass'};
		$muser->{'pass'} =
			&virtual_server::encrypt_user_password(
				$muser, $muser->{'plainpass'});
		$muser->{'passmode'} = 3;
		&virtual_server::set_pass_change($muser);
		&virtual_server::modify_user($muser, \%oldmuser, $muserdom);
		}
	elsif ($link{'uuser'} || $wuser->{'pass'} eq 'x') {
		# Update in Users and Groups
		print &text('forgot_udoing',
			"<tt>".&html_escape($username)."</tt>"),"<br>\n";
		&foreign_require("useradmin");
		my ($user) = grep { $_->{'user'} eq $username }
				  &useradmin::list_users();
		$user || &error($text{'forgot_eunix'});
		$user->{'pass'} eq $useradmin::config{'lock_string'} &&
			&error($text{'forgot_eunixlock'});
		my $olduser = { %$user };
		$user->{'passmode'} = 3;
		$user->{'plainpass'} = $in{'newpass'};
		$user->{'pass'} = &useradmin::encrypt_password($in{'newpass'},
							       undef, 1);
		&useradmin::modify_user($olduser, $user);
		&useradmin::other_modules("useradmin_modify_user", $user,
					  $olduser);
		&reload_miniserv();
		print $text{'forgot_done'},"<p>\n";
		}
	else {
		# Update in Webmin
		print &text('forgot_wdoing',
			"<tt>".&html_escape($link{'user'})."</tt>"),"<br>\n";
		$wuser->{'pass'} = &acl::encrypt_password($in{'newpass'});
		&acl::modify_user($wuser->{'name'}, $wuser);
		&reload_miniserv();
		print $text{'forgot_done'},"<p>\n";
		}
	
	# Print link to login for Webmin user
	if (!$muser) {
		print &text('forgot_retry', &get_webprefix()."/",
			    "<tt>".$username."</tt>"),"<p>\n";
		}
	else {
		print &text('forgot_retry2', "<tt>".$username."</tt>"),"<p>\n";
		}

	&webmin_log("forgot", "reset", undef,
		    { 'user' => $username,
		      'unix' => $link{'uuser'} ? 1 : 0,
		      'email' => $email }, "acl");

	&unlink_logged($linkfile);
	}
else {
	# Show password selection form
	print "<center>\n";
	print &ui_form_start("forgot.cgi", "post");
	print &ui_hidden("id", $in{'id'});
	print &ui_table_start(undef, undef, 2);
	print &ui_table_row(
		&text('forgot_newpass',
		      "<tt>".&html_escape($username)."</tt>"),
		&ui_password("newpass", undef, 30));
	print &ui_table_row(
		$text{'forgot_newpass2'},
		&ui_password("newpass2", undef, 30));
	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'forgot_passok'} ] ]);
	print "</center>\n";
	}

&ui_print_footer();
