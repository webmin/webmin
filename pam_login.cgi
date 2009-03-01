#!/usr/local/bin/perl
# Ask one PAM question

BEGIN { push(@INC, ".."); };
use WebminCore;

$pragma_no_cache = 1;
#$ENV{'MINISERV_INTERNAL'} || die "Can only be called by miniserv.pl";
&init_config();
&ReadParse();
if ($gconfig{'loginbanner'} && $ENV{'HTTP_COOKIE'} !~ /banner=1/ &&
    $in{'initial'}) {
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
&get_miniserv_config(\%miniserv);
print "Set-Cookie: banner=0; path=/$sec\r\n" if ($gconfig{'loginbanner'});
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
print "<form action=$gconfig{'webprefix'}/pam_login.cgi method=post>\n";
print "<input type=hidden name=cid value='",&quote_escape($in{'cid'}),"'>\n";

print "<table border width=40%>\n";
print "<tr $tb> <td><b>$text{'pam_header'}</b></td> </tr>\n";
print "<tr $cb> <td align=center><table cellpadding=3>\n";
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
	print "<tr> <td colspan=2 align=center>",
	      &html_escape($in{'message'}),"</td> </tr>\n";
	print "<input type=hidden name=message value=1>\n";
	}
else {
	# Asking a question
	print "<tr> <td colspan=2 align=center>",
	      &text($gconfig{'nohostname'} ? 'pam_mesg2' : 'pam_mesg',
		    "<tt>$host</tt>"),"</td> </tr>\n";

	$pass = "type=password" if ($in{'password'});
	print "<tr> <td><b>",&html_escape($in{'question'}),"</b></td>\n";
	print "<td><input name=answer $pass size=20></td> </tr>\n";
	}

print "<tr> <td colspan=2 align=center>\n";
print "<input type=submit value='$text{'pam_login'}'>\n";
print "<input type=reset value='$text{'session_clear'}'>\n";
if (!$in{'initial'}) {
	print "<input type=submit name=restart value='$text{'pam_restart'}'>\n";
	}
print "<br>\n";

print "</td> </tr>\n";
print "</table></td></tr></table><p>\n";
print "</form></center>\n";
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

