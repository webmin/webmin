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
local $tt = &ui_columns_start([ $text{'time_services'},
				$text{'time_ttys'},
				$text{'time_users'},
				$text{'time_times'} ]);
local $i = 0;
foreach $t (@time, [ ]) {
	$tt .= &ui_columns_row([
		&ui_textbox("services_$i", $t->[0], 25),
		&ui_textbox("ttys_$i", $t->[1], 25),
		&ui_textbox("users_$i", $t->[2], 25),
		&ui_textbox("times_$i", $t->[3], 25),
		]);
	$i++;
	}
$tt .= &ui_columns_end();
$tt .= "<br>".$text{'time_info'};
print &ui_table_row(undef, $tt, 4);
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

