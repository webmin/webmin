#!/usr/local/bin/perl
# edit_user.cgi
# Display a form for editing or creating a user

require './postgresql-lib.pl';
&ReadParse();
$access{'users'} || &error($text{'user_ecannot'});
if ($in{'new'}) {
	&ui_print_header(undef, $text{'user_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'user_edit'}, "");
	$s = &execute_sql_safe($config{'basedb'}, "select * from pg_shadow ".
					     "where usename = '$in{'user'}'");
	@user = @{$s->{'data'}->[0]};
	}

print "<form action=save_user.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=user value='$in{'user'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'user_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'user_name'}</b></td>\n";
if ($in{'new'} || &get_postgresql_version() >= 7.4) {
	print "<td><input name=name value='$user[0]' size=20></td>\n";
	}
else {
	print "<td>$user[0]</td>\n";
	}

print "<td><b>$text{'user_passwd'}</b></td>\n";
if ($in{'new'}) {
	# For new users, can select empty or specific password
	print "<td>",&ui_radio("pass_def", 1,
			[ [ 1, $text{'user_none'} ],
			  [ 0, $text{'user_setto'} ] ]),"\n",
		     &ui_password("pass", undef, 20),"</td> </tr>\n";
	}
else {
	# For existing users, can select empty, leave unchanged or
	# specific password
	print "<td>",&ui_radio("pass_def", 2,
			[ [ 2, $text{'user_nochange'} ],
			  [ 0, $text{'user_setto'} ] ]),"\n",
		     &ui_password("pass", undef, 20),"</td> </tr>\n";
	}

print "<tr> <td><b>$text{'user_db'}</b></td>\n";
printf "<td><input type=radio name=db value=1 %s> $text{'yes'}\n",
	$user[2] =~ /t|1/ ? 'checked' : '';
printf "<input type=radio name=db value=0 %s> $text{'no'}</td>\n",
	$user[2] =~ /t|1/ ? '' : 'checked';

print "<td><b>$text{'user_other'}</b></td>\n";
printf "<td><input type=radio name=other value=1 %s> $text{'yes'}\n",
	$user[4] =~ /t|1/ ? 'checked' : '';
printf "<input type=radio name=other value=0 %s> $text{'no'}</td> </tr>\n",
	$user[4] =~ /t|1/ ? '' : 'checked';

print "<tr> <td><b>$text{'user_until'}</b></td> <td colspan=3>\n";
if (!$user[6]) {
	printf "<input type=radio name=until_def value=1 %s> %s\n",
		$user[6] ? '' : 'checked', $text{'user_forever'};
	printf "<input type=radio name=until_def value=0 %s>\n",
		$user[6] ? 'checked' : '';
	}
print "<input name=until size=30 value='$user[6]'></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table>\n";

&ui_print_footer("list_users.cgi", $text{'user_return'});

