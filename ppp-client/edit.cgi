#!/usr/local/bin/perl
# edit.cgi
# Display settings for some dialer

require './ppp-client-lib.pl';
&ReadParse();
$conf = &get_config();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'edit_title2'}, "");
	$dialer = $conf->[$in{'idx'}];
	}
($ddialer) = grep { lc($_->{'name'}) eq 'dialer defaults' } @$conf;
if ($inherits = $dialer->{'values'}->{'inherits'}) {
	($parent) = grep { lc($_->{'name'}) eq lc($inherits) } @$conf;
	}

if (lc($dialer->{'name'}) eq 'dialer defaults') {
	print "$text{'edit_ddesc'}<p>\n";
	}

print "<form action=save.cgi method=post>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_name'}</b></td> <td>\n";
if (lc($dialer->{'name'}) eq 'dialer defaults') {
	# Don't allow renaming of the defaults
	print $text{'index_defaults'};
	$defs++;
	}
elsif ($dialer->{'name'} =~ /^Dialer\s+(.*)$/ || $in{'new'}) {
	# Some normal dialer name
	print "<input name=dialer size=20 value='$1'>\n";
	}
else {
	# Some other oddly-named section
	print "<input name=name size=20 value='$dialer->{'name'}'>\n";
	}
print "</td>\n";

print &opt_input("Phone", $text{'edit_phone'}, 20);
print "</tr>\n";

print "<tr>\n";
print &opt_input("Username", $text{'edit_user'}, 20);
print &opt_input("Password", $text{'edit_pass'}, 20, "type=password");
print "</tr>\n";

print "<tr>\n";
print &opt_input("Dial Prefix", $text{'edit_prefix'}, 10);
print &yes_no_input("Stupid Mode", $text{'edit_stupid'}, 0);
print "</tr>\n";

print "<tr> <td><b>$text{'edit_other'}</b></td> <td colspan=3>\n";
for($i=1; $i<=4; $i++) {
	printf "<input name=other_%d size=20 value='%s'>\n",
		$i, $dialer->{'values'}->{'phone'.$i};
	}
print "</td> </tr>\n";

print "<tr> <td><b>$text{'edit_inherits'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=inherits_def value=1 %s> %s\n",
	$inherits ? "" : "checked", $text{'edit_def'};
printf "<input type=radio name=inherits_def value=0 %s> %s\n",
	$inherits ? "checked" : "", $text{'edit_from'};
print "<select name=inherits>\n";
foreach $c (@$conf) {
	next if ($c eq $dialer);
	printf "<option value='%s' %s>%s</option>\n",
		$c->{'name'}, lc($inherits) eq lc($c->{'name'}) ? "selected":"",
		&dialer_name($c->{'name'});
	}
print "</select></td> </tr>\n";

# Modem options
print "<tr> <td colspan=4><hr></td> </tr>\n";

$modem = $dialer->{'values'}->{'modem'};
$dm = &get_default("Modem");
local $found = !$modem || $modem eq "/dev/modem";
print "<tr> <td><b>$text{'edit_serial'}</b></td>\n";
print "<td nowrap><select name=modem>\n";
printf "<option value='' %s>%s %s</option>\n",
	$modem ? "" : "selected",
	$defs ? $text{'edit_none'} : $text{'edit_def'},
	$dm ? "($dm)" : "";
printf "<option value=/dev/modem %s>%s (%s)</option>\n",
	$modem eq "/dev/modem" ? "selected" : "", $text{'edit_modem'},
	"/dev/modem";
foreach $t (sort { "$a$b" =~ /^\/dev\/ttyS(\d+)\/dev\/ttyS(\d+)$/ ? $1 <=> $2 : 0 } glob("/dev/ttyS[0-9]*")) {
	printf "<option value=%s %s>%s</option>\n",
		$t, $modem eq $t ? "selected" : "",
		$t =~ /ttyS(\d+)$/ ? &text('edit_port', $1+1) : $t;
	$found++ if ($modem eq $t);
	}
printf "<option value=* %s>%s</option>\n",
	$found ? "" : "selected", $text{'edit_otherm'};
print "</select>\n";
printf "<input name=otherm size=15 value='%s'></td>\n",
	$found ? "" : $modem;

print &opt_input("Baud", $text{'edit_baud'}, 6);
print "</tr>\n";

print "<tr> <td valign=top><b>$text{'edit_init'}</b></td> <td colspan=3>\n";
for($i=1; $i<=9; $i++) {
	printf "<input name=init_%s size=25 value='%s'>\n",
		$i, $dialer->{'values'}->{"init".$i};
	print "<br>\n" if (($i-1)%3 == 2);
	}
print "</td> </tr>\n";

print "<tr>\n";
print &yes_no_input("Carrier Check", $text{'edit_carrier'}, 1);
print &yes_no_input("Abort on Busy", $text{'edit_busy'}, 0);
print "</tr>\n";

print "<tr>\n";
print &opt_input("Dial Attempts", $text{'edit_dial'}, 4);
print &yes_no_input("Abort on No Dialtone", $text{'edit_dialtone'}, 1);
print "</tr>\n";

# Networking options
print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr>\n";
print &yes_no_input("Auto DNS", $text{'edit_dns'}, 1);
print &yes_no_input("Auto Reconnect", $text{'edit_reconnect'}, 1);
print "</tr>\n";

print "<tr>\n";
print &opt_input("Idle Seconds", $text{'edit_idle'}, 6);
print "</tr>\n";

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
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

# opt_input(name, text, size, inputopts)
sub opt_input
{
local $n = lc($_[0]);
local $v = $dialer->{'values'}->{$n};
local $rv = "<td><b>$_[1]</b></td> <td nowrap>\n";
$rv .= sprintf "<input type=radio name='${n}_def' value=1 %s> %s\n",
		defined($v) ? "" : "checked",
		$defs ? $text{'edit_none'} : $text{'default'};
$rv .= sprintf "<input type=radio name='${n}_def' value=0 %s>\n",
		defined($v) ? "checked" : "";
$rv .= sprintf "<input $_[3] name='${n}' size=$_[2] value='%s'></td>\n", $v;
return $rv;
}

# yes_no_input(name, text, defmode)
sub yes_no_input
{
local $n = lc($_[0]);
local $val = $dialer->{'values'}->{$n};
local $dval = &get_default($_[0]);
local $d = $dval =~ /on|yes|1/i ? $text{'edit_yd'} :
	   $dval =~ /off|no|0/i ? $text{'edit_nd'} :
	   $_[2] ? $text{'edit_yd'} : $text{'edit_nd'};
local $rv = "<td><b>$_[1]</b></td> <td>\n";
$rv .= sprintf "<input type=radio name='$n' value=1 %s> %s\n",
	$val =~ /on|yes|1/i ? "checked" : "", $text{'yes'};
$rv .= sprintf "<input type=radio name='$n' value=0 %s> %s\n",
	$val =~ /off|no|0/i ? "checked" : "", $text{'no'};
$rv .= sprintf "<input type=radio name='$n' value=-1 %s> %s</td>\n",
	$val ? "" : "checked", $d;
return $rv;
}

# get_default(name)
sub get_default
{
return undef if ($defs);
if ($parent) {
	local $pv = $parent->{'values'}->{lc($_[0])};
	return $pv if (defined($pv));
	}
return $ddialer->{'values'}->{lc($_[0])};
}

