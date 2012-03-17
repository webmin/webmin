#!/usr/local/bin/perl
# conf_bind.cgi
# Display winbind-related options

require './samba-lib.pl';

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcm'}") unless $access{'conf_bind'};

&ui_print_header(undef, $text{'bind_title'}, "");

&get_share("global");
print "<form action=save_bind.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'bind_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'bind_local'}</b></td>\n";
print "<td>",&ui_radio("local",
		&istrue("winbind enable local accounts") ? 1 : 0,
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<td><b>$text{'bind_trust'}</b></td>\n";
print "<td>",&ui_radio("trust",
		&istrue("winbind trusted domains only") ? 1 : 0,
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<tr> <td><b>$text{'bind_users'}</b></td>\n";
print "<td>",&ui_radio("users",
		&istrue("winbind enum users") ? 1 : 0,
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<td><b>$text{'bind_groups'}</b></td>\n";
print "<td>",&ui_radio("groups",
		&istrue("winbind enum groups") ? 1 : 0,
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<tr> <td><b>$text{'bind_defaultdomain'}</b></td>\n";
print "<td>",&ui_radio("defaultdomain",
		&istrue("winbind use default domain") ? 1 : 0,
		[ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<tr> <td><b>$text{'bind_realm'}</b></td>\n";
printf "<td><input name=realm size=20 value='%s'></td>\n",
	&getval("realm");

print "<td><b>$text{'bind_cache'}</b></td>\n";
printf "<td><input name=cache size=5 value='%s'></td> </tr>\n",
	&getval("winbind cache time");

print "<tr> <td><b>$text{'bind_uid'}</b></td>\n";
printf "<td><input name=uid size=20 value='%s'></td>\n",
	&getval("idmap uid");

print "<td><b>$text{'bind_gid'}</b></td>\n";
printf "<td><input name=gid size=20 value='%s'></td> </tr>\n",
	&getval("idmap gid");

$backend = &getval("idmap backend");
print "<tr> <td><b>$text{'bind_backend'}</b></td>\n";
print "<td colspan=3>",
	&ui_radio("backend_def", $backend ? 0 : 1,
		  [ [ 1, $text{'default'} ],
		    [ 0, &ui_textbox("backend", $backend, 50) ] ]),
	"</td> </tr>\n";

print "</table></tr></td></table><p>\n";
print "<input type=submit value=$text{'save'}></form>\n";

&ui_print_footer("", $text{'index_sharelist'});


