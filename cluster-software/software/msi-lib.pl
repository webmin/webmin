# msi-lib.pl
# Functions for Windows package management
# 
# XXX fix up all tempname references
# XXX some installs fail for no reason? No gui?
# XXX test more packages

$msi_package_logdir = "$module_config_directory/msis";

# list_packages([package]*)
# Fills the array %packages with all or listed packages
sub list_packages
{
local @pkgs = @_;
@pkgs = &list_msi_packages() if (!@pkgs);
local $i = 0;
foreach my $p (@pkgs) {
	local $msi = &get_msi_package($p);
	$packages{$i,'name'} = $msi->{'name'};
	$packages{$i,'version'} = $msi->{'version'};
	$packages{$i,'desc'} = $msi->{'desc'};
	$i++;
	}
return $i;
}

# list_msi_packages()
# Returns the names of installed MSI packages (using Webmin)
sub list_msi_packages
{
opendir(DIR, $msi_package_logdir);
local @rv = grep { $_ ne "." && $_ ne ".." } readdir(DIR);
closedir(DIR);
return @rv;
}

# get_msi_package(name)
# Returns a hash containing details of an MSI package
sub get_msi_package
{
local ($pkg) = @_;
local %msi;
&read_file("$msi_package_logdir/".lc($pkg), \%msi);
$msi{'name'} = $pkg;
return \%msi;
}

# save_msi_package(&package)
# Updates the local details of an MSI package
sub save_msi_package
{
local ($msi) = @_;
&make_dir($msi_package_logdir, 0700);
&write_file("$msi_package_logdir/".lc($msi->{'name'}), $msi);
}

# delete_msi_package(name)
# Removes the local details of an MSI package
sub delete_msi_package
{
local ($name) = @_;
unlink("$msi_package_logdir/".lc($name));
}

# package_info(package, [version])
# Returns an array of package information in the order
#  name, class, description, arch, version, vendor, installtime
sub package_info
{
local ($name, $ver) = @_;
local $msi = &get_msi_package($name);
return ( $msi->{'name'}, $msi->{'class'}, $msi->{'desc'}, $msi->{'arch'},
	 $msi->{'version'}, $msi->{'vendor'}, &make_date($msi->{'installed'}) );
}

# is_package(file)
# Check if some file is a package file
sub is_package
{
local ($file) = @_;
return $file =~ /\.msi$/i ? 1 : 0;
}

# file_packages(file)
# Returns a list of all packages in the given file, in the form
#  package-version description
# XXX how to get proper description?
sub file_packages
{
local ($file) = @_;
if ($file =~ /([^\/\\]+)\.msi$/i) {
	local $suffix = $1;
	$suffix =~ s/_.*$//;	# For files named like apache_2.x.y...
	return $suffix;
	}
return ( );
}

# install_options(file, package)
# Outputs HTML for choosing install options for some package
sub install_options
{
local ($file, $pkg) = @_;

print "<tr>\n";
print "<td><b>$text{'msi_users'}</b></td>\n";
print "<td>",&ui_radio("users", 2, [ [ 0, $text{'msi_users0'} ],
				     [ 1, $text{'msi_users1'} ],
				     [ 2, $text{'msi_users2'} ] ]),"</td>\n";
print "</tr>\n";
}

# install_package(file, package, [&inputs])
# Install the given package from the given file, using options from %in. Returns
# undef on success or an error message on failure.
sub install_package
{
local ($file, $pkg, $in) = @_;

# Run the msiexec command
local $temp = &tempname();
$file =~ s/\//\\/g;
$temp =~ s/\//\\/g;
system("msiexec /i ".&quote_path($file)." /quiet /norestart ".
       "/l*vx ".&quote_path($temp));
&wait_till_stopped_logging($temp);

# Read output from log file
local $ok;
local %msi = ( 'name' => $pkg,
	       'arch' => 'x86',			# Wrong!
	       'installed' => time() );
local $fc = 0;
open(OUT, $temp);
while(<OUT>) {
	s/\r|\n//g;
	s/\0//g;		# Strip unicode, primitively
	if (/Product:\s*(.*)\s\-\-.*success/i) {
		$ok = 1;
		}
	elsif (/ProductVersion\s*=\s*(.*)/) {
		$msi{'version'} = $1;
		}
	elsif (/ProductName\s*=\s*(.*)/) {
		$msi{'desc'} = $1;
		}
	elsif (/ProductCode\s*=\s*(.*)/) {
		$msi{'code'} = $1;
		}
	elsif (/Manufacturer\s*=\s*(.*)/) {
		$msi{'vendor'} = $1;
		}
	elsif (/Note:\s+\d+:\s+\d+\s+\d+:\s+([a-z]:\S+)/) {
		$msi{'files_'.$fc} = $1;
		local @st = stat($1);
		$msi{'sizes_'.$fc} = $st[7];
		$fc++;
		}
	}
close(OUT);
if (!$ok) {
	return "MSI install failed!";
	}
&save_msi_package(\%msi);

# Make available to users, if requested
if ($in->{'users'}) {
	local $flag = $in->{'users'} == 1 ? "u" : "m";
	system("msiexec /j$flag ".&quote_path($file)." /quiet /norestart");
	}

return undef;
}

# check_files(package, version)
# Fills in the %files array with information about the files belonging
# to some package. Values in %files are  path type user group size error
sub check_files
{
local ($name, $ver) = @_;
local $msi = &get_msi_package($name);
local $i;
for($i=0; defined($msi->{'files_'.$i}); $i++) {
	$files{$i,'path'} = $msi->{'files_'.$i};
	local @st = stat($files{$i,'path'});
	$files{$i,'type'} = -d $files{$i,'path'} ? 1 : 0;
	$files{$i,'size'} = $msi->{'sizes_'.$i};
	if (!@st) {
		$files{$i,'error'} = $text{'msi_missing'};
		}
	elsif ($files{$i,'size'} ne $st[7]) {
		$files{$i,'error'} = $text{'msi_size'};
		}
	}
return $i;
}

# delete_options(package)
# Outputs HTML for package uninstall options
sub delete_options
{
local ($name) = @_;
# None!
}

# delete_package(package, [&options], version)
# Attempt to remove some package
sub delete_package
{
local ($name, $opts, $ver) = @_;

# Call the uninstall command
local $msi = &get_msi_package($name);
local $temp = &tempname();
$temp =~ s/\//\\/g;
system("msiexec /x \"$msi->{'code'}\" /quiet /norestart ".
       "/l*vx ".&quote_path($temp));
&wait_till_stopped_logging($temp);

# Check log for success
local $ok = 0;
open(LOG, $temp);
while(<LOG>) {
	s/\r|\n//g;
	s/\0//g;		# Strip unicode, primitively
	if (/Product:\s*(.*)\s\-\-.*success/i) {
		$ok = 1;
		}
	}
close(LOG);
if (!$ok) {
	return "MSI uninstall failed";
	}

# Remove from local info
&delete_msi_package($name);

return undef;
}

sub package_system
{
return "MSI";
}

sub package_help
{
return "msi";
}

# wait_till_stopped_logging(file)
# Spin until some file has remained untouched for 5 seconds
sub wait_till_stopped_logging
{
local ($file) = @_;
while(1) {
	local @before = stat($file);
	sleep(5);
	local @after = stat($file);
	last if ($before[9] == $after[9]);
	}
}

1;

