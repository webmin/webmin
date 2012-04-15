# slackware-lib.pl
# Functions for slackware package management

$package_dir = "/var/log/packages";
%class_map = (  'a', 'Base Slackware system',
		'ap', 'Linux applications',
		'd', 'Program development',
		'e', 'GNU Emacs',
		'extra', 'Extra Slackware packages',
		'f', 'FAQs, howtos, and documentation',
		'gnome', 'GNOME desktop and programs',
		'k', 'Linux kernel source',
		'kde', 'KDE desktop and programs',
		'kdei', 'Language support of KDE',
		'l', 'Libraries',
		'n', 'Networking',
		'pasture', 'Software put to pasture',
		't', 'TeX',
		'testing', 'Software in testing',
		'tcl', 'TcL/Tk',
		'x', 'X Windows',
		'xap', 'X applications',
		'y', 'Classic BSD console games' );
use POSIX;
chop($system_arch = `uname -m`);

sub validate_package_system
{
return -d &translate_filename($package_dir) ? undef :
	&text('slack_edir', "<tt>$package_dir</tt>");
}

# list_packages([package]*)
# Fills the array %packages with a list of all packages
sub list_packages
{
local ($i, $f, @list);
%packages = ( );
opendir(DIR, &translate_filename($package_dir));
local @list = @_ ? @_ : grep { !/^\./ } readdir(DIR);
$i = 0;
foreach $f (@list) {
	$packages{$i,'name'} = $f;
	$packages{$i,'class'} = $text{'slack_unclass'};
	&open_tempfile(PKG, "$package_dir/$f");
	while(<PKG>) {
		if (/^PACKAGE LOCATION:\s+disk([a-z]+)\d+/i ||
		    /^PACKAGE LOCATION:\s+\S+\/([a-z]+)\/[^\/]+$/i) {
			$packages{$i,'class'} = $class_map{$1} ||
						$text{'slack_unclass'};
			}
		elsif (/^PACKAGE DESCRIPTION:/i) {
			local $desc = <PKG>;
			$desc =~ s/^\S+:\s+//;
			$desc =~ s/\n//;
			$packages{$i,'desc'} = $desc;
			}
		}
	close(PKG);
	$i++;
	}
closedir(DIR);
return $i;
}

# package_info(package)
# Returns an array of package information in the order
#  name, class, description, arch, version, vendor, installtime
sub package_info
{
local @rv = ( $_[0], $text{'slack_unclass'}, $text{'slack_unknown'},
	      $system_arch, $text{'slack_unknown'}, "Slackware" );
local @st = stat(&translate_filename("$package_dir/$_[0]"));
$rv[6] = ctime($st[9]);
&open_readfile(PKG, "$package_dir/$_[0]");
while(<PKG>) {
	if (/^PACKAGE LOCATION:\s+disk([a-z]+)\d+/i) {
		$rv[1] = $class_map{$1};
		}
	elsif (/^PACKAGE DESCRIPTION:/i) {
		$rv[2] = "";
		while(<PKG>) {
			last if (/^FILE LIST/i);
			s/^\S+: *//;
			if (!$rv[2] && /([0-9][0-9\.]*)/) {
				$rv[4] = $1;
				}
			$rv[2] .= $_;
			}
		$rv[2] =~ s/\s+$//;
		}
	}
close(PKG);
return @rv;
}

# check_files(package)
# Fills in the %files array with information about the files belonging
# to some package. Values in %files are  path type user group mode size error
sub check_files
{
local $i = 0;
local $file;
&open_readfile(PKG, "$package_dir/$_[0]");
while(<PKG>) {
	last if (/^FILE LIST:/i);
	}
while($file = <PKG>) {
	$file =~ s/\r|\n//g;
	next if ($file eq "./");
	$file = '/'.$file;
	local $real = &translate_filename($file);
	$files{$i,'path'} = $file;
	local @st = stat($real);
	if (@st) {
		$files{$i,'type'} = -l $real ? 3 :
				    -d $real ? 1 : 0;
		$files{$i,'user'} = getpwuid($st[4]);
		$files{$i,'group'} = getgrgid($st[5]);
		$files{$i,'mode'} = sprintf "%o", $st[2] & 07777;
		$files{$i,'size'} = $st[7];
		$files{$i,'link'} = readlink($file);
		}
	else {
		$files{$i,'type'} = $file =~ /\// ? 1 : 0;
		$files{$i,'user'} = $files{$i,'group'} =
		 $files{$i,'mode'} = $files{$i,'size'} = $text{'slack_unknown'};
		$files{$i,'error'} = $text{'slack_missing'};
		}
	$i++;
	}
return $i;
}

