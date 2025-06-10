#!/usr/local/bin/perl
# edit_conf.cgi
# Display PPTP server options

require './pptp-server-lib.pl';
$access{'conf'} || &error($text{'conf_ecannot'});
&ui_print_header(undef, $text{'conf_title'}, "", "conf");

# Show actual options
$conf = &get_config();
print "<form action=save_conf.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'conf_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Maximum PPP speed
$speed = &find_conf("speed", $conf);
print "<tr> <td><b>$text{'conf_speed'}</b></td> <td>\n";
printf "<input type=radio name=speed_def value=1 %s> %s\n",
	$speed ? "" : "checked", $text{'default'};
printf "<input type=radio name=speed_def value=0 %s>\n",
	$speed ? "checked" : "";
printf "<input name=speed size=8 value='%s'> %s</td>\n",
	$speed, $text{'conf_baud'};

# Listen address
$listen = &find_conf("listen", $conf);
print "<td><b>$text{'conf_listen'}</b></td> <td>\n";
printf "<input type=radio name=listen_def value=1 %s> %s\n",
	$listen ? "" : "checked", $text{'conf_all'};
printf "<input type=radio name=listen_def value=0 %s>\n",
	$listen ? "checked" : "";
printf "<input name=listen size=15 value='%s'></td> </tr>\n",
	$listen;

# PPP options file
$option = &find_conf("option", $conf);
$mode = $option eq $options_pptp ? 1 : $option ? 2 : 0;
print "<td><b>$text{'conf_option'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=mode value=0 %s> %s\n",
	$mode == 0 ? "checked" : "", $text{'conf_mode0'};
printf "<input type=radio name=mode value=1 %s> %s\n",
	$mode == 1 ? "checked" : "", $text{'conf_mode1'};
printf "<input type=radio name=mode value=2 %s> %s\n",
	$mode == 2 ? "checked" : "", $text{'conf_mode2'};
printf "<input name=option size=25 value='%s'>&nbsp;%s</td> </tr>\n",
	$mode == 2 ? $option : "", &file_chooser_button("option");

# Local IP ranges
&ip_table("localip");

# Remote IP ranges
&ip_table("remoteip");

# IPX networks
$ipxnets = &find_conf("ipxnets", $conf);
($from, $to) = split(/-/, $ipxnets);
print "<td><b>$text{'conf_ipxnets'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=ipxnets_def value=1 %s> %s\n",
	$ipxnets ? "" : "checked", $text{'conf_all'};
printf "<input type=radio name=ipxnets_def value=0 %s>\n",
	$ipxnets ? "checked" : "";
printf "<b>%s</b> <input name=from size=8 value='%s'>\n",
	$text{'conf_from'}, $from;
printf "<b>%s</b> <input name=to size=8 value='%s'>\n",
	$text{'conf_to'}, $from;
print "</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

sub ip_table
{
local @ips = split(/,/, &find_conf($_[0], $conf));
print "<tr> <td valign=top><b>",$text{'conf_'.$_[0]},
      "</b></td> <td colspan=2>\n";
print "<textarea name=$_[0] rows=3 cols=50>",
	join("\n", @ips),"</textarea>\n";
print "</td>\n";
if ($_[0] eq "localip") {
	print "<td rowspan=2 valign=top>$text{'conf_ipdesc'}</td>\n";
	}
print "</tr>\n";
}

