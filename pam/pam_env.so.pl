# display args for pam_env.so

# display_args(&service, &module, &args)
sub display_module_args
{
local $file = $_[2]->{'conffile'} ? $_[2]->{'conffile'}
				  : "/etc/security/pam_env.conf";
open(FILE, $file);
while(<FILE>) {
	s/#.*$//;
	s/\r|\n//g;
	if (/^\s*(\S+)/) {
		local $var = $1;
		local ($def, $over);
		if (/DEFAULT="([^"]+)"/i || /DEFAULT=(\S+)/i) {
			$def = $1;
			}
		if (/OVERRIDE="([^"]+)"/i || /OVERRIDE=(\S+)/i) {
			$over = $1;
			}
		push(@env, [ $var, $def, $over ]);
		}
	}
close(FILE);
local $et;
$et .= &ui_columns_start([ $text{'env_var'},
			  $text{'env_def'},
			  $text{'env_over'} ]);
local $i = 0;
foreach $e (@env, [ ]) {
	$et .= &ui_columns_row([
		&ui_textbox("var_$i", $e->[0], 20),
		&ui_textbox("def_$i", $e->[1], 30),
		&ui_textbox("over_$i", $e->[2], 30),
		]);
	$i++;
	}
$et .= &ui_columns_end();
print &ui_table_row(undef, $et, 4);
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
local $file = $_[2]->{'conffile'} ? $_[2]->{'conffile'}
				  : "/etc/security/pam_env.conf";
local ($i, @lines);
for($i=0; defined($in{"var_$i"}); $i++) {
	next if (!$in{"var_$i"});
	$in{"var_$i"} =~ /^\S+$/ || &error($text{'env_evar'});
	local $line = $in{"var_$i"};
	$line .= "\tDEFAULT=\"".$in{"def_$i"}."\"" if ($in{"def_$i"});
	$line .= "\tOVERRIDE=\"".$in{"over_$i"}."\"" if ($in{"over_$i"});
	push(@lines, $line,"\n");
	}
&lock_file($file);
&open_tempfile(FILE, ">$file");
&print_tempfile(FILE, @lines);
&close_tempfile(FILE);
&unlock_file($file);
}

