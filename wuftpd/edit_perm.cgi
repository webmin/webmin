#!/usr/local/bin/perl
# edit_perm.cgi
# Display file permission options

require './wuftpd-lib.pl';
&ui_print_header(undef, $text{'perm_title'}, "", "perm");

$conf = &get_ftpaccess();
@class = &find_value("class", $conf);

print "<form action=save_perm.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'perm_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Display permission options (chmod, delete, etc..)
@permtypes = ( 'chmod', 'delete', 'overwrite', 'rename', 'umask' );
foreach $t (@permtypes) {
	push(@perms, &find($t, $conf));
	}
@perms = ( ( sort { $a->{'line'} <=> $b->{'line'} } @perms ), { } );
print "<tr> <td valign=top><b>$text{'perm_perms'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'perm_type'}</b></td>\n",
      "<td><b>$text{'perm_can'}</b></td>\n",
      "<td><b>$text{'perm_users'}</b></td>\n",
      "<td><b>$text{'perm_classes'}</b></td> </tr>\n";
$i = 0;
foreach $p (@perms) {
	$v = $p->{'values'};
	print "<tr $cb>\n";

	print "<td><select name=type_$i>\n";
	printf "<option %s></option>\n", $p->{'name'} ? '' : 'checked';
	foreach $t (@permtypes) {
		printf "<option %s>%s</option>\n",
			$p->{'name'} eq $t ? 'selected' : '', $t;
		}
	print "</select></td>\n";

	printf "<td><input type=radio name=can_$i value=yes %s> %s\n",
		lc($v->[0]) eq 'yes' ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=can_$i value=no %s> %s</td>\n",
		lc($v->[0]) eq 'yes' ? '' : 'checked', $text{'no'};

	local (%users, $notall);
	map { $users{$_}++; $notall++ if (/class=/) } split(/,/, $v->[1]);
	print "<td>\n";
	foreach $u ('anonymous', 'guest', 'real') {
		printf "<input name=users_%s type=checkbox value=%s %s> %s\n",
			$i, $u, $users{$u} ? 'checked' : '', $text{"perm_$u"};
		}
	print "</td>\n";

	if (!$notall) {
		map { $users{"class=".$_->[0]}++ } @class;
		}
	print "<td>\n";
	foreach $c (@class) {
		printf "<input name=classes_%s type=checkbox value=%s %s> %s\n",
			$i, $c->[0], $users{"class=$c->[0]"} ? 'checked' : '',
			$c->[0];
		}
	print "</td> </tr>\n";
	$i++;
	}
print "</table><br>$text{'perm_note'}</td> </tr>\n";
print "<tr> <td colspan=4><hr></td> </tr>\n";

# Display path-filter options
@filter = ( &find_value('path-filter', $conf), [ ] );
print "<tr> <td valign=top><b>$text{'perm_filter'}</b></td> <td colspan=3>\n";
print "<table border> <tr $tb> <td><b>$text{'perm_char'}</b></td>\n",
      "<td><b>$text{'perm_regexp'}</b></td>\n",
      "<td><b>$text{'perm_types'}</b></td>\n",
      "<td><b>$text{'perm_mesg'}</b></td> </tr>\n";
$i = 0;
foreach $f (@filter) {
	print "<tr $cb>\n";
	print "<td><input name=char_$i size=15 value='$f->[2]'></td>\n";
	printf "<td><input name=regexp_$i size=25 value='%s'></td>\n",
		join(" ", @$f[3..@$f-1]);
	print "<td>\n";
	foreach $u ('anonymous', 'guest', 'real') {
		printf "<input name=types_%s type=checkbox value=%s %s> %s\n",
			$i, $u, $f->[0] =~ /$u/ ? 'checked' : '',
			$text{"perm_$u"};
		}
	print "</td>\n";
	print "<td><input name=mesg_$i size=20 value='$f->[1]'></td> </tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

