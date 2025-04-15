#!/usr/local/bin/perl
# Linked to from the forgotten password email

BEGIN { push(@INC, "."); };
use WebminCore;
$no_acl_check++;
&init_config();
&ReadParse();
$gconfig{'forgot_pass'} || &error($text{'forgot_ecannot'});
my $forgot_password_link_dir = "$config_directory/forgot-password";
my $forgot_timeout = 10;
&error_setup($text{'forgot_err'});

# Check that the random ID is valid
$in{'id'} =~ /^[a-f0-9]+$/i || &error($text{'forgot_eid'});
my %link;
&read_file("$forgot_password_link_dir/$link{'id'}", \%link) ||
	&error($text{'forgot_eid2'});
time() - $link{'time'} > 60*$forgot_timeout &&
	&error(&text('forgot_etime', $forgot_timeout));

# Get the Webmin user
&foreign_require("acl");
my ($wuser) = grep { $_->{'name'} eq $link{'user'} } &acl::list_users();
$wuser || &error(&text('forgot_euser2',
		"<tt>".&html_escape($link{'user'})."</tt>"));

&ui_print_header(undef, $text{'forgot_title'}, "", undef, undef, 1, 1);

print "<center>\n";
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
		}
	if ($d) {
		# Update in Virtualmin
		}
	elsif ($wuser->{'pass'} eq 'x') {
		# Update in Users and Groups
		}
	else {
		# Update in Webmin
		$wuser->{'pass'} = &encrypt_password($in{'newpass'});
		&modify_user($wuser->{'name'}, $wuser);
		&reload_miniserv();
		}
	}
else {
	# Show password selection form
	print &ui_form_start("forgot.cgi", "post");
	print &ui_hidden("id", $in{'id'});
	print "<b>",&text('forgot_newpass',
			  "<tt>".&html_escape($link{'user'})."</tt>"),"</b>\n",
	      &ui_textbox("newpass", undef, 30),"<p>\n";
	print &ui_form_end([ [ undef, $text{'forgot_passok'} ] ]);
	}
print "</center>\n";

&ui_print_footer();
