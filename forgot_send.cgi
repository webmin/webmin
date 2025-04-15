#!/usr/local/bin/perl
# Send a forgotten password reset email

BEGIN { push(@INC, "."); };
use WebminCore;
$no_acl_check++;
&init_config();
&ReadParse();
$gconfig{'forgot_pass'} || &error($text{'forgot_ecannot'});
$forgot_password_link_dir = "$config_directory/forgot-password";

# Lookup the Webmin user
&foreign_require("acl");
my ($wuser) = grep { lc($_->{'name'}) eq lc($in{'forgot'}) } &acl::list_users();
$wuser && $wuser->{'email'} || &error($text{'forgot_euser'});
($wuser->{'sync'} || $wuser->{'pass'} eq 'e') && &error($text{'forgot_esync'});
$wuser->{'pass'} eq '*LK*' && &error($text{'forgot_elock'});
my $email = $wuser->{'email'};

# Generate a random ID for this password reset
my %link = ( 'id' => &generate_random_id(),
	     'remote' => $ENV{'REMOTE_ADDR'},
	     'time' => time(),
	     'user' => $wuser->{'user'} );
$link{'id'} || &error($text{'forgot_erandom'});
&make_dir($forgot_password_link_dir, 0700);
&write_file("$forgot_password_link_dir/$link{'id'}", \%link);
my $baseurl = &get_webmin_email_url();
my $url = $baseurl.'/forgot.cgi?id='.&urlize($link{'id'});

&ui_print_header(undef, $text{'forgot_title'}, "", undef, undef, 1, 1);

# Send email with a link to generate the reset form
&foreign_require("mailboxes");
my $msg = &text('forgot_msg', $wuser->{'name'}, $url, $ENV{'REMOTE_HOST'},
			      $baseurl);
$msg =~ s/\\n/\n/g;
$msg = join("\n", &mailboxes::wrap_lines($msg, 75))."\n";
my $subject = $text{'forgot_subject'};
&mailboxes::send_text_mail(&mailboxes::get_from_address(),
			   $email,
			   undef,
			   $subject,
			   $msg);

# Tell the user
print "<center>\n";
print &text('forgot_sent', "<tt>".&html_escape($email)."</tt>",
		   "<tt>".&html_escape($wuser->{'name'})."</tt>"),"<p>\n";
print "</center>\n";

&ui_print_footer();

# generate_random_id()
# Generate an ID string that can be used for a password reset link
sub generate_random_id
{
if (open(my $RANDOM, "</dev/urandom")) {
	my $sid;
	my $tmpsid;
	if (read($RANDOM, $tmpsid, 16) == 16) {
		$sid = lc(unpack('h*',$tmpsid));
		}
	close($RANDOM);
	return $sid;
	}
return undef;
}

