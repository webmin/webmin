#!/usr/local/bin/perl
# edit_session.cgi
# Edit session login options

require './usermin-lib.pl';
$access{'session'} || &error($text{'acl_ecannot'});
print "Set-Cookie: sessiontest=1; path=/\n";
&ui_print_header(undef, $text{'session_title'}, "");
&get_usermin_miniserv_config(\%miniserv);
$ver = &get_usermin_version();

&get_usermin_config(\%uconfig);
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

# Block hosts
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=blockhost_on value=1 %s>\n",
	$miniserv{'blockhost_failures'} ? "checked" : "";
print &text('session_blockhost',
    &ui_textbox("blockhost_failures", $miniserv{'blockhost_failures'}, 4),
    &ui_textbox("blockhost_time", $miniserv{'blockhost_time'}, 4)),"<br>\n";

# Block users
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
print &text('session_logouttime',
	"<input name=logouttime value='$miniserv{'logouttime'}' size=10>"),"<br>\n";
#printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=locking value=1 %s>\n",
#	$gconfig{'locking'} ? "checked" : "";
#print "$text{'session_locking'}<br>\n";
printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=remember value=1 %s>\n",
	$uconfig{'noremember'} ? "" : "checked";
print "$text{'session_remember'}<br>\n";
print "&nbsp;&nbsp;&nbsp;";
printf "<input type=checkbox name=realname value=1 %s>\n",
	$uconfig{'realname'} ? "checked" : "";
print "$text{'session_realname'}<br>\n";
if ($ver >= 1.153) {
	printf "&nbsp;&nbsp;&nbsp;<input type=checkbox name=utmp value=1 %s>\n",
		$miniserv{'utmp'} ? "checked" : "";
	print "$text{'session_utmp'}<br>\n";
	}
printf "&nbsp;&nbsp;&nbsp;<input type=radio name=banner_def value=1 %s> %s\n",
	$uconfig{'loginbanner'} ? "" : "checked", $text{'session_banner1'};
printf "<input type=radio name=banner_def value=0 %s> %s\n",
	$uconfig{'loginbanner'} ? "checked" : "", $text{'session_banner0'};
printf "<input name=banner size=30 value='%s'> %s<br>\n",
	$uconfig{'loginbanner'}, &file_chooser_button("banner");
print "<p>\n";

printf "<input type=radio name=localauth value=0 %s> %s<br>\n",
	!$miniserv{'localauth'} ? "checked" : "", $text{'session_localoff'};
printf "<input type=radio name=localauth value=1 %s> %s<br>\n",
	$miniserv{'localauth'} ? "checked" : "", $text{'session_localon'};
print "<p>\n";

# Authentication mode
@users = &get_usermin_miniserv_users();
$authmode = $users[0]->{'pass'} eq 'e' ? 2 :
	    $miniserv{'no_pam'} ? 1 : 0;
printf "<input type=radio name=authmode value=0 %s> %s<br>\n",
	$authmode == 0 ? "checked" : "", $text{'session_authmode0'};
print "&nbsp;&nbsp;&nbsp;",
	&ui_checkbox("pam_conv", 1, $text{'session_pamconv'},
		     $miniserv{'pam_conv'}),"<br>\n";
print "&nbsp;&nbsp;&nbsp;",
	&ui_checkbox("pam_end", 1, $text{'session_pamend'},
		     $miniserv{'pam_end'}),"<br>\n";
printf "<input type=radio name=authmode value=1 %s>\n",
	$authmode == 1 ? "checked" : "";
print &text('session_authmode1',
      "<input name=passwd_file size=20 value='$miniserv{'passwd_file'}'>",
      "<input name=passwd_uindex size=2 value='$miniserv{'passwd_uindex'}'>",
      "<input name=passwd_pindex size=2 value='$miniserv{'passwd_pindex'}'>"),
      "<br>\n";
printf "<input type=radio name=authmode value=2 %s> %s\n",
	$authmode == 2 ? "checked" : "", $text{'session_authmode2'};
printf "<input name=extauth size=30 value='%s'><p>\n",
	$miniserv{'extauth'};

# Unix password change
print &ui_oneradio("cmd_def", 1, $text{'session_cmddef1'},
		   !$gconfig{'passwd_cmd'}),"<br>\n";
print &ui_oneradio("cmd_def", 0, $text{'session_cmddef0'},
		   $gconfig{'passwd_cmd'})," ",
      &ui_textbox("cmd", $gconfig{'passwd_cmd'}, 40),"<p>\n";

if ($ver >= 1.047 && $miniserv{'passwd_cindex'} ne '') {
	#print "$text{'session_pmodedesc'}<br>\n";
	foreach $m (0 .. 2) {
		printf "<input type=radio name=passwd_mode value=%d %s> %s\n",
			$m, $miniserv{'passwd_mode'} == $m ? "checked" : "",
			$text{'session_pmode'.$m};
		print $m == 2 ? "<p>\n" : "<br>\n";
		}
	}

# Prompt to choose password at login
if ($ver >= 1.087) {
	printf "<input type=checkbox name=passwd_blank value=1 %s> %s<br>\n",
		$miniserv{'passwd_blank'} ? "checked" : "",
		$text{'session_blank'};
	}

if ($ver >= 1.003) {
	printf "<input type=checkbox name=domainuser value=1 %s> %s<br>\n",
		$miniserv{'domainuser'} ? "checked" : "",
		$text{'session_domain'};
	}
if ($ver >= 1.021) {
	printf "<input type=checkbox name=domainstrip value=1 %s> %s<br>\n",
		$miniserv{'domainstrip'} ? "checked" : "",
		$text{'session_strip'};
	printf "<input type=checkbox name=user_mapping_on value=1 %s> %s\n",
		$miniserv{'user_mapping'} ? "checked" : "",
		$text{'session_usermap'};
	printf "<input name=user_mapping size=30 value='%s'> %s<br>\n",
		$miniserv{'user_mapping'}, &file_chooser_button("user_mapping");
	print "&nbsp;" x 3;
	printf "$text{'session_userfmt'}\n";
	print &ui_radio("user_mapping_reverse",
			int($miniserv{'user_mapping_reverse'}),
			[ [ 0, $text{'session_userfmt0'} ],
			  [ 1, $text{'session_userfmt1'} ] ]),"<p>\n";
	}

# Prompt to choose password at login
if ($ver >= 1.142) {
	printf "<input type=checkbox name=create_homedir value=1 %s> %s<br>\n",
		$uconfig{'create_homedir'} ? "checked" : "",
		$text{'session_homedir'};
	print "&nbsp;" x 3;
	print $text{'session_homedir_perms'},"\n",
	      &ui_opt_textbox("create_homedir_perms",
		$uconfig{'create_homedir_perms'}, 4, $text{'default'}),"<br>\n";
	}

print "</td> </tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

