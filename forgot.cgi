#!/usr/local/bin/perl
# Linked to from the forgotten password email

BEGIN { push(@INC, "."); };
use WebminCore;
$no_acl_check++;
$trust_unknown_referers = 1;
&init_config();
&ReadParse();
$gconfig{'forgot_pass'} || &error($text{'forgot_ecannot'});
my $forgot_password_link_dir = "$config_directory/forgot-password";
my $forgot_timeout = 10;
&error_setup($text{'forgot_err'});

# Check that the random ID is valid
$in{'id'} =~ /^[a-f0-9]+$/i || &error($text{'forgot_eid'});
my %link;
&read_file("$forgot_password_link_dir/$in{'id'}", \%link) ||
	&error($text{'forgot_eid2'});
time() - $link{'time'} > 60*$forgot_timeout &&
	&error(&text('forgot_etime', $forgot_timeout));

# Get the Webmin user
&foreign_require("acl");
my ($wuser) = grep { $_->{'name'} eq $link{'user'} } &acl::list_users();
$wuser || &error(&text('forgot_euser2',
		"<tt>".&html_escape($link{'user'})."</tt>"));

&ui_print_header(undef, $text{'forgot_title'}, "", undef, undef, 1, 1);

if (defined($in{'newpass'})) {
	# Validate the password
	$in{'newpass'} =~ /\S/ || &error($text{'forgot_enewpass'});
	my $perr = &acl::check_password_restrictions(
			$wuser->{'name'}, $in{'newpass'});
	$perr && &error(&text('forgot_equality', $perr));

	# Actually update the password
	if (&foreign_check("virtual-server")) {
		# Is this a Virtualmin domain owner?
		&foreign_require("virtual-server");
		$d = &virtual_server::get_domain_by("user", $link{'user'},
						    "parent", "");
		$d->{'disabled'} && &error($text{'forgot_edisabled'});
		}
	if ($d) {
		# Update in Virtualmin
		print &text('forgot_vdoing',
			&virtual_server::show_domain_name($d)),"<br>\n";
		foreach my $d (&virtual_server::get_domain_by("user", $link{'user'})) {
			&virtual_server::lock_domain($d);
			my $oldd = { %$d };
			$d->{'pass'} = $in{'newpass'};
			$d->{'pass_set'} = 1;
			&virtual_server::generate_domain_password_hashes($d, 0);

			# Update all features
			foreach my $f (&virtual_server::domain_features($d)) {
				if ($virtual_server::config{$f} && $d->{$f}) {
					my $mfunc = "virtual_server::modify_".$f;
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
		print $text{'forgot_done'},"<p>\n";
		}
	elsif ($wuser->{'pass'} eq 'x') {
		# Update in Users and Groups
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
	print &text('forgot_retry', '/'),"<p>\n";

	&unlink_file("$forgot_password_link_dir/$in{'id'}");
	}
else {
	# Show password selection form
	print "<center>\n";
	print &ui_form_start("forgot.cgi", "post");
	print &ui_hidden("id", $in{'id'});
	print "<b>",&text('forgot_newpass',
			  "<tt>".&html_escape($link{'user'})."</tt>"),"</b>\n",
	      &ui_textbox("newpass", undef, 30),"<p>\n";
	print &ui_form_end([ [ undef, $text{'forgot_passok'} ] ]);
	print "</center>\n";
	}

&ui_print_footer();
