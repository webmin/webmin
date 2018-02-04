#!/usr/local/bin/perl
# edit_session.cgi
# Edit session login options

require './webmin-lib.pl';
print "Set-Cookie: sessiontest=1; path=/\n";
ui_print_header(undef, $text{'session_title'}, "");
get_miniserv_config(\%miniserv);

print "$text{'session_desc1'}<p>\n";

print ui_form_start("change_session.cgi", "post");
print ui_table_start($text{'session_header'}, undef, 2);

# Bad password delay
print &ui_table_row($text{'session_ptimeout'},
	&ui_radio("passdelay", $miniserv{'passdelay'} ? 1 : 0,
		  [ [ 0, $text{'session_pdisable'}."<br>\n" ],
		    [ 1, $text{'session_penable'} ] ]));

# Block bad hosts
print &ui_table_row($text{'session_pblock'},
    &ui_checkbox("blockhost_on", 1, 
	text('session_blockhost',
	  ui_textbox("blockhost_failures", $miniserv{'blockhost_failures'}, 4),
	  ui_textbox("blockhost_time", $miniserv{'blockhost_time'}, 4)),
	$miniserv{'blockhost_failures'} ? 1 : 0));

# Block bad users
print &ui_table_row("",
    &ui_checkbox("blockuser_on", 1, 
	text('session_blockuser',
	  ui_textbox("blockuser_failures", $miniserv{'blockuser_failures'}, 4),
	  ui_textbox("blockuser_time", $miniserv{'blockuser_time'}, 4)),
	$miniserv{'blockuser_failures'} ? 1 : 0));

# Lock Webmin users who failed login too many times
print &ui_table_row("",
    ui_checkbox("blocklock", 1, $text{'session_blocklock'},
		$miniserv{'blocklock'}));

# Log to syslog
eval "use Sys::Syslog qw(:DEFAULT setlogsock)";
if (!$@) {
	print &ui_table_row($text{'session_syslog3'},
		&ui_yesno_radio("syslog", $miniserv{'syslog'}));
	}
else {
	print ui_hidden('syslog', $miniserv{'syslog'});
	}

# Session authentication
print &ui_table_row($text{'session_stype'},
	&ui_radio("session", $miniserv{'session'} ? 1 : 0,
		  [ [ 0, $text{'session_disable'}."<br>" ],
		    [ 1, $text{'session_enable'} ] ]));

# Session auth options
print &ui_table_row($text{'session_sopts'},
	&ui_checkbox("logouttime_on", 1, 
		&text('session_logouttime',
			&ui_textbox("logouttime", $miniserv{'logouttime'}, 10)),
		 $miniserv{'logouttime'} ? 1 : 0).
	"<br>\n".
	&ui_checkbox("remember", 1, $text{'session_remember'},
		     $gconfig{'noremember'} ? 0 : 1).
	"<br>\n".
	&ui_checkbox("realname", 1, $text{'session_realname'},
		     $gconfig{'realname'} ? 1 : 0).
	"<br>\n".
	&ui_checkbox("session_ip", 1, $text{'session_ip'},
		     $miniserv{'session_ip'} ? 1 : 0).
	"<br>\n".
	&ui_checkbox("utmp", 1, $text{'session_utmp'},
		     $miniserv{'utmp'} ? 1 : 0));

# Pre-login banner
print &ui_table_row($text{'session_banner'},
	&ui_radio("banner_def", $gconfig{'loginbanner'} ? 0 : 1,
		  [ [ 1, $text{'session_banner1'}."<br>" ],
		    [ 0, $text{'session_banner0'} ] ]).
	&ui_filebox("banner", $gconfig{'loginbanner'}, 50));

# Local authentication
print &ui_table_row($text{'session_local'},
	&ui_radio("localauth", $miniserv{'localauth'} ? 1 : 0,
		  [ [ 0, $text{'session_localoff'}."<br>" ],
		    [ 1, $text{'session_localon'} ] ]));

# Use PAM or shadow file?
print &ui_table_row($text{'session_pam'},
	&ui_radio("no_pam", $miniserv{'no_pam'} ? 1 : 0,
		  [ [ 0, $text{'session_pamon'}."<br>" ],
		    [ 1, $text{'session_pamoff'} ] ]));

print &ui_table_row($text{'session_popts'},
	ui_checkbox("pam_conv", 1, $text{'session_pamconv'},
		     $miniserv{'pam_conv'}).
	"<br>".
	ui_checkbox("pam_end", 1, $text{'session_pamend'},
		     $miniserv{'pam_end'}).
	"<br>\n".
	&text('session_pfile',
	      &ui_textbox("passwd_file", $miniserv{'passwd_file'}, 20),
	      &ui_textbox("passwd_uindex", $miniserv{'passwd_uindex'}, 2),
	      &ui_textbox("passwd_pindex", $miniserv{'passwd_pindex'}, 2)));

# Unix password change
print &ui_table_row($text{'session_cmddef'},
	&ui_oneradio("cmd_def", 1, $text{'session_cmddef1'},
		     !$gconfig{'passwd_cmd'}).
	"<br>".
	&ui_oneradio("cmd_def", 0, $text{'session_cmddef0'},
		     $gconfig{'passwd_cmd'}).
	" ".
	&ui_textbox("cmd", $gconfig{'passwd_cmd'}, 60));

# Password expiry policy
print &ui_table_row($text{'session_pmodedesc3'},
	&ui_radio("passwd_mode", $miniserv{'passwd_mode'} || 0,
		  [ [ 0, $text{'session_pmode0'}."<br>" ],
		    [ 1, $text{'session_pmode1'}."<br>" ],
		    [ 2, $text{'session_pmode2'} ] ]));

# Squid-style authentication program
print &ui_table_row($text{'session_extauth'},
	&ui_textbox("extauth", $miniserv{'extauth'}, 60));

# Password encryption format
print &ui_table_row($text{'session_md5'},
	&ui_radio("md5pass", $gconfig{'md5pass'} || 0,
		  [ [ 0, $text{'session_md5off'}."<br>" ],
		    [ 1, $text{'session_md5on'} ],
		    [ 2, $text{'session_sha512'} ] ]));

print ui_table_end();
print ui_form_end([ [ "save", $text{'save'} ] ]);

ui_print_footer("", $text{'index_return'});

