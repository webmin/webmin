#!/usr/local/bin/perl
# list_mgetty.cgi
# Displays a list of serial ports on which mgetty is enabled by searching
# for them in /etc/inittab

require './pap-lib.pl';
$access{'mgetty'} || &error($text{'mgetty_ecannot'});
&foreign_require("inittab", "inittab-lib.pl");
&ui_print_header(undef, $text{'mgetty_title'}, "");

if (!&has_command($config{'mgetty'})) {
	print "<p>",&text('mgetty_ecmd', "<tt>$config{'mgetty'}</tt>"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
print &text('mgetty_desc', "<tt>mgetty</tt>"),"<p>\n";

@mgi = &mgetty_inittabs();
if (@mgi) {
	print &ui_link("edit_mgetty.cgi?new=1",$text{'mgetty_add'}),"<br>\n";
	print "<table border>\n";
	print "<tr $tb> <td><b>$text{'mgetty_tty'}</b></td> ",
	      "<td><b>$text{'mgetty_type'}</b></td> ",
	      "<td><b>$text{'mgetty_speed'}</b></td> ",
	      "<td><b>$text{'mgetty_answer'}</b></td> ",
	      "<td><b>$text{'mgetty_config'}</b></td> </tr>\n";
	foreach $m (@mgi) {
		print "<tr $cb>\n";
		local $tty = $m->{'tty'} =~ /^ttyS(\d+)$/ ?
			&text('mgetty_ts', $1+1) :
			$m->{'tty'} =~ /^term\/(\S+)$/ ?
			&text('mgetty_ts', uc($1)) :
			$m->{'tty'} =~ /^\// ? $m->{'tty'} : "/dev/$m->{'tty'}";
		if ($m->{'mgetty'}) {
			print "<td><a href='edit_mgetty.cgi?id=$m->{'id'}'>",
			      "$tty</a></td>\n";
			print "<td>",$m->{'direct'} ? $text{'mgetty_direct'}
					    : $text{'mgetty_modem'},"</td>\n";
			print "<td>",$m->{'speed'} ||
				     $text{'mgetty_auto'},"</td>\n";
			print "<td>",defined($m->{'rings'}) ? $m->{'rings'}
					    : 1," $text{'mgetty_rings'}</td>\n";
			local $fn = $m->{'tty'};
			$fn =~ s/^\/dev\///;
			$fn =~ s/\//\./g;
			if ($access{'options'}) {
				print "<td><a href='edit_options.cgi?",
				      "file=$config{'ppp_options'}.$fn'>",
				      "$text{'mgetty_cedit'}</a></td>\n";
				}
			else {
				print "<td><br></td>\n";
				}
			}
		else {
			print "<td>$tty</td>\n";
			print "<td colspan=4>$text{'mgetty_vgetty'}</td>\n";
			}
		print "</tr>\n";
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'mgetty_none'}</b><p>\n";
	}
print &ui_link("edit_mgetty.cgi?new=1",$text{'mgetty_add'}),"<p>\n";

print &ui_hr();
print "<form action=mgetty_apply.cgi>\n";
print "<table width=100%><tr>\n";
print "<td><input type=submit value='$text{'mgetty_apply'}'></td>\n";
print "<td>",&text('mgetty_applydesc', "<tt>telinit q</tt>"),"</td>\n";
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

