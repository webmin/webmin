# view-lib.pl
# Helpers for viewing files listed by the package manager.

# can_view_package_file(package, version, path)
# Returns 1 if path is a regular or editable file reported for the package.
sub can_view_package_file
{
my ($package, $version, $path) = @_;
return 0 if (!defined($package) || $package eq "" ||
	     !defined($path) || $path eq "");
return 0 if ($package =~ /[\\\/\0\r\n]/ || $package =~ /^\s*-/ ||
	     (defined($version) && $version =~ /[\0\r\n]/));

# Trust only the package manager's exact path and file type.
local %files;
my $count = &check_files($package, $version);
for(my $i = 0; $i < $count; $i++) {
	my $type = $files{$i,'type'};
	return 1 if (defined($files{$i,'path'}) &&
		     $files{$i,'path'} eq $path &&
		     defined($type) && ($type == 0 || $type == 5));
	}
return 0;
}

1;
