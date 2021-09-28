#!/usr/local/bin/perl
# edit_dialin.cgi
# Display a list of allowed and denied caller-ID numbers

require './pap-lib.pl';
$access{'dialin'} || &error($text{'dialin_ecannot'});
&ui_print_header(undef, $text{'dialin_title'}, "");

# Check for the mgetty login config file
if (!-r $config{'login_config'}) {
	print "<p>",&text('dialin_efile', "<tt>$config{'dialin_config'}</tt>",
	    "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
@dialin = &parse_dialin_config();

print "$text{'dialin_desc'}<p>\n";

if (@dialin) {
	print &ui_link("edit_dialin.cgi?new=1",$text{'dialin_add'}),"<br>\n";
	print "<table border>\n";
	print "<tr $tb> <td><b>$text{'dialin_number'}</b></td> ",
	      "<td><b>$text{'dialin_ad'}</b></td> ",
	      "<td><b>$text{'dialin_move'}</b></td> </tr>\n";
	foreach $d (@dialin) {
		print "<tr $cb>\n";
		print "<td><a href='edit_dialin.cgi?idx=$d->{'index'}'>",
			$d->{'number'} eq 'all' ? $text{'dialin_all'} :
			$d->{'number'} eq 'none' ? $text{'dialin_none'} :
			$d->{'number'},"</a></td>\n";
		print "<td>",$d->{'not'} ? $text{'dialin_deny'}
					 : $text{'dialin_allow'},"</td>\n";
		print "<td>";
		if ($d eq $dialin[@dialin-1]) {
			print "<img src=images/gap.gif>";
			}
		else {
			print "<a href='move.cgi?idx=$d->{'index'}&down=1'>",
			      "<img src=images/down.gif border=0></a>";
			}
		if ($d eq $dialin[0]) {
			print "<img src=images/gap.gif>";
			}
		else {
			print "<a href='move.cgi?idx=$d->{'index'}&up=1'>",
			      "<img src=images/up.gif border=0></a>";
			}
		print "</td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'dialin_nonumbers'}</b> <p>\n";
	}
print &ui_link("edit_dialin.cgi?new=1",$text{'dialin_add'}),"<p>\n";

&ui_print_footer("", $text{'index_return'});