# package_files(package)
# Returns a list of all files in some package
sub package_files
{
local ($pkg) = @_;
local @rv;
&open_readfile(PKG, "$package_dir/$_[0]");
while(<PKG>) {
	last if (/^FILE LIST:/i);
	}
while(my $file = <PKG>) {
	$file =~ s/\r|\n//g;
	next if ($file eq "./");
	$file = '/'.$file;
	push(@rv, $file);
	}
close(PKG);
return @rv;
}

# installed_file(file)
# Given a filename, fills %file with details of the given file and returns 1.
# If the file is not known to the package system, returns 0
# Usable values in %file are  path type user group mode size packages
sub installed_file
{
local ($f, $file, @pkgin);
opendir(DIR, &translate_filename($package_dir));
while($f = readdir(DIR)) {
	next if ($f =~ /^\./);
	&open_readfile(PKG, "$package_dir/$f");
	while(<PKG>) {
		last if (/^FILE LIST:/);
		}
	while($file = <PKG>) {
		next if ($file eq "./");
		$file =~ s/[\/\r\n]+$//;
		$file = '/'.$file;
		if ($_[0] eq $file) {
			# found it!
			push(@pkgin, $f);
			last;
			}
		}
	close(PKG);
	}
closedir(DIR);
if (@pkgin) {
	local $real = &translate_filename($_[0]);
	local @st = stat($real);
	$file{'path'} = $_[0];
	$file{'type'} = -l $real ? 3 :
			-d $real ? 1 : 0;
	$file{'user'} = getpwuid($st[4]);
	$file{'group'} = getgrgid($st[5]);
	$file{'mode'} = sprintf "%o", $st[2] & 07777;
	$file{'size'} = $st[7];
	$file{'link'} = readlink($real);
	$file{'packages'} = join(" ", @pkgin);
	return 1;
	}
else {
	return 0;
	}
}

# is_package(file)
sub is_package
{
local $count;
local $qm = quotemeta($_[0]);
if ($_[0] =~ /\.txz$/) {
	&open_execute_command(TAR, "tar tf $qm 2>&1", 1, 1);
	}
else {
	&open_execute_command(TAR, "gunzip -c $qm | tar tf - 2>&1", 1, 1);
	}
while(<TAR>) {
	$count++ if (/^[^\/\s]\S+/);
	}
close(TAR);
return $count < 2 ? 0 : 1;
}

# file_packages(file)
# Returns a list of all packages in the given file, in the form
#  package description
sub file_packages
{
if ($_[0] !~ /^(.*)\/(([^\/]+)(\.tgz|\.txz|\.tar\.gz))$/) {
	return "$_[0] $text{'slack_unknown'}";
	}
local ($dir, $file, $base) = ($1, $2, $3);
local $diskfile;
opendir(DIR, &translate_filename($dir));
while($f = readdir(DIR)) {
	if ($f =~ /^disk\S+\d+$/ || $f eq 'package_descriptions') {
		# found the slackware disk file
		$diskfile = "$dir/$f";
		last;
		}
	}
closedir(DIR);
return "$base $text{'slack_unknown'}" if (!$diskfile);

# read the disk file
local $desc;
&open_readfile(DISK, $diskfile);
while(<DISK>) {
	if (/^$base:\s*(.*)/) {
		$desc = $1;
		last;
		}
	}
close(DISK);
return $desc ? "$base $desc" : "$base $text{'slack_unknown'}";
}

# install_options(file, package)
# Outputs HTML for choosing install options
sub install_options
{
print &ui_table_row($text{'slack_root'},
	&ui_textbox("root", "/", 50)." ".
	&file_chooser_button("root", 1), 3);
}

# install_package(file, package)
# Installs the package in the given file, with options from %in
sub install_package
{
local $in = $_[2] ? $_[2] : \%in;
return $text{'slack_eroot'} if (!-d $in->{'root'});
$ENV{'ROOT'} = $in->{'root'};
local $out;
local $qm = quotemeta($_[0]);
if (&has_command("upgradepkg") &&
    -r &translate_filename("$package_dir/$_[1]")) {
	# Try to upgrade properly
	$out = &backquote_logged("upgradepkg $qm 2>&1");
	}
else {
	# Just install
	$out = &backquote_logged("installpkg $qm 2>&1");
	}
if ($?) {
	return "<pre>$out</pre>";
	}
return undef;
}

# delete_package(package)
# Totally remove some package
sub delete_package
{
local $qm = quotemeta($_[0]);
local $out = &backquote_logged("removepkg $qm 2>&1");
if ($?) { return "<pre>$out</pre>"; }
return undef;
}

sub package_system
{
return $text{'slack_manager'};
}

sub package_help
{
return "installpkg removepkg";
}

1;

