#!/usr/local/bin/perl
# session_login.cgi
# Display the login form used in session login mode

$pragma_no_cache = 1;
#$ENV{'MINISERV_INTERNAL'} || die "Can only be called by miniserv.pl";
require './web-lib.pl';
require './ui-lib.pl';
&init_config();
&ReadParse();
if ($gconfig{'loginbanner'} && $ENV{'HTTP_COOKIE'} !~ /banner=1/ &&
    !$in{'logout'} && !$in{'failed'} && !$in{'timed_out'}) {
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
$sidname = $miniserv{'sidname'} || "sid";
print "Set-Cookie: banner=0; path=/$sec\r\n" if ($gconfig{'loginbanner'});
print "Set-Cookie: $sidname=x; path=/$sec\r\n" if ($in{'logout'});
print "Set-Cookie: testing=1; path=/$sec\r\n";
&ui_print_unbuffered_header(undef, undef, undef, undef, undef, 1, 1, undef, undef,
	"onLoad='document.forms[0].pass.value = \"\"; document.forms[0].user.focus()'");

if ($tconfig{'inframe'}) {
	# Framed themes lose original page
	$in{'page'} = "/";
	}

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
print "$text{'session_prefix'}\n";
print "<form action=$gconfig{'webprefix'}/session_login.cgi method=post>\n";
print "<input type=hidden name=page value='".&html_escape($in{'page'})."'>\n";
print "<table border width=40%>\n";
print "<tr $tb> <td><b>$text{'session_header'}</b></td> </tr>\n";
print "<tr $cb> <td align=center><table cellpadding=3>\n";
if ($gconfig{'realname'}) {
	$host = &get_display_hostname();
	}
else {
	$host = $ENV{'HTTP_HOST'};
	$host =~ s/:\d+//g;
	$host = &html_escape($host);
	}
print "<tr> <td colspan=2 align=center>",
      &text($gconfig{'nohostname'} ? 'session_mesg2' : 'session_mesg',
	    "<tt>$host</tt>"),"</td> </tr>\n";
print "<tr> <td><b>$text{'session_user'}</b></td>\n";
print "<td><input name=user size=20 value='".&html_escape($in{'failed'})."'></td> </tr>\n";
print "<tr> <td><b>$text{'session_pass'}</b></td>\n";
print "<td><input name=pass size=20 type=password></td> </tr>\n";
print "<tr> <td colspan=2 align=center><input type=submit value='$text{'session_login'}'>\n";
print "<input type=reset value='$text{'session_clear'}'><br>\n";
if (!$gconfig{'noremember'}) {
	print "<input type=checkbox name=save value=1> $text{'session_save'}\n";
	}
print "</td> </tr>\n";
print "</table></td></tr></table><p>\n";
print "</form></center>\n";
print "$text{'session_postfix'}\n";

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

