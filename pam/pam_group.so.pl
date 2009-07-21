# display args for pam_group.so

# display_args(&service, &module, &args)
sub display_module_args
{
local $file = "/etc/security/group.conf";
local @group;
open(FILE, $file);
while(<FILE>) {
	s/#.*$//;
	s/\r|\n//g;
	if (/^\s*([^;]*)\s*;\s*([^;]*)\s*;\s*([^;]*)\s*;\s*([^;]*)\s*;\s*([^;]*)\s*$/) {
		push(@group, [ $1, $2, $3, $4, $5 ]);
		}
	}
close(FILE);
local $gt;
$gt .= &ui_columns_start([ $text{'group_services'},
			   $text{'group_ttys'},
			   $text{'group_users'},
			   $text{'group_times'},
			   $text{'group_groups'} ]);
local $i = 0;
foreach $g (@group, [ ]) {
	$gt .= &ui_columns_row([
		&ui_textbox("services_$i", $g->[0], 20),
		&ui_textbox("ttys_$i", $g->[1], 20),
		&ui_textbox("users_$i", $g->[2], 20),
		&ui_textbox("times_$i", $g->[3], 20),
		&ui_textbox("groups_$i", $g->[4], 20),
		]);
	$i++;
	}
$gt .= &ui_columns_end();
$gt .= "<br>".$text{'group_info'};
print &ui_table_row(undef, $gt, 4);
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
local $file = "/etc/security/group.conf";
local (@lines, $i);
for($i=0; defined($in{"services_$i"}); $i++) {
	next if (!$in{"services_$i"});
	push(@lines, join(";", $in{"services_$i"}, $in{"ttys_$i"},
		     $in{"users_$i"}, $in{"times_$i"}, $in{"groups_$i"}),"\n");
	}
&lock_file($file);
&open_tempfile(FILE, ">$file");
&print_tempfile(FILE, @lines);
&close_tempfile(FILE);
&unlock_file($file);
}

