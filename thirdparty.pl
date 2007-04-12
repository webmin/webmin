# thirdparty.pl
# Checks for modules available in an old install of webmin that are
# not included in this new install, and offers to copy them across.
# Also re-creates clones of existing modules in the new install

($newdir, $olddir, $copythird) = @ARGV;

# find missing modules
opendir(DIR, $olddir);
while($m = readdir(DIR)) {
	next if ($m =~ /^\./);
	if (-r "$olddir/$m/module.info" && !-r "$newdir/$m/module.info") {
		if (-l "$olddir/$m") {
			# Found a clone - recreate it
			$clone = readlink("$olddir/$m");
			symlink($clone, "$newdir/$m");
			}
		else {
			# Found a candidate for copying
			local %minfo;
			&read_file("$olddir/$m/module.info", \%minfo);
			push(@missing, $m);
			push(@missdesc, $minfo{'desc'});
			}
		}
	elsif (-r "$olddir/$m/theme.info" && !-r "$newdir/$m/theme.info") {
		# Found a theme for copying
		local %tinfo;
		&read_file("$olddir/$m/theme.info", \%tinfo);
		push(@missing, $m);
		push(@missdesc, $tinfo{'desc'});
		}
	}
closedir(DIR);

if (@missing) {
	# Tell the user, and ask whether to copy
	if (!$copythird) {
		print "The following third party modules were found in your old Webmin\n";
		print "installation in $olddir :\n";
		for($i=0; $i<@missing; $i++) {
			printf "  %-12.12s %s\n", $missing[$i], $missdesc[$i];
			}
		print "Copy to new Webmin installation (y/n): ";
		chop($resp = <STDIN>);
		$copythird = $resp =~ /^y/i;
		}
	if ($copythird) {
		foreach $m (@missing) {
			system("cp -rp $olddir/$m $newdir");
			}
		}
	}

# read_file(file, array)
# Fill an associative array with name=value pairs from a file
sub read_file
{
local($arr);
$arr = $_[1];
open(ARFILE, $_[0]) || return 0;
while(<ARFILE>) {
        chop;
        if (!/^#/ && /^([^=]+)=(.*)$/) { $$arr{$1} = $2; }
        }
close(ARFILE);
return 1;
}
 
