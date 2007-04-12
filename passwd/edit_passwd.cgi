#!/usr/local/bin/perl
# edit_passwd.cgi

require './passwd-lib.pl';
&ReadParse();
&error_setup($text{'passwd_err'});

@user = getpwnam($in{'user'});
@user || &error($text{'passwd_euser'});
&can_edit_passwd(\@user) || &error($text{'passwd_ecannot'});

# Show password change form
&ui_print_header(undef, $text{'passwd_title'}, "");
print "<form action=save_passwd.cgi method=post>\n";
print "<input type=hidden name=user value='$user[0]'>\n";
print "<input type=hidden name=one value='$in{'one'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'passwd_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

%uconfig = &foreign_config("useradmin");
print "<tr> <td><b>$text{'passwd_for'}</b></td>\n";
$user[6] =~ s/,.*$// if ($uconfig{'extra_real'});
print "<td>$user[0]",( $user[6] ? " ($user[6])" : "" ),
      "</td> </tr>\n";

if ($access{'old'} == 1 ||
    $access{'old'} == 2 && $user[0] ne $remote_user) {
	print "<tr> <td><b>$text{'passwd_old'}</b></td>\n";
	print "<td><input name=old size=25 type=password></td> </tr>\n";
	}

print "<tr> <td><b>$text{'passwd_new'}</b></td>\n";
print "<td><input name=new size=25 type=password></td> </tr>\n";

if ($access{'repeat'}) {
	print "<tr> <td><b>$text{'passwd_repeat'}</b></td>\n";
	print "<td><input name=repeat size=25 type=password></td> </tr>\n";
	}

if (!$config{'passwd_cmd'} && $access{'expire'}) {
	&foreign_require("useradmin", "user-lib.pl");
	$pft = &useradmin::passfiles_type();
	($uuser) = grep { $_->{'user'} eq $in{'user'} }
			&useradmin::list_users();
	if ($uuser->{'max'} && ($pft == 2 || $pft == 5)) {
		print "<tr> <td colspan=2>\n";
		print "<input type=checkbox name=expire value=1> ",
		      "$text{'passwd_expire'}</td> </tr>\n";
		}
	}

if ($access{'others'} == 2) {
	print "<tr> <td colspan=2>\n";
	print "<input type=checkbox name=others value=1 checked> ",
	      "$text{'passwd_others'}</td> </tr>\n";
	}

print "<tr> <td colspan=2>\n";
print "<input type=submit value='$text{'passwd_change'}'>\n";
print "<input type=reset value='$text{'passwd_reset'}'></td> </tr>\n";

print "</table></td></tr></table></form>\n";
&ui_print_footer($in{'one'} ? ( "/", $text{'index'} ) :
			      ( "", $text{'index_return'} ));

