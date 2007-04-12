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
print "<tr> <td colspan=4><table width=100% border>\n";
print "<tr $tb> <td><b>$text{'env_var'}</b></td> ",
      "<td><b>$text{'env_def'}</b></td> ",
      "<td><b>$text{'env_over'}</b></td> </tr>\n";
local $i = 0;
foreach $e (@env, [ ]) {
	print "<tr> <td><input name=var_$i size=20 value='$e->[0]'></td>\n";
	print "<td><input name=def_$i size=30 value='$e->[1]'></td>\n";
	print "<td><input name=over_$i size=30 value='$e->[2]'></td> </tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";
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

