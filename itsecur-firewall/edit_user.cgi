#!/usr/bin/perl
# edit_user.cgi
# Show one Webmin user

require './itsecur-lib.pl';
&foreign_require("acl", "acl-lib.pl");
&can_use_error("users");
@users = &acl::list_users();
&ReadParse();

if ($in{'new'}) {
	&header($text{'user_title1'}, "",
		undef, undef, undef, undef, &apply_button());
	%gotmods = ( $module_name, 1 );
	}
else {
	&header($text{'user_title2'}, "",
		undef, undef, undef, undef, &apply_button());
	($user) = grep { $_->{'name'} eq $in{'name'} } @users;
	%gotmods = map { $_, 1 } @{$user->{'modules'}};
	}
print "<hr>\n";

print "<form action=save_user.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=old value='$in{'name'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'user_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# Show username
print "<tr> <td nowrap><b>$text{'user_name'}</b></td> <td>\n";
printf "<input name=name size=20 value='%s'></td> </tr>\n",
	$user->{'name'};

# Show password
print "<tr> <td nowrap><b>$text{'user_pass'}</b></td> <td>\n";
if (!$in{'new'}) {
	print "<input type=radio name=same value=1 checked> ",
	      "$text{'user_same'}\n";
	print "<input type=radio name=same value=0> ",
	      "$text{'user_change'}\n";
	}
print "<input name=pass type=password size=20></td> </tr>\n";

# Show enabled flag
print "<tr> <td nowrap><b>$text{'user_enabled'}</b></td> <td>\n";
printf "<input type=radio name=enabled value=1 %s> %s\n",
	$user->{'pass'} =~ /^\*LK\*/ ? "" : "checked", $text{'yes'};
printf "<input type=radio name=enabled value=0 %s> %s</td> </tr>\n",
	$user->{'pass'} =~ /^\*LK\*/ ? "checked" : "", $text{'no'};

# Show allowed IPS
print "<tr> <td valign=top nowrap><b>$acl::text{'edit_ips'}</b></td>\n";
print "<td><table><tr>\n";
printf "<td nowrap><input name=ipmode type=radio value=0 %s> %s<br>\n",
	$user->{'allow'} || $user->{'deny'} ? '' : 'checked',
	$acl::text{'edit_all'};
printf "<input name=ipmode type=radio value=1 %s> %s<br>\n",
	$user->{'allow'} ? 'checked' : '', $acl::text{'edit_allow'};
printf "<input name=ipmode type=radio value=2 %s> %s</td> <td>\n",
	$user->{'deny'} ? 'checked' : '', $acl::text{'edit_deny'};
print "<textarea name=ips rows=4 cols=30>",
      join("\n", split(/\s+/, $user->{'allow'} ? $user->{'allow'}
					     : $user->{'deny'})),
      "</textarea></td>\n";
print "</tr></table></td> </tr>\n";

# Show allowed modules (from list for *this* user)
print "<tr> <td valign=top nowrap><b>$text{'user_mods'}</b></td>\n";
&read_acl(\%acl);
@mymods = grep { $acl{$base_remote_user,$_->{'dir'}} } &get_all_module_infos();
print "<td><select name=mods size=5 multiple>\n";
foreach $m (sort { $a->{'desc'} cmp $b->{'desc'} } @mymods) {
	printf "<option value=%s %s>%s</option>\n",
		$m->{'dir'}, $gotmods{$m->{'dir'}} ? "selected" : "",
		$m->{'desc'};
	}
print "</select></td> </tr>\n";

# Show access control
print "<tr> <td colspan=2><hr></td> </tr>\n";
require "./acl_security.pl";
if ($in{'new'}) {
	%uaccess = ( 'features' => 'rules services groups nat pat spoof logs apply',
		     'rfeatures' => 'rules services groups nat pat spoof logs apply',
		     'edit' => 1 );
	}
else {
	%uaccess = &get_module_acl($user->{'name'});
	}
&acl_security_form(\%uaccess);

print "</table></td></tr></table>\n";
if ($in{'new'}) {
	print "<input type=submit value='$text{'create'}'>\n";
	}
else {
	print "<input type=submit value='$text{'save'}'>\n";
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
print "</form>\n";
&can_edit_disable("users");

print "<hr>\n";
&footer("list_users.cgi", $text{'users_return'});

