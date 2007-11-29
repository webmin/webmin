#!/usr/local/bin/perl
# edit_dir.cgi
# Display information about a protected directory

require './htaccess-lib.pl';
&foreign_require($apachemod, "apache-lib.pl");
&ReadParse();
$can_create || &error($text{'dir_ecannotcreate'});
if ($in{'new'}) {
	&ui_print_header(undef, $text{'dir_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'dir_title2'}, "");
	@dirs = &list_directories();
	($dir) = grep { $_->[0] eq $in{'dir'} } @dirs;
	&can_access_dir($dir->[0]) || &error($text{'dir_ecannot'});
	}

print "<form action=save_dir.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'dir_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# Directory to protect
print "<tr> <td><b>$text{'dir_dir'}</b></td> <td>\n";
if ($in{'new'}) {
	printf "<input name=dir size=50 value='%s'> %s\n",
		$dir->[0], &file_chooser_button("dir", 1);
	}
else {
	print "<input type=hidden name=dir value='$in{'dir'}'>\n";
	print "<tt>$dir->[0]</tt>\n";
	}
print "</td> </tr>\n";

# File containing users
print "<tr> <td valign=top><b>$text{'dir_file'}</b></td> <td>\n";
if ($can_htpasswd) {
	# Allow choice of users file
	if ($in{'new'}) {
		print "<input type=radio name=auto value=1 checked> ",
		      "$text{'dir_auto'}<br>\n";
		print "<input type=radio name=auto value=0> $text{'dir_sel'}\n";
		}
	printf "<input name=file size=50 value='%s'> %s</td> </tr>\n",
		$dir->[1], &file_chooser_button("file", 0);
	}
else {
	# Always automatic
	if ($in{'new'}) {
		print "$text{'dir_auto'}</td> </tr>\n";
		}
	else {
		print "<tt>$dir->[1]</tt></td> </tr>\n";
		}
	}

# File containing groups
if ($can_htgroups) {
	print "<tr> <td valign=top><b>$text{'dir_gfile'}</b></td> <td>\n";
	printf "<input type=radio name=gauto value=2 %s> %s<br>\n",
		$dir->[4] ? "" : "checked", $text{'dir_none'};
	if ($in{'new'}) {
		print "<input type=radio name=gauto value=1> ",
		      "$text{'dir_auto'}<br>\n";
		}
	printf "<input type=radio name=gauto value=0 %s> %s\n",
		$dir->[4] ? "checked" : "", $text{'dir_sel'};
	printf "<input name=gfile size=50 value='%s'> %s</td> </tr>\n",
		$dir->[4], &file_chooser_button("gfile", 0);
	}

# If MD5 encryption is available, show option for it
@crypts = ( 0 );
push(@crypts, 1) if ($config{'md5'});
push(@crypts, 2) if ($config{'sha1'});
push(@crypts, 3) if ($config{'digest'});
if (@crypts > 1) {
	print "<tr> <td><b>$text{'dir_crypt'}</b></td>\n";
	print "<td>",&ui_radio("crypt", int($dir->[2]),
	  [ map { [ $_, $text{'dir_crypt'.$_} ] } @crypts ]),"</td> </tr>\n";
	}
else {
	print "<input type=hidden name=crypt value=$crypts[0]>\n";
	}

# Authentication realm
print "<tr> <td><b>$text{'dir_realm'}</b></td>\n";
if (!$in{'new'}) {
	$conf = &foreign_call($apachemod, "get_htaccess_config",
			      "$dir->[0]/$config{'htaccess'}");
	$realm = &foreign_call($apachemod, "find_directive",
			       "AuthName", $conf, 1);
	}
printf "<td><input name=realm size=40 value='%s'></td> </tr>\n",
	$realm;

# Users and groups to allow
if (!$in{'new'}) {
	$require = &foreign_call($apachemod, "find_directive_struct",
				 "require", $conf);
	($rmode, @rwho) = @{$require->{'words'}} if ($require);
	}
else {
	$rmode = "valid-user";
	}
print "<tr> <td valign=top><b>$text{'dir_require'}</b></td>\n";
print "<td>",&ui_radio("require_mode", $rmode,
	[ [ "valid-user", $text{'dir_requirev'}."<br>" ],
	  [ "user", $text{'dir_requireu'}." ".
		    &ui_textbox("require_user",
			$rmode eq "user" ? join(" ", @rwho) : "", 40)."<br>" ],
	  [ "group", $text{'dir_requireg'}." ".
		    &ui_textbox("require_group",
			$rmode eq "group" ? join(" ", @rwho) : "", 40)."<br>" ] ]),
       "</td> </tr>\n";

# Webmin synchronization mode
if ($can_sync) {
	print "<tr> <td colspan=2><hr></td> </tr>\n";

	%sync = map { $_, 1 } split(/,/, $dir->[3]);
	foreach $s ('create', 'update', 'delete') {
		print "<tr> <td><b>",$text{'dir_sync_'.$s},"</b></td> <td>\n";
		printf "<input type=radio name=sync_%s value=1 %s> %s\n",
			$s, $sync{$s} ? "checked" : "", $text{'yes'};
		printf "<input type=radio name=sync_%s value=0 %s> %s\n",
			$s, $sync{$s} ? "" : "checked", $text{'no'};
		print "</td> </tr>\n";
		}
	}

print "</table></td></tr></table>\n";
if ($in{'new'}) {
	print "<input type=submit value='$text{'create'}'>\n";
	}
else {
	print "<input type=submit value='$text{'save'}'>\n";
	print "<input type=submit name=delete value='$text{'dir_delete'}'>\n";
	print "<input type=checkbox name=remove value=1 checked> ",
	       &text($dir->[4] ? 'dir_remove2' : 'dir_remove',
		     "<tt>$config{'htaccess'}</tt>",
		     "<tt>$config{'htpasswd'}</tt>",
		     "<tt>$config{'htgroups'}</tt>"),"\n";
	}
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

