# bsd-lib.pl
# Functions for FreeBSD package management

use POSIX;
chop($system_arch = `uname -m`);

if (&use_pkg_ng()) {
	# check whether the new pkg manager is available and use that.
	$pkg_info    = "pkg info";
	$pkg_add     = "pkg add";
	$pkg_delete  = "pkg delete";
	}
else {
	# If not, default to the previous pkg manager tools
	$pkg_info    = "pkg_info";
	$pkg_add     = "pkg_add";
	$pkg_delete  = "pkg_delete";
	}

$package_dir = "/var/db/pkg";

sub use_pkg_ng
{
return 0 if (!-x "/usr/sbin/pkg");
local @lines = split(/\n/, &backquote_command(
			"/usr/sbin/pkg info 2>/dev/null </dev/null"));
return @lines > 1 ? 1 : 0;
}

sub list_package_system_commands
{
return ($pkg_info, $pkg_add);
}

# list_packages([package]*)
# Fills the array %packages with a list of all packages
sub list_packages
{
local $i = 0;
local $arg = @_ ? join(" ", map { quotemeta($_) } @_) : "-a";
%packages = ( );
&open_execute_command(PKGINFO, "$pkg_info -I $arg", 1, 1);
while(<PKGINFO>) {
	if (/^(\S+)\-(\d\S+)\s+(.*)/) {
		$packages{$i,'name'} = $1;
		$packages{$i,'version'} = $2;
		$packages{$i,'class'} = "";
		$packages{$i,'desc'} = $3;
		$i++;
		}
	}
close(PKGINFO);
return $i;
}

# package_info(package, [version])
# Returns an array of package information in the order
#  name, class, description, arch, version, vendor, installtime
sub package_info
{
local ($name, $ver) = @_;
local $qm = quotemeta($name.($ver ? '='.$ver : '>=0'));
local $out = &backquote_command("$pkg_info $qm 2>&1", 1);
return () if ($?);
local @rv = ( $name );
push(@rv, "");
push(@rv, $out =~ /Description:\n([\0-\177]*\S)/i ? $1 : $text{'bsd_unknown'});
push(@rv, $system_arch);
push(@rv, $out =~ /Information\s+for\s+(\S+)\-(\d\S+)/ ? $2 : $ver);
push(@rv, "FreeBSD");
local @st = stat(&translate_filename("$package_dir/$name-$ver"));
push(@rv, @st ? ctime($st[9]) : $text{'bsd_unknown'});
return @rv;
}

