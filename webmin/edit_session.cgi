#!/usr/local/bin/perl
# edit_session.cgi
# Edit session login options

require './webmin-lib.pl';
print "Set-Cookie: sessiontest=1; path=/\n";
&ui_print_header(undef, $text{'session_title'}, "");
&get_miniserv_config(\%miniserv);

print "$text{'session_desc1'}<p>\n";
print "$text{'session_desc2'}<p>\n";

print "<form action=change_session.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'session_header'}</b></td> </tr>\n";
print "<tr $cb> <td nowrap>\n";

# Bad password delay
printf "<input type=radio name=passdelay value=0 %s> %s<br>\n",
	$miniserv{'passdelay'} ? '' : 'checked', $text{'session_pdisable'};
printf "<input type=radio name=passdelay value=1 %s> %s<br>\n",
	$miniserv{'passdelay'} ? 'checked' : '', $text{'session_penable'};

# Block bad hosts
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=blockhost_on value=1 %s>\n",
	$miniserv{'blockhost_failures'} ? "checked" : "";
print &text('session_blockhost',
    &ui_textbox("blockhost_failures", $miniserv{'blockhost_failures'}, 4),
    &ui_textbox("blockhost_time", $miniserv{'blockhost_time'}, 4)),"<br>\n";

# Block bad users
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=blockuser_on value=1 %s>\n",
	$miniserv{'blockuser_failures'} ? "checked" : "";
print &text('session_blockuser',
    &ui_textbox("blockuser_failures", $miniserv{'blockuser_failures'}, 4),
    &ui_textbox("blockuser_time", $miniserv{'blockuser_time'}, 4)),"<br>\n";

# Log to syslog
eval "use Sys::Syslog qw(:DEFAULT setlogsock)";
if (!$@) {
	printf "<input type=checkbox name=syslog value=1 %s> %s\n",
		$miniserv{'syslog'} ? "checked" : "", $text{'session_syslog2'};
	}
else {
	print "<input type=hidden name=syslog value='$miniserv{'syslog'}'>\n";
	}
print "<p>\n";

printf "<input type=radio name=session value=0 %s> %s<br>\n",
	!$miniserv{'session'} ? "checked" : "", $text{'session_disable'};
printf "<input type=radio name=session value=1 %s> %s<br>\n",
	$miniserv{'session'} ? "checked" : "", $text{'session_enable'};
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=logouttime_on value=1 %s>\n",
	$miniserv{'logouttime'} ? "checked" : "";
print &text('session_logout',
	"<input name=logouttime value='$miniserv{'logouttime'}' size=10>"),"<br>\n";
#printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=locking value=1 %s>\n",
#	$gconfig{'locking'} ? "checked" : "";
#print "$text{'session_locking'}<br>\n";
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=remember value=1 %s>\n",
	$gconfig{'noremember'} ? "" : "checked";
print "$text{'session_remember'}<br>\n";
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=hostname value=1 %s>\n",
	$gconfig{'nohostname'} ? "" : "checked";
print "$text{'session_hostname'}<br>\n";
print "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
printf "<input type=checkbox name=realname value=1 %s>\n",
	$gconfig{'realname'} ? "checked" : "";
print "$text{'session_realname'}<br>\n";
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=utmp value=1 %s>\n",
	$miniserv{'utmp'} ? "checked" : "";
print "$text{'session_utmp'}<br>\n";
printf "&nbsp;&nbsp;&nbsp;<input type=radio name=banner_def value=1 %s> %s\n",
	$gconfig{'loginbanner'} ? "" : "checked", $text{'session_banner1'};
printf "<input type=radio name=banner_def value=0 %s> %s\n",
	$gconfig{'loginbanner'} ? "checked" : "", $text{'session_banner0'};
printf "<input name=banner size=30 value='%s'> %s<br>\n",
	$gconfig{'loginbanner'}, &file_chooser_button("banner");
print "<p>\n";

printf "<input type=radio name=localauth value=0 %s> %s<br>\n",
	!$miniserv{'localauth'} ? "checked" : "", $text{'session_localoff'};
printf "<input type=radio name=localauth value=1 %s> %s<br>\n",
	$miniserv{'localauth'} ? "checked" : "", $text{'session_localon'};
print "<p>\n";

printf "<input type=radio name=no_pam value=0 %s> %s<br>\n",
	!$miniserv{'no_pam'} ? "checked" : "", $text{'session_pamon'};
printf "<input type=radio name=no_pam value=1 %s> %s<br>\n",
	$miniserv{'no_pam'} ? "checked" : "", $text{'session_pamoff'};
print "&nbsp;&nbsp;&nbsp;",&text('session_pfile',
	"<input name=passwd_file size=20 value='$miniserv{'passwd_file'}'>",
	"<input name=passwd_uindex size=2 value='$miniserv{'passwd_uindex'}'>",
	"<input name=passwd_pindex size=2 value='$miniserv{'passwd_pindex'}'>"),
	"<br>\n";
print "&nbsp;&nbsp;&nbsp;",
	&ui_checkbox("pam_conv", 1, $text{'session_pamconv'},
		     $miniserv{'pam_conv'}),"<p>\n";

print "$text{'session_pmodedesc3'}<br>\n";
foreach $m (0 .. 2) {
	printf "<input type=radio name=passwd_mode value=%d %s> %s\n",
		$m, $miniserv{'passwd_mode'} == $m ? "checked" : "",
		$text{'session_pmode'.$m};
	print $m == 2 ? "<p>\n" : "<br>\n";
	}

# Squid-style authentication program
print "$text{'session_extauth'} ",
      "<input name=extauth size=40 value='$miniserv{'extauth'}'><p>\n";

# Password encryption format
printf "<input type=radio name=md5pass value=0 %s> %s<br>\n",
	!$gconfig{'md5pass'} ? "checked" : "", $text{'session_md5off'};
printf "<input type=radio name=md5pass value=1 %s> %s<br>\n",
	$gconfig{'md5pass'} ? "checked" : "", $text{'session_md5on'};

print "</td> </tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

