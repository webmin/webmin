#!/usr/local/bin/perl
# edit_env.cgi
# Edit an existing or new environment variable

require './cron-lib.pl';
&ReadParse();

if (!$in{'new'}) {
	@jobs = &list_cron_jobs();
	$env = $jobs[$in{'idx'}];
	&can_edit_user(\%access, $env->{'user'}) ||
		&error($text{'edit_ecannot'});
	&ui_print_header(undef, $text{'env_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'env_title2'}, "");
	$env = { 'active' => 1 };
	}

print "$text{'env_order'}<p>\n";

print "<form action=save_env.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'env_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'env_user'}</b></td>\n";
if ($access{'mode'} == 1) {
	print "<td><select name=user>\n";
	foreach $u (split(/\s+/, $access{'users'})) {
		printf "<option %s>$u\n",
			$env->{'user'} eq $u ? "selected" : "";
		}
	print "</select></td>\n";
	}
elsif ($access{'mode'} == 3) {
	print "<td><tt>$remote_user</tt></td>\n";
	print "<input type=hidden name=user value='$remote_user'>\n";
	}
else {
	print "<td><input name=user size=8 value=\"$env->{'user'}\"> ",
		&user_chooser_button("user", 0),"</td>\n";
	}

print "<td> <b>$text{'env_active'}</b></td>\n";
printf "<td><input type=radio name=active value=1 %s> $text{'yes'}\n",
	$env->{'active'} ? "checked" : "";
printf "<input type=radio name=active value=0 %s> $text{'no'}</td> </tr>\n",
	$env->{'active'} ? "" : "checked";

print "<td> <b>$text{'env_name'}</b></td>\n";
printf "<td><input name=name size=30 value='%s'></td> </tr>\n",
	$env->{'name'};

print "<td> <b>$text{'env_value'}</b></td>\n";
printf "<td><input name=value size=60 value='%s'></td> </tr>\n",
	$env->{'value'};

if ($in{'new'}) {
	# Location for new variable
	print "<td> <b>$text{'env_where'}</b></td> <td colspan=3>\n";
	print &ui_radio("where", 1, [ [ 1, $text{'env_top'} ],
				      [ 0, $text{'env_bot'} ] ]),"</td></tr>\n";
	}
elsif ($env->{'index'}) {
	# Location for existing
	print "<td> <b>$text{'env_where2'}</b></td> <td colspan=3>\n";
	print &ui_radio("where", 0, [ [ 1, $text{'env_top'} ],
				      [ 0, $text{'env_leave'} ]]),"</td></tr>\n";
	}

print "</table></td></tr></table>\n";

print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "</form><form action=delete_env.cgi>\n";
	print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
	print "<td align=right><input type=submit name=delete ",
              "value='$text{'delete'}'></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

