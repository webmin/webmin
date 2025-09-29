#!/usr/local/bin/perl
# Send a forgotten password reset email

BEGIN { push(@INC, "."); };
use WebminCore;
$no_acl_check++;
&init_config();
&ReadParse();
&load_theme_library();

&theme_forgot_handler($0) if (defined(&theme_forgot_handler));
&error_setup($text{'forgot_err'});
$gconfig{'forgot_pass'} || &error($text{'forgot_ecannot'});
$remote_user && &error($text{'forgot_elogin'});
$ENV{'HTTPS'} eq 'ON' || $gconfig{'forgot_pass'} == 2 ||
        &error($text{'forgot_essl'});
$ENV{'SSL_CN_CERT'} == 1 ||
	&error(&text('forgot_esslhost',
 		     &html_escape($ENV{'HTTP_HOST'} || $ENV{'SSL_CN'})))
		     	if ($ENV{'HTTPS'} eq 'ON');

# Lookup the Webmin user
&foreign_require("acl");
my ($wuser) = grep { lc($_->{'name'}) eq lc($in{'forgot'}) } &acl::list_users();
my $uuser;
if (!$wuser) {
	# Webmin user doesn't exist, but maybe this Unix user can sudo?
	&foreign_require("useradmin");
	($uuser) = grep { lc($_->{'user'}) eq lc($in{'forgot'}) }
			&useradmin::list_users();
	if ($uuser && &useradmin::can_user_sudo_root($uuser->{'user'}) == 1) {
		# Use the Webmin root user's email for recovery
		($wuser) = grep { $_->{'name'} eq 'root' } &acl::list_users();
		}
	}

# If no Webmin user, then try to get mail user from Virtualmin
my $muser;
if (!$wuser && &foreign_check("virtual-server")) {
	# Probably in Virtualmin, so try to find the user
	&foreign_require("virtual-server");
	my $d = &virtual_server::get_user_domain(lc($in{'forgot'}));
	if ($d) {
		my @u = &virtual_server::list_domain_users($d, 0, 0, 1, 1, 0);
		($muser) = grep { $_->{'user'} eq lc($in{'forgot'}) } @u;
		}
	}

my $email = $wuser ? $wuser->{'email'} : 
	    $muser ? $muser->{'recovery'} || $muser->{'email'} : undef;

# Check if the IP or Webmin user is over it's rate limit
&make_dir($main::forgot_password_link_dir, 0700);
my $ratelimit_file = $main::forgot_password_link_dir."/ratelimit";
&lock_file($ratelimit_file);
my %ratelimit;
&read_file($ratelimit_file, \%ratelimit);
my $now = time();
my $rlerr;
my $maxtries = 0;
my $pfailures = $gconfig{'passreset_failures'} // 3;
my $ptime = $gconfig{'passreset_time'} // 60;
foreach my $key ($ENV{'REMOTE_ADDR'},
		 $wuser ? ( $wuser->{'name'} ) : ( ),
		 $uuser ? ( $uuser->{'user'} ) : ( ),
		 $muser ? ( $muser->{'user'} ) : ( ),
		 $email ? ( $email ) : ( )) {
	# Don't block if disabled
	next if (!$pfailures || !$ptime);

	if (!$ratelimit{$key."_last"} ||
	    $ratelimit{$key."_last"} < $now-$ptime*60) {
		# More than 60 mins since the last try, so reset counter
		$ratelimit{$key} = 1;
		}
	else {
		$ratelimit{$key}++;
		}
	$maxtries = $ratelimit{$key} if ($ratelimit{$key} > $maxtries);
	$ratelimit{$key."_last"} = $now;
	if ($ratelimit{$key} > $pfailures) {
		# More than 3 attempts in the last 60 minutes!
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
sleep($maxtries);
&error($rlerr) if ($rlerr);

# Make sure the Webmin user exists and is eligible for a reset
(($wuser && $email) || ($muser && $email)) || &error($text{'forgot_euser'});
($wuser->{'sync'} || $wuser->{'pass'} eq 'e') && &error($text{'forgot_esync'});
$wuser->{'pass'} eq '*LK*' && &error($text{'forgot_elock'});

# Generate a random ID and tracking file for this password reset
my $baseurl = &get_webmin_email_url();
my ($basehost) = &parse_http_url($baseurl);
my %link = ( 'id' => &acl::generate_random_id(),
	     'remote' => $ENV{'REMOTE_ADDR'},
	     'host' => $basehost,
	     'time' => $now,
	     'user' => $wuser->{'name'},
	     'uuser' => $uuser ? $uuser->{'user'} : undef,
	     'muser' => $muser ? $muser->{'user'} : undef, );
$link{'id'} || &error($text{'forgot_erandom'});
my $linkfile = $main::forgot_password_link_dir."/".$link{'id'};
&lock_file($linkfile);
&write_file($linkfile, \%link);
&unlock_file($linkfile);
my $url = $baseurl.'/forgot.cgi?id='.&urlize($link{'id'});
my $username = $muser ? $muser->{'user'} :
	       $uuser ? $uuser->{'user'} : $wuser->{'name'};
$url = &theme_forgot_url($baseurl, $link{'id'}, $username)
	if (defined(&theme_forgot_url));

&ui_print_header(undef, $text{'forgot_title'}, "", undef, undef, 1, 1);

# Send email with a link to generate the reset form
&foreign_require("mailboxes");
my $msg = &text('forgot_msg', $username, $url, $ENV{'REMOTE_HOST'},
			      $baseurl);
$msg =~ s/\\n/\n/g;
$msg = join("\n", &mailboxes::wrap_lines($msg, 75))."\n";
my $subject = &text('forgot_subject', $username);
&mailboxes::send_text_mail(&mailboxes::get_from_address(),
			   $email,
			   undef,
			   $subject,
			   $msg);

# Tell the user
print "<center>\n";
print &text('forgot_sent',
	    "<tt>".&html_escape(&acl::obsfucate_email($email))."</tt>",
	    "<tt>".&html_escape($username)."</tt>"),"\n";
print "</center>\n";

&webmin_log("forgot", "send", undef,
	    { 'user' => $username,
	      'unix' => $muser || $uuser ? 1 : 0,
	      'email' => $email }, "acl");
&ui_print_footer();
