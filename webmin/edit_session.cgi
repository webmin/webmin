#!/usr/local/bin/perl
# edit_session.cgi
# Edit session login options

require './webmin-lib.pl';
print "Set-Cookie: sessiontest=1; path=/\n";
ui_print_header(undef, $text{'session_title'}, "");
get_miniserv_config(\%miniserv);

print "$text{'session_desc1'}<p>\n";
print "$text{'session_desc2'}<p>\n";

print ui_form_start("change_session.cgi", "post");
print ui_table_start($text{'session_header'});
print "<tr $cb> <td nowrap>\n";

# Bad password delay
printf "<input type=radio name=passdelay value=0 %s> %s<br>\n",
	$miniserv{'passdelay'} ? '' : 'checked', $text{'session_pdisable'};
printf "<input type=radio name=passdelay value=1 %s> %s<br>\n",
	$miniserv{'passdelay'} ? 'checked' : '', $text{'session_penable'};

# Block bad hosts
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=blockhost_on value=1 %s>\n",
	$miniserv{'blockhost_failures'} ? "checked" : "";
print text('session_blockhost',
    ui_textbox("blockhost_failures", $miniserv{'blockhost_failures'}, 4),
    ui_textbox("blockhost_time", $miniserv{'blockhost_time'}, 4)),"<br>\n";

# Block bad users
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=blockuser_on value=1 %s>\n",
	$miniserv{'blockuser_failures'} ? "checked" : "";
print text('session_blockuser',
    ui_textbox("blockuser_failures", $miniserv{'blockuser_failures'}, 4),
    ui_textbox("blockuser_time", $miniserv{'blockuser_time'}, 4)),"<br>\n";

# Lock bad users
print "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\n",
      ui_checkbox("blocklock", 1, $text{'session_blocklock'},
		   $miniserv{'blocklock'}),"<br>\n";

# Log to syslog
eval "use Sys::Syslog qw(:DEFAULT setlogsock)";
if (!$@) {
	print ui_checkbox('syslog', 1, $text{'session_syslog2'},
	  $miniserv{'syslog'});
	}
else {
	print ui_hidden('syslog', $miniserv{'syslog'});
	}
print "<p>\n";

printf "<input type=radio name=session value=0 %s> %s<br>\n",
	!$miniserv{'session'} ? "checked" : "", $text{'session_disable'};
printf "<input type=radio name=session value=1 %s> %s<br>\n",
	$miniserv{'session'} ? "checked" : "", $text{'session_enable'};
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=logouttime_on value=1 %s>\n",
	$miniserv{'logouttime'} ? "checked" : "";
print text('session_logouttime',
	"<input name=logouttime value='$miniserv{'logouttime'}' size=10>"),"<br>\n";
#printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=locking value=1 %s>\n",
#	$gconfig{'locking'} ? "checked" : "";
#print "$text{'session_locking'}<br>\n";
print '&nbsp;&nbsp;&nbsp;', ui_checkbox('remember', 1, $text{'session_remember'},
       !$gconfig{'noremember'}), "<br>\n";
print '&nbsp;&nbsp;&nbsp;', ui_checkbox('realname', 1,
       $text{'session_realname'}, $gconfig{'realname'}), "<br>\n";
print '&nbsp;&nbsp;&nbsp;', ui_checkbox('utmp', 1, $text{'session_utmp'},
       $miniserv{'utmp'}), "<br>\n";
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

# Use PAM or shadow file?
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
	ui_checkbox("pam_conv", 1, $text{'session_pamconv'},
		     $miniserv{'pam_conv'}),"<br>\n";
print "&nbsp;&nbsp;&nbsp;",
	ui_checkbox("pam_end", 1, $text{'session_pamend'},
		     $miniserv{'pam_end'}),"<p>\n";

# Unix password change
print &ui_oneradio("cmd_def", 1, $text{'session_cmddef1'},
		   !$gconfig{'passwd_cmd'}),"<br>\n";
print &ui_oneradio("cmd_def", 0, $text{'session_cmddef0'},
		   $gconfig{'passwd_cmd'})," ",
      &ui_textbox("cmd", $gconfig{'passwd_cmd'}, 40),"<p>\n";

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

print ui_table_end();
print ui_form_end([ [ "save", $text{'save'} ] ]);

ui_print_footer("", $text{'index_return'});

