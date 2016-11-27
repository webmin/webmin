#!/usr/local/bin/perl
# Ask one PAM question

BEGIN { push(@INC, ".."); };
use WebminCore;

$pragma_no_cache = 1;
#$ENV{'MINISERV_INTERNAL'} || die "Can only be called by miniserv.pl";
&init_config();
&ReadParse();
if ($gconfig{'loginbanner'} && $ENV{'HTTP_COOKIE'} !~ /banner=1/ &&
    !$in{'logout'} && $in{'initial'}) {
	# Show pre-login HTML page
	print "Set-Cookie: banner=1; path=/\r\n";
	&PrintHeader();
	$url = $in{'page'};
	open(BANNER, $gconfig{'loginbanner'});
	while(<BANNER>) {
		s/LOGINURL/$url/g;
		print;
		}
	close(BANNER);
	return;
	}
$sec = uc($ENV{'HTTPS'}) eq 'ON' ? "; secure" : "";
if (!$config{'no_httponly'}) {
	$sec .= "; httpOnly";
}
&get_miniserv_config(\%miniserv);
$sidname = $miniserv{'sidname'} || "sid";
print "Set-Cookie: banner=0; path=/$sec\r\n" if ($gconfig{'loginbanner'});
print "Set-Cookie: $sidname=x; path=/$sec\r\n" if ($in{'logout'});
print "Set-Cookie: testing=1; path=/$sec\r\n";
&ui_print_unbuffered_header(undef, undef, undef, undef, undef, 1, 1, undef,
			    undef, "onLoad='document.forms[0].answer.focus()'");

print "<center>\n";
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

print &ui_form_start("$gconfig{'webprefix'}/pam_login.cgi", "post");
print &ui_hidden("cid", $in{'cid'});

print &ui_table_start($text{'pam_header'},
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

