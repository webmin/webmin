#!/usr/local/bin/perl
# Ask one PAM question

BEGIN { push(@INC, "."); };
use WebminCore;

$pragma_no_cache = 1;
#$ENV{'MINISERV_INTERNAL'} || die "Can only be called by miniserv.pl";
&init_config();
&ReadParse(undef, undef, undef, 2);

# Redirect to the forgot page that this theme supports if generate in SPA theme
if ($gconfig{'forgot_pass'} && $ENV{'REQUEST_URI'}) {
	my ($forgot_id) = $ENV{'REQUEST_URI'} =~ /[?&]forgot=([0-9a-fA-F]{32})/;
	if ($forgot_id) {
		&redirect("@{[&get_webprefix()]}/forgot.cgi?id=$forgot_id");
		return;
		}
	}

# Redirect to forgot form if return param is set from SPA theme
if ($gconfig{'forgot_pass'} && $ENV{'REQUEST_URI'} &&
    $ENV{'REQUEST_URI'} =~ /[?&]return=(http?\S+)/) {
	&redirect("@{[&get_webprefix()]}/forgot_form.cgi");
	return;
	}

# Login banner
if ($gconfig{'loginbanner'} && $ENV{'HTTP_COOKIE'} !~ /banner=1/ &&
    !$in{'logout'} && $in{'initial'}) {
	# Show pre-login HTML page
	print "Set-Cookie: banner=1; path=/\r\n";
	&PrintHeader();
	$url = $in{'page'};
	$url = &filter_javascript($url);
	open(BANNER, "<$gconfig{'loginbanner'}");
	while(<BANNER>) {
		s/LOGINURL/$url/g;
		print;
		}
	close(BANNER);
	return;
	}
&get_miniserv_config(\%miniserv);
$sec = uc($ENV{'HTTPS'}) eq 'ON' ? "; secure" : "";
if (!$miniserv{'no_httponly'}) {
	$sec .= "; httpOnly";
}
$sidname = $miniserv{'sidname'} || "sid";
print "Set-Cookie: banner=0; path=/$sec\r\n" if ($gconfig{'loginbanner'});
print "Set-Cookie: $sidname=x; path=/$sec\r\n" if ($in{'logout'});
print "Set-Cookie: testing=1; path=/$sec\r\n";
&ui_print_unbuffered_header(undef, undef, undef, undef, undef, 1, 1, undef,
			    undef, "onLoad='document.forms[0].answer.focus()'");

print "<center>\n";
if (&miniserv_using_default_cert()) {
    print "<h3>",&text('defcert_error',
    	ucfirst(&get_product_name()), ($ENV{'MINISERV_KEYFILE'} || $miniserv{'keyfile'})),"</h3><p></p>\n";
	}
if (defined($in{'failed'})) {
	print "<h3>$text{'session_failed'}</h3><p>\n";
	}
elsif ($in{'logout'}) {
	print "<h3>$text{'session_logout'}</h3><p>\n";
	}
elsif ($in{'timed_out'}) {
	print "<h3>",&text('session_timed_out', int($in{'timed_out'}/60)),"</h3><p>\n";
	}

print "$text{'pam_prefix'}\n";

print &ui_form_start("@{[&get_webprefix()]}/pam_login.cgi", "post");
print &ui_hidden("cid", $in{'cid'});

my $not_secure;
if ($ENV{'HTTPS'} ne 'ON' && $miniserv{'ssl'}) {
	my $link = ui_tag('a', "&#9888; $text{'login_notsecure'}",
		{ 'href' => "javascript:void(0);",
		  'class' => 'inherit-color',
		  'onclick' => "window.location.href = ".
		    "window.location.href.replace(/^http:/, 'https:'); return false;",
		});
	$not_secure = ui_tag('span', $link,
		{ class => 'not-secure', title => $text{'login_notsecure_desc'} });
	}

print &ui_table_start($text{'pam_header'} . $not_secure,
		      "width=40% class='loginform'", 2);

if ($gconfig{'realname'}) {
	$host = &get_system_hostname();
	}
else {
	$host = $ENV{'HTTP_HOST'};
	$host =~ s/:\d+//g;
	$host = &html_escape($host);
	}

if ($in{'message'}) {
	# Showing a message
	print &ui_table_row(undef,
	      &html_escape($in{'message'}), 2);
	print &ui_hidden("message", 1);
	}
else {
	# Asking a question
	print &ui_table_row(undef,
	      &text($gconfig{'nohostname'} ? 'pam_mesg2' : 'pam_mesg',
		    "<tt>$host</tt>"), 2, [ "align=center", "align=center" ]);

	print &ui_table_row(&html_escape($in{'question'}),
		$in{'password'} ? &ui_password("answer", undef, 20)
				: &ui_textbox("answer", undef, 20));
	}

print &ui_table_end(),"\n";
print &ui_submit($text{'pam_login'});
print &ui_reset($text{'session_clear'});
if (!$in{'initial'}) {
	print &ui_submit($text{'pam_restart'}, 'restart');
	}
print &ui_form_end();

if ($gconfig{'forgot_pass'}) {
	# Show forgotten password link
	my $link = &get_webmin_base_url();
	my $param = '';
	if ($link) {
		my $src_link = ($ENV{'HTTPS'} eq 'ON'
			? 'https'
			: 'http').'://'.$ENV{'HTTP_HOST'};
		$src_link .= ($gconfig{'webprefix'} || '')."/";
		$param = "?return=".&urlize($src_link);
		}
	print &ui_form_start($link."forgot_form.cgi".$param, "post");
	print &ui_hidden("failed", $in{'failed'});
	print &ui_form_end([ [ undef, $text{'session_forgot'} ] ]);
	}

print "</center>\n";
print "$text{'pam_postfix'}\n";

# Output frame-detection Javascript, if theme uses frames
if ($tconfig{'inframe'}) {
	print <<EOF;
<script>
if (window != window.top) {
	window.top.location = window.location;
	}
</script>
EOF
	}

&ui_print_footer();

