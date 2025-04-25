#!/usr/local/bin/perl
# Send a forgotten password reset email

BEGIN { push(@INC, "."); };
use WebminCore;
$no_acl_check++;
&init_config();
&ReadParse();
&load_theme_library();

&error_setup($text{'forgot_err'});
$gconfig{'forgot_pass'} || &error($text{'forgot_ecannot'});
&theme_forgot_handler($0) if (defined(&theme_forgot_handler));
$remote_user && &error($text{'forgot_elogin'});

# Slow down the rate of password reset requests (plus needs better check by IP
# to limit the number of requests per IP in a given time period)
sleep(1);

# Lookup the Webmin user
&foreign_require("acl");
my ($wuser) = grep { lc($_->{'name'}) eq lc($in{'forgot'}) } &acl::list_users();
$wuser && $wuser->{'email'} || &error($text{'forgot_euser'});
($wuser->{'sync'} || $wuser->{'pass'} eq 'e') && &error($text{'forgot_esync'});
$wuser->{'pass'} eq '*LK*' && &error($text{'forgot_elock'});
my $email = $wuser->{'email'};

# Check if the IP or Webmin user is over it's rate limit
&make_dir($main::forgot_password_link_dir, 0700);
my $ratelimit_file = $main::forgot_password_link_dir."/ratelimit";
&lock_file($ratelimit_file);
my %ratelimit;
&read_file($ratelimit_file, \%ratelimit);
my $now = time();
my $rlerr;
foreach my $key ($ENV{'REMOTE_ADDR'}, $wuser->{'name'}, $wuser->{'email'}) {
	if (!$ratelimit{$key."_last"} ||
	    $ratelimit{$key."_last"} < $now-5*60) {
		# More than 5 mins since the last try, so reset counter
		$ratelimit{$key} = 1;
		}
	else {
		$ratelimit{$key}++;
		}
	$ratelimit{$key."_last"} = $now;
	if ($ratelimit{$key} > 10) {
		# More than 10 attempts in the last 5 minutes!
		$rlerr = &text('forgot_erate',
			       "<tt>".&html_escape($key)."</tt>");
		last;
		}
	}

# Clean up old ratelimit entries
my $cutoff = $now - 24*60*60;
my @cleanup;
foreach my $k (keys %ratelimit) {
	if ($k =~ /^(.*)_last$/ && $ratelimit{$k} < $cutoff) {
		push(@cleanup, $k);
		push(@cleanup, $1);
		}
	}
foreach my $k (@cleanup) {
	delete($ratelimit{$k});
	}
&write_file($ratelimit_file, \%ratelimit);
&unlock_file($ratelimit_file);
&error($rlerr) if ($rlerr);

# Generate a random ID for this password reset
my %link = ( 'id' => &generate_random_id(),
	     'remote' => $ENV{'REMOTE_ADDR'},
	     'time' => $now,
	     'user' => $wuser->{'name'} );
$link{'id'} || &error($text{'forgot_erandom'});
&write_file("$main::forgot_password_link_dir/$link{'id'}", \%link);
my $baseurl = &get_webmin_email_url();
my $url = $baseurl.'/forgot.cgi?id='.&urlize($link{'id'});
$url = &theme_forgot_url($baseurl, $link{'id'}, $link{'user'})
	if (defined(&theme_forgot_url));

&ui_print_header(undef, $text{'forgot_title'}, "", undef, undef, 1, 1);

# Send email with a link to generate the reset form
&foreign_require("mailboxes");
my $msg = &text('forgot_msg', $wuser->{'name'}, $url, $ENV{'REMOTE_HOST'},
			      $baseurl);
$msg =~ s/\\n/\n/g;
$msg = join("\n", &mailboxes::wrap_lines($msg, 75))."\n";
my $subject = &text('forgot_subject', $wuser->{'name'});
&mailboxes::send_text_mail(&mailboxes::get_from_address(),
			   $email,
			   undef,
			   $subject,
			   $msg);

# Tell the user
print "<center>\n";
print &text('forgot_sent',
	    "<tt>".&html_escape(&obsfucate_email($email))."</tt>",
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

# obsfucate_email(email)
# Convert an email like foo@bar.com to f**@b**.com
sub obsfucate_email
{
my ($email) = @_;
my ($mailbox, $dom) = split(/\@/, $email);
$mailbox = substr($mailbox, 0, 1) . ("*" x (length($mailbox)-1));
my @doms;
foreach my $d (split(/\./, $dom)) {
	push(@doms, substr($d, 0, 1) . ("*" x (length($d)-1)));
	}
return $mailbox."\@".join(".", @doms);
}
