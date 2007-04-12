#!/usr/local/bin/perl
# list_periods.cgi
# Display a list of all defined periods

require './mon-lib.pl';
&ui_print_header(undef, $text{'periods_title'}, "");

$conf = &get_mon_config();
@periods = &find("period", $conf);

print "<form action=save_periods.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'periods_period'}</b></td> ",
      "<td><b>$text{'periods_times'}</b></td> </tr>\n";
$i = 0;
foreach $p (@periods, { }) {
	local ($name, $value, $dfrom, $dto, $hfrom, $hto, $known);
	if ($p->{'value'} =~ /^\s*(\S+):\s*wd\s+{(\S+)-(\S+)}\s+hr\s+{(\S+)-(\S+)}\s*$/){
		$name = $1;
		$dfrom = $2; $dto = $3; $hfrom = $4; $hto = $5;
		$known++;
		}
	elsif ($p->{'value'} =~ /^\s*(\S+):\s*wd\s+{(\S+)-(\S+)}\s*$/) {
		$name = $1;
		$dfrom = $2; $dto = $3;
		$known++;
		}
	elsif ($p->{'value'} =~ /^\s*(\S+):\s*hr\s+{(\S+)-(\S+)}\s*$/) {
		$name = $1;
		$hfrom = $2; $hto = $3;
		$known++;
		}
	elsif ($p->{'value'} =~ /^\s*(\S+):\s*(.*)$/) {
		$name = $1;
		$value = $2;
		}
	elsif (!$p->{'value'}) {
		$known++;
		}
	print "<tr $cb>\n";
	print "<td><input name=name_$i size=20 value='$name'></td>\n";
	print "<td>\n";
	if ($known || !$p->{'name'}) {
		# Show friendly period inputs
		printf "<input type=radio name=days_def_$i value=1 %s> %s\n",
			$dfrom ? "" : "checked", $text{'periods_alldays'};
		printf "<input type=radio name=days_def_$i value=0 %s>\n",
			$dfrom ? "checked" : "";
		print &day_input("dfrom_$i", $dfrom)," - ",
		      &day_input("dto_$i", $dto);

		print "&nbsp;&nbsp;&nbsp;\n";

		printf "<input type=radio name=hours_def_$i value=1 %s> %s\n",
			$hfrom ? "" : "checked", $text{'periods_allhours'};
		printf "<input type=radio name=hours_def_$i value=0 %s>\n",
			$hfrom ? "checked" : "";
		print "<input name=hfrom_$i size=4 value='$hfrom'> - ",
		      "<input name=hto_$i size=4 value='$hto'></td> </tr>\n";
		}
	else {
		# Allow any Time::Period string
		print "<input name=value_$i size=50 value='$value'>\n";
		}
	print "</td> </tr>\n";
	$i++;
	}
print "</table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

