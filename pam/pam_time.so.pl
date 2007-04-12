# display args for pam_time.so

# display_args(&service, &module, &args)
sub display_module_args
{
local $file = "/etc/security/time.conf";
local @time;
open(FILE, $file);
while(<FILE>) {
	s/#.*$//;
	s/\r|\n//g;
	if (/^\s*([^;]*)\s*;\s*([^;]*)\s*;\s*([^;]*)\s*;\s*([^;]*)\s*$/) {
		push(@time, [ $1, $2, $3, $4 ]);
		}
	}
close(FILE);
print "<tr> <td colspan=4><table border width=100%>\n";
print "<tr $tb> <td><b>$text{'time_services'}</b></td> ",
      "<td><b>$text{'time_ttys'}</b></td> ",
      "<td><b>$text{'time_users'}</b></td> ",
      "<td><b>$text{'time_times'}</b></td> </tr>\n";
local $i = 0;
foreach $t (@time, [ ]) {
	print "<tr>\n";
	print "<td><input name=services_$i size=25 value='$t->[0]'></td>\n";
	print "<td><input name=ttys_$i size=25 value='$t->[1]'></td>\n";
	print "<td><input name=users_$i size=25 value='$t->[2]'></td>\n";
	print "<td><input name=times_$i size=25 value='$t->[3]'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table><br>$text{'time_info'}</td> </tr>\n";
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
local $file = "/etc/security/time.conf";
local (@lines, $i);
for($i=0; defined($in{"services_$i"}); $i++) {
	next if (!$in{"services_$i"});
	push(@lines, join(";", $in{"services_$i"}, $in{"ttys_$i"},
			       $in{"users_$i"}, $in{"times_$i"}),"\n");
	}
&lock_file($file);
&open_tempfile(FILE, ">$file");
&print_tempfile(FILE, @lines);
&close_tempfile(FILE);
&unlock_file($file);
}

