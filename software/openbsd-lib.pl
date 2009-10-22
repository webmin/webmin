# openbsd-lib.pl
# Functions for OpenBSD package management

use POSIX;
chop($system_arch = `uname -m`);
$package_dir = "/var/db/pkg";

sub list_package_system_commands
{
return ("pkg_info", "pkg_add");
}

# list_packages([package]*)
# Fills the array %packages with a list of all packages
sub list_packages
{
local $i = 0;
local $arg = @_ ? join(" ", map { quotemeta($_) } @_) : "-a";
%packages = ( );
&open_execute_command(PKGINFO, "pkg_info -I $arg", 1, 1);
while(<PKGINFO>) {
	if (/^(\S+)\s+(.*)/) {
		$packages{$i,'name'} = $1;
		$packages{$i,'class'} = "";
		$packages{$i,'desc'} = $2;
		$i++;
		}
	}
close(PKGINFO);
return $i;
}

# package_info(package)
# Returns an array of package information in the order
#  name, class, description, arch, version, vendor, installtime
sub package_info
{
local $qm = quotemeta($_[0]);
local $out = &backquote_command("pkg_info $_[0] 2>&1", 1);
return () if ($?);
local @rv = ( $_[0] );
push(@rv, "");
push(@rv, $out =~ /Description:\n([\0-\177]*\S)/i ? $1 : $text{'bsd_unknown'});
push(@rv, $system_arch);
push(@rv, $_[0] =~ /-([^\-]+)$/ ? $1 : $text{'bsd_unknown'});
push(@rv, "OpenBSD");
local @st = stat(&translate_filename("$package_dir/$_[0]"));
push(@rv, @st ? ctime($st[9]) : $text{'bsd_unknown'});
return @rv;
}

# check_files(package)
# Fills in the %files array with information about the files belonging
# to some package. Values in %files are  path type user group mode size error
sub check_files
{
local $i = 0;
local $file;
local $qm = quotemeta($_[0]);
&open_execute_command(PKGINFO, "pkg_info -L $qm", 1, 1);
while($file = <PKGINFO>) {
	$file =~ s/\r|\n//g;
	next if ($file !~ /^\//);
	local $real = &translate_filename($file);
	local @st = stat($real);
	$files{$i,'path'} = $file;
	$files{$i,'type'} = -l $real ? 3 :
			    -d $real ? 1 : 0;
	$files{$i,'user'} = getpwuid($st[4]);
	$files{$i,'group'} = getgrgid($st[5]);
	$files{$i,'mode'} = sprintf "%o", $st[2] & 07777;
	$files{$i,'size'} = $st[7];
	$files{$i,'link'} = readlink($real);
	$i++;
	}
return $i;
}

# installed_file(file)
# Given a filename, fills %file with details of the given file and returns 1.
# If the file is not known to the package system, returns 0
# Usable values in %file are  path type user group mode size packages
sub installed_file
{
local (%packages, $file, $i, @pkgin);
local $n = &list_packages();
for($i=0; $i<$n; $i++) {
	&open_execute_command(PKGINFO, "pkg_info -L $packages{$i,'name'}", 1,1);
	while($file = <PKGINFO>) {
		$file =~ s/\r|\n//g;
		if ($file eq $_[0]) {
			# found it
			push(@pkgin, $packages{$i,'name'});
			}
		}
	close(PKGINFO);
	}
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
local ($desc, $contents);
local $qm = quotemeta($_[0]);
&open_execute_command(TAR, "gunzip -c $qm | tar tf -", 1, 1);
while(<TAR>) {
	$desc++ if (/^\+DESC/);
	$contents++ if (/^\+CONTENTS/);
	}
close(TAR);
return $desc && $contents;
}

# file_packages(file)
# Returns a list of all packages in the given file, in the form
#  package description
sub file_packages
{
local $temp = &transname();
&make_dir($temp, 0700);
local $qm = quotemeta($_[0]);
&execute_command("cd $temp && gunzip -c $qm | tar xf - +CONTENTS +COMMENT");
local ($comment, $name);
&open_readfile(COMMENT, "$temp/+COMMENT");
($comment = <COMMENT>) =~ s/\r|\n//g;
close(COMMENT);
&open_readfile(CONTENTS, "$temp/+CONTENTS");
while(<CONTENTS>) {
	$name = $1 if (/^\@name\s+(\S+)/);
	}
close(CONTENTS);
&unlink_file($temp);
return ( "$name $comment" );
}

# install_options(file, package)
# Outputs HTML for choosing install options
sub install_options
{
print &ui_table_row($text{'bsd_scripts'},
	&ui_radio("scripts", 0, [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

print &ui_table_row($text{'bsd_force'},
	&ui_yesno_radio("force", 1));
}

# install_package(file, package)
# Installs the package in the given file, with options from %in
sub install_package
{
local $in = $_[2] ? $_[2] : \%in;
local $args = ($in->{"scripts"} ? " -I" : "").
	      ($in->{"force"} ? " -f" : "");
local $out = &backquote_logged("pkg_add $args $_[0] 2>&1");
if ($?) {
	return "<pre>$out</pre>";
	}
return undef;
}

# delete_package(package)
# Totally remove some package
sub delete_package
{
local $out = &backquote_logged("pkg_delete $_[0] 2>&1");
if ($?) { return "<pre>$out</pre>"; }
return undef;
}

sub package_system
{
return &text('bsd_manager', "OpenBSD");
}

sub package_help
{
return "pkg_add pkg_info pkg_delete";
}

1;
