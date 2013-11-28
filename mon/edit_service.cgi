#!/usr/local/bin/perl
# edit_service.cgi
# Display a new or existing service inside a watch

require './mon-lib.pl';
&ReadParse();
$conf = &get_mon_config();
$watch = $conf->[$in{'idx'}];

if ($in{'new'}) {
	&ui_print_header(undef, $text{'service_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'service_title2'}, "");
	$service = $watch->{'members'}->[$in{'sidx'}];
	}

print "<form action=save_service.cgi method=post>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=sidx value='$in{'sidx'}'>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'service_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'service_name'}</b></td>\n";
printf "<td><input name=name size=20 value='%s'></td>\n",
	$service->{'values'}->[0];

$int = &find_value("interval", $service->{'members'});
print "<td><b>$text{'service_interval'}</b></td>\n";
print "<td>",&interval_input("interval", $int),"</td> </tr>\n";

$desc = &find("description", $service->{'members'});
print "<tr> <td><b>$text{'service_desc'}</b></td>\n";
printf "<td colspan=3><input name=desc size=50 value='%s'></td> </tr>\n",
	$desc ? $desc->{'value'} : "";

@mons = &list_monitors();
$monitor = &find("monitor", $service->{'members'}) if (!$in{'new'});
if ($monitor->{'value'} =~ /^(\S+)\s*(.*)$/) {
	$mon = $1; $args = $2;
	}
$idx = &indexof($mon, @mons);

print "<tr> <td><b>$text{'service_monitor'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=monitor_def value=1 %s> %s\n",
	$in{'new'} || $idx >= 0 ? "checked" : "", $text{'service_mon1'};
print "<select name=monitor>\n";
foreach $m (@mons) {
	printf "<option %s>%s</option>\n", $m eq $mon ? "selected" : "", $m;
	}
print "</select>\n";
printf "<input type=radio name=monitor_def value=0 %s> %s\n",
	$in{'new'} || $idx >= 0 ? "" : "checked", $text{'service_mon0'};
printf "<input name=other size=20 value='%s'>\n",
	$idx >= 0 ? "" : $mon;
print "</td> </tr>\n";

print "<tr> <td><b>$text{'service_args'}</b></td> <td colspan=3>\n";
print "<input name=args size=50 value='$args'></td> </tr>\n";

$i = 0;
@avail = &list_alerts();
@periods = &find("period", $service->{'members'});
push(@periods, { }) if ($in{'newperiod'} || $in{'new'});
@defperiods = &find("period", $conf);
foreach $p (@periods) {
	print "<tr> <td colspan=4><hr></td> </tr>\n";
	print "<tr> <td colspan=2><b><i>",&text($p->{'name'} ?
		'service_period' : 'service_new', $i+1),"</i></b></td>\n";
	print "<td colspan=2 align=right><input type=checkbox name=delete_$i> ",
	      "$text{'service_delperiod'}</td> </tr>\n";

	print "<input type=hidden name=idx_$i value='$p->{'index'}'>\n";
	local ($dfrom, $dto, $hfrom, $hto, $known, $name);
	if ($p->{'value'} =~ /^\s*wd\s+{(\S+)-(\S+)}\s+hr\s+{(\S+)-(\S+)}\s*$/){
		$dfrom = $1; $dto = $2; $hfrom = $3; $hto = $4;
		$known = 1;
		}
	elsif ($p->{'value'} =~ /^\s*wd\s+{(\S+)-(\S+)}\s*$/) {
		$dfrom = $1; $dto = $2;
		$known = 1;
		}
	elsif ($p->{'value'} =~ /^\s*hr\s+{(\S+)-(\S+)}\s*$/) {
		$hfrom = $1; $hto = $2;
		$known = 1;
		}
	elsif ($p->{'value'} =~ /^\s*(\S+):\s*$/) {
		$name = $1;
		$known = 2;
		}
	elsif (!$p->{'value'}) {
		$hfrom = $hto = "";
		$known = 1;
		}

	# Specified days and hours
	printf "<tr> <td><input type=radio name=known_$i value=1 %s> %s</td>\n",
		$known == 1 ? "checked" : "", "<b>$text{'service_known1'}</b>";

	print "<td colspan=3><b>$text{'service_days'}</b>\n";
	printf "<input type=radio name=days_def_$i value=1 %s> %s\n",
		$dfrom ? "" : "checked", $text{'service_all'};
	printf "<input type=radio name=days_def_$i value=0 %s>\n",
		$dfrom ? "checked" : "";
	print &day_input("dfrom_$i", $dfrom)," - ",
	      &day_input("dto_$i", $dto);

	print "&nbsp;&nbsp;&nbsp;\n";
	print "<b>$text{'service_hours'}</b>\n";
	printf "<input type=radio name=hours_def_$i value=1 %s> %s\n",
		$hfrom ? "" : "checked", $text{'service_all'};
	printf "<input type=radio name=hours_def_$i value=0 %s>\n",
		$hfrom ? "checked" : "";
	print "<input name=hfrom_$i size=4 value='$hfrom'> - ",
	      "<input name=hto_$i size=4 value='$hto'></td> </tr>\n";

	# Selected defined period
	if (@defperiods || $known == 2) {
		printf "<tr> <td><input type=radio name=known_$i value=2 %s> %s</td>\n", $known == 2 ? "checked" : "", "<b>$text{'service_known2'}</b>";
		print "<td><select name=name_$i>\n";
		foreach $p (@defperiods) {
			$p->{'value'} =~ /^(\S+):/;
			printf "<option %s>%s</option>\n",
				$name eq $1 ? "selected" : "", $1;
			}
		print "</select></td> </tr>\n";
		}

	# Any Time::Period string
	printf "<tr> <td><input type=radio name=known_$i value=0 %s> %s</td>\n",
		$known == 0 ? "checked" : "", "<b>$text{'service_known0'}</b>";
	printf "<td colspan=3><input name=pstr_$i size=50 value='%s'></td> </tr>\n", $known == 0 ? $p->{'value'} : "";

	print "<tr> <td valign=top><b>$text{'service_alerts'}</b></td>\n";
	print "<td colspan=3><table border>\n";
	print "<tr $tb> <td><b>$text{'service_alert'}</b></td> ",
	      "<td><b>$text{'service_atype'}</b></td> ",
	      "<td><b>$text{'service_aargs'}</b></td> </tr>\n";
	local @alerts = ( &find("alert", $p->{'members'}),
			  &find("upalert", $p->{'members'}),
			  &find("startupalert", $p->{'members'}) );
	local $j = 0;
	foreach $a (@alerts, { }) {
		print "<tr $cb> <td><select name=alert_${i}_${j}>\n";
		local ($found, $al, $ar);
		if ($a->{'value'} =~ /^(\S+)\s*(.*)/) {
			$al = $1; $ar = $2;
			}
		printf "<option value='' %s>&nbsp;</option>\n",
			$al ? "" : "selected";
		foreach $av (@avail) {
			printf "<option %s>%s</option>\n",
			    $al eq $av ? "selected" : "", $av;
			$found++ if ($al eq $av);
			}
		print "<option selected>$al</option>\n" if (!$found && $al);
		print "</select></td>\n";
		print "<td><select name=atype_${i}_${j}>\n";
		foreach $t ('alert', 'upalert', 'startupalert') {
			printf "<option value=%s %s>%s</option>\n",
				$t, $a->{'name'} eq $t ? "selected" : "",
				$text{"service_atype_$t"};
			}
		print "</select></td>\n";
		$ar =~ s/"/&quot;/g;
		print "<td><input name=aargs_${i}_${j} size=30 ",
		      "value='$ar'></td> </tr>\n";
		$j++;
		}
	print "</table></td> </tr>\n";

	local $ev = &find_value("alertevery", $p->{'members'});
	print "<tr> <td><b>$text{'service_every'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=every_def_$i value=1 %s> %s\n",
		$ev ? "" : "checked", $text{'service_every_def'};
	printf "<input type=radio name=every_def_$i value=0 %s> %s\n",
		$ev ? "checked" : "", $text{'service_every_time'};
	print &interval_input("every_$i", $ev),"</td>\n";

	local @aa = &find_value("alertafter", $p->{'members'});
	print "<tr> <td><b>$text{'service_after'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=after_def_$i value=1 %s> %s\n",
		@aa ? "" : "checked", $text{'service_immediate'};
	printf "<input type=radio name=after_def_$i value=0 %s>\n",
		@aa ? "checked" : "";
	print &text('service_after_num',
		    "<input name=after_$i size=6 value='$aa[0]'>"),"\n";
	print "&nbsp;" x 3;
	print $text{'service_aftertime'},"\n";
	print &interval_input("after_interval_$i", $aa[1]),"</td> </tr>\n";

	local $na = &find_value("numalerts", $p->{'members'});
	print "<tr> <td><b>$text{'service_num'}</b></td>\n";
	printf "<td><input type=radio name=num_def_$i value=1 %s> %s\n",
		$na ? "" : "checked", $text{'service_unlimited'};
	printf "<input type=radio name=num_def_$i value=0 %s>\n",
		$na ? "checked" : "";
	print "<input name=num_$i size=6 value='$na'></td> </tr>\n";

	$i++;
	}

if (!$in{'new'}) {
	print "<tr> <td colspan=4><hr></td> </tr>\n";
	print "<tr> <td colspan=4 align=right><a href='edit_service.cgi?",
	      "idx=$in{'idx'}&sidx=$in{'sidx'}&newperiod=1'>",
	      "$text{'service_newperiod'}</a></td> </tr>\n";
	}

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

&ui_print_footer("list_watches.cgi", $text{'watches_return'});


