#!/usr/local/bin/perl
# edit_class.cgi
# Display a list of user classes for editing

require './wuftpd-lib.pl';
&ui_print_header(undef, $text{'class_title'}, "", "class");
$conf = &get_ftpaccess();

print "<form action=save_class.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'class_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

@class = ( &find_value("class", $conf), [ ] );
print "<tr> <td valign=top><b>$text{'class_class'}</b></td>\n";
print "<td colspan=3><table border width=100%>\n";
print "<tr $tb> <td><b>$text{'class_name'}</b></td> ",
      "<td><b>$text{'class_types'}</b></td> ",
      "<td><b>$text{'class_addrs'}</b></td> </tr>\n";
$i = 0;
foreach $c (@class) {
	print "<tr $cb>\n";
	print "<td><input name=class_$i size=10 value='$c->[0]'></td>\n";
	local %types;
	map { $types{$_}++ } split(/,/, $c->[1]);
	printf "<td><input type=checkbox name=types_$i value=real %s> %s\n",
		$types{'real'} ? 'checked' : '', $text{'class_real'};
	printf "<input type=checkbox name=types_$i value=anonymous %s> %s\n",
		$types{'anonymous'} ? 'checked' : '', $text{'class_anonymous'};
	printf "<input type=checkbox name=types_$i value=guest %s> %s</td>\n",
		$types{'guest'} ? 'checked' : '', $text{'class_guest'};
	printf "<td><input name=addrs_$i size=30 value='%s'></td>\n",
		join(" ", @$c[2..@$c-1]);
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";
foreach $g ('guestuser', 'guestgroup', 'realuser', 'realgroup') {
	print "<tr> <td><b>",$text{"class_$g"},"</b></td> <td colspan=3>\n";
	printf "<input name=%s size=50 value='%s'> %s</td> </tr>\n",
		$g, &join_all($g, $conf),
		$g =~ /user$/ ? &user_chooser_button($g, 1)
			      : &group_chooser_button($g, 1);
	}

print "<tr> <td colspan=4><hr></td> </tr>\n";
print "<tr> <td><b>",&text('class_ftpusers', "<tt>$config{'ftpusers'}</tt>"),
      "</b></td> <td colspan=3>\n";
open(FTPUSERS, $config{'ftpusers'});
while(<FTPUSERS>) {
	s/\r|\n//g;
	s/#.*$//;
	push(@ftpusers, $_) if (/\S/);
	}
close(FTPUSERS);
printf "<input name=ftpusers size=40 value='%s'> %s</td> </tr>\n",
	join(" ", @ftpusers), &user_chooser_button('ftpusers', 1);
foreach $g ('deny-uid', 'deny-gid', 'allow-uid', 'allow-gid') {
	($fg = $g) =~ s/-/_/g;
	print "<tr> <td><b>",$text{"class_$fg"},"</b></td> <td colspan=3>\n";
	printf "<input name=%s size=40 value='%s'> %s</td> </tr>\n",
		$fg, &join_all($g, $conf),
		$g =~ /uid$/ ? &user_chooser_button($fg, 1)
			     : &group_chooser_button($fg, 1);
	}

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

# join_all(name, &config)
sub join_all
{
local (@rv, $v);
foreach $v (&find_value($_[0], $_[1])) {
	push(@rv, @$v);
	}
return join(" ", @rv);
}