# check_files(package, version)
# Fills in the %files array with information about the files belonging
# to some package. Values in %files are  path type user group mode size error
sub check_files
{
local ($name, $ver) = @_;
local $i = 0;
local $file;
local $qm = quotemeta($name.($ver ? '='.$ver : '>=0'));
&open_execute_command(PKGINFO, "$pkg_info -L $qm", 1, 1);
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

# package_files(package, version)
# Returns a list of all files in some package
sub package_files
{
local ($pkg, $v) = @_;
local $qn = quotemeta($pkg.($v ? '='.$v : '>=0'));
local @rv;
&open_execute_command(RPM, "$pkg_info -L $qn", 1, 1);
while(<RPM>) {
	s/\r|\n//g;
	if (/^\//) {
		push(@rv, $_);
		}
	}
close(RPM);
return @rv;
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
	&open_execute_command(PKGINFO, "$pkg_info -L $packages{$i,'name'}", 1, 1);
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
local $real = &translate_filename($_[0]);
local $qm = quotemeta($_[0]);
if (-d $_[0]) {
	# A directory .. see if it contains any tgz files
	opendir(DIR, $real);
	local @list = grep { /\.tgz$/ || /\.tbz$/ } readdir(DIR);
	closedir(DIR);
	return @list ? 1 : 0;
	}
elsif ($_[0] =~ /\*|\?/) {
	# a wildcard .. see what it matches
	local @list = glob($real);
	return @list ? 1 : 0;
	}
else {
	# just a normal file - see if it is a package
	local $cmd;
	foreach $cmd ('gunzip', 'bunzip2') {
		next if (!&has_command($cmd));
		local ($desc, $contents);
		&open_execute_command(TAR, "$cmd -c $qm | tar tf -", 1, 1);
		while(<TAR>) {
			$desc++ if (/^\+DESC/);
			$contents++ if (/^\+CONTENTS/);
			}
		close(TAR);
		return 1 if ($desc && $contents);
		}
	return 0;
	}
}

# file_packages(file)
# Returns a list of all packages in the given file, in the form
#  package description
sub file_packages
{
local $real = &translate_filename($_[0]);
local $qm = quotemeta($_[0]);
if (-d $real) {
	# Scan directory for packages
	local ($f, @rv);
	opendir(DIR, $real);
	while($f = readdir(DIR)) {
		if ($f =~ /\.tgz$/i || $f =~ /\.tbz$/i) {
			local @pkg = &file_packages("$_[0]/$f");
			push(@rv, @pkg);
			}
		}
	closedir(DIR);
	return @rv;
	}
elsif ($real =~ /\*|\?/) {
	# Expand glob of packages
	# XXX won't work in translation
	local ($f, @rv);
	foreach $f (glob($real)) {
		local @pkg = &file_packages($f);
		push(@rv, @pkg);
		}
	return @rv;
	}
else {
	# Just one file
	local $cmd;
	foreach $cmd ('gunzip', 'bunzip2') {
		next if (!&has_command($cmd));
		local $temp = &transname();
		&make_dir($temp, 0700);
		local $rv = &execute_command("cd $temp && $cmd -c $qm | tar xf - +CONTENTS +COMMENT");
		if ($rv) {
			&unlink_file($temp);
			next;
			}
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
	return ( );
	}
}

# install_options(file, package)
# Outputs HTML for choosing install options
sub install_options
{
print &ui_table_row($text{'bsd_scripts'},
	&ui_radio("scripts", 0, [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

print &ui_table_row($text{'bsd_force'},
	&ui_yesno_radio("force", 0));
}

# install_package(file, package)
# Installs the package in the given file, with options from %in
sub install_package
{
local $in = $_[2] ? $_[2] : \%in;
local $args = ($in->{"scripts"} ? " -I" : "").
	      ($in->{"force"} ? " -f" : "");
local $out = &backquote_logged("$pkg_add $args $_[0] 2>&1");
if ($?) {
	return "<pre>$out</pre>";
	}
return undef;
}

# install_packages(file, [&inputs])
# Installs all the packages in the given file or glob
sub install_packages
{
local $in = $_[2] ? $_[2] : \%in;
local $args = ($in->{"scripts"} ? " -I" : "").
	      ($in->{"force"} ? " -f" : "");
local $file;
if (-d $_[0]) {
	$file = "$_[0]/*.tgz";
	}
else {
	$file = $_[0];
	}
local $out = &backquote_logged("$pkg_add $args $file 2>&1");
if ($?) {
	return "<pre>$out</pre>";
	}
return undef;
}

# delete_package(package, &in, version)
# Totally remove some package
sub delete_package
{
local ($name, $in, $ver) = @_;
local $qm = quotemeta($name.($ver ? '='.$ver : '>=0'));
local $out = &backquote_logged("$pkg_delete $qm 2>&1");
if ($? && $ver) {
	$qm = quotemeta($name.'-'.$ver);
	$out = &backquote_logged("$pkg_delete $qm 2>&1");
	}
if ($?) { return "<pre>$out</pre>"; }
return undef;
}

# delete_packages(&packages, &in, &versions)
# Totally remove some list of packages
sub delete_packages
{
local ($names, $in, $vers) = @_;
local @qm;
for(my $i=0; $i<@$names; $i++) {
	local $qm = quotemeta($names[$i].($vers[$i] ? '='.$vers[$i] : '>=0'));
	push(@qm, $qm);
	}
local $out = &backquote_logged("$pkg_delete ".join(" ", @qm)." 2>&1");
if ($?) { return "<pre>$out</pre>"; }
return undef;
}

sub package_system
{
return &text('bsd_manager', "FreeBSD");
}

sub package_help
{
return "$pkg_add $pkg_info $pkg_delete";
}

1;
