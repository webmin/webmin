#!/usr/local/bin/perl
# edit_modules.cgi
# Edit which modules are loaded from which shared libraries by the server

require './jabber-lib.pl';
&ui_print_header(undef, $text{'modules_title'}, "", "modules");

print "$text{'modules_desc'}<p>\n";

$conf = &get_jabber_config();
$session = &find_by_tag("service", "id", "sessions", $conf);
$load = &find("load", $session);

print "<form action=save_modules.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'modules_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'modules_mod'}</b></td> ",
      "<td><b>$text{'modules_so'}</b></td> ",
      "<td><b>$text{'modules_mod'}</b></td> ",
      "<td><b>$text{'modules_so'}</b></td> </tr>\n";
for($i=1; $i<@{$load->[1]}; $i+=2) {
	if ($load->[1]->[$i] ne '0') {
		push(@mods, [ $load->[1]->[$i], $load->[1]->[$i+1] ] );
		}
	}
if (scalar(@mods)%2 == 0) {
	push(@mods, [ ], [ ]);
	}
else {
	push(@mods, [ ]);
	}
for($n=0; $n<@mods; $n++) {
	print "<tr>\n" if ($n%2 == 0);
	printf "<td><input name=%s size=15 value='%s'></td>\n",
		"mod_$n", $mods[$n]->[0];
	printf "<td><input name=%s size=15 value='%s'></td>\n",
		"so_$n", &value_in($mods[$n]);
	print "</tr>\n" if ($n%2 == 1);
	}

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

