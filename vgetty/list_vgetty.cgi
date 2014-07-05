#!/usr/local/bin/perl
# list_vgetty.cgi
# Displays a list of serial ports on which vgetty is enabled by searching
# for them in /etc/inittab

require './vgetty-lib.pl';
&foreign_require("inittab", "inittab-lib.pl");
&ui_print_header(undef, $text{'vgetty_title'}, "");

print &text('vgetty_desc', "<tt>vgetty</tt>"),"<p>\n";

@vgi = &vgetty_inittabs();
if (@vgi) {
	print &ui_link("edit_vgetty.cgi?new=1",$text{'vgetty_add'}),"<br>\n";
	print "<table border>\n";
	print "<tr $tb> <td><b>$text{'vgetty_tty'}</b></td> ",
	      "<td><b>$text{'vgetty_type'}</b></td> </tr>\n";
	foreach $v (@vgi) {
		print "<tr $cb>\n";
		local $tty = $v->{'tty'} =~ /^ttyS(\d+)$/ ?
			&text('vgetty_ts', $1+1) :
			$v->{'tty'} =~ /^\// ? $v->{'tty'} : "/dev/$v->{'tty'}";
		if ($v->{'vgetty'}) {
			print "<td><a href='edit_vgetty.cgi?id=$v->{'id'}'>",
			      "$tty</a></td>\n";
			print "<td>$text{'vgetty_vgetty'}</td>\n";
			}
		else {
			print "<td>$tty</td>\n";
			print "<td>$text{'vgetty_mgetty'}</td>\n";
			}
		print "</tr>\n";
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'vgetty_none'}</b><p>\n";
	}
print &ui_link("edit_vgetty.cgi?new=1",$text{'vgetty_add'}),"<p>\n";

&ui_print_footer("", $text{'index_return'});

