# emerge-lib.pl
# Functions for gentoo package management

chop($system_arch = `uname -m`);
$pkg_dir = "/var/db/pkg";
$portage_bin = "/usr/lib/portage/bin";
$ENV{'TERM'} = "dumb";
$package_list_binary = $package_list_command = "$portage_bin/pkglist";
if (!-x $package_list_binary) {
	$package_list_binary = &has_command("qlist");
	$package_list_command = $package_list_binary." --nocolor -Iv";
	}

sub list_package_system_commands
{
return ( $package_list_binary || "pkglist" );
}

sub list_update_system_commands
{
return ("emerge");
}

# list_packages([package]*)
# Fills the array %packages with all or listed packages
sub list_packages
{
local $i = 0;
%packages = ( );
&open_execute_command(LIST, $package_list_command, 1, 1);
while(<LIST>) {
	if (/^([^\/]+)\/([^0-9]+)-(\d\S+)$/ &&
	    !@_ || &indexof($2, @_) >= 0) {
		$packages{$i,'name'} = $2;
		$packages{$i,'class'} = $1;
		$packages{$i,'version'} = $3;
		&open_readfile(BUILD, "$pkg_dir/$1/$2-$3/$2-$3.ebuild");
		while(<BUILD>) {
			if (/DESCRIPTION="([^"]+)"/ || /DESCRIPTION='([^']+)'/) {
				$packages{$i,'desc'} = $1;
				last;
				}
			}
		close(BUILD);
		$i++;
		}
	}
return $i;
}

# package_search(string, [allavailable])
# Searches the package database for packages matching some string and puts
# them into %packages
sub package_search
{
local $n = 0;
local $qm = quotemeta($_[0]);
&open_execute_command(SEARCH, "emerge search $qm", 1, 1);
while(<SEARCH>) {
	s/\r|\n//g;
	s/\033[^m]+m//g;
	if (/^\*\s+([^\/]+)\/(\S+)/) {
		$packages{$n,'name'} = $2;
		$packages{$n,'class'} = $1;
		$packages{$n,'missing'} = 0;
		}
	elsif (/version\s+Available:\s+(\S+)/i) {
		$packages{$n,'version'} = $1;
		}
	elsif (/version\s+Installed:\s+\[\s+Not/i && !$_[1]) {
		$packages{$n,'missing'} = 1;
		}
	elsif (/\s+Description:\s*(.*)/i) {
		$packages{$n,'desc'} = $1;
		local $nl = <SEARCH>;
		chop($nl);
		if ($nl =~ /\S/) {
			$packages{$n,'desc'} .= " " if ($packages{$n,'desc'});
			$packages{$n,'desc'} .= $nl;
			}
		$n++ if (!$packages{$n,'missing'} || $_[1]);
		}
	}
close(SEARCH);
return $n;
}

# package_info(package)
# Returns an array of package information in the order
#  name, class, description, arch, version, vendor, installtime
sub package_info
{
local %packages;
local $n = &list_packages($_[0]);
$n || return ();
local @st = stat("$pkg_dir/$packages{0,'class'}/$packages{0,'name'}-$packages{0,'version'}");
return ( $packages{0,'name'}, $packages{0,'class'}, $packages{0,'desc'},
	 $system_arch, $packages{0,'version'}, "Gentoo", &make_date($st[9]) );
}

# is_package(file)
# Check if some file is a package file
sub is_package
{
local $qm = quotemeta($_[0]);
local $out = &backquote_command("emerge --pretend $qm 2>&1", 1);
return $? ? 0 : 1;
}

# file_packages(file)
# Returns a list of all packages in the given file, in the form
#  package description
sub file_packages
{
local @rv;
local $qm = quotemeta($_[0]);
&open_execute_command(EMERGE, "emerge --pretend $qm", 1, 1);
while(<EMERGE>) {
	s/\r|\n//g;
	s/\033[^m]+m//g;
	if (/\s+[NRU]\s+\]\s+([^\/]+)\/([^0-9]+)\-(\d\S+)/) {
		push(@rv, $2);
		}
	}
close(EMERGE);
return @rv;
}

# install_options(file, package)
# Outputs HTML for choosing install options for some package
sub install_options
{
print &ui_table_row($text{'emerge_noreplace'},
	&ui_radio("noreplace", 0, [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

print &ui_table_row($text{'emerge_onlydeps'},
	&ui_yesno_radio("onlydeps", 0));
}

$show_install_progress = 1;

# install_package(file, package, [&inputs], [show])
# Install the given package from the given file, using options from %in
sub install_package
{
local $file = $_[0];
local $in = $_[2] ? $_[2] : \%in;
local $cmd = "emerge";
$cmd .= " --noreplace" if ($in{'noreplace'});
$cmd .= " --onlydeps" if ($in{'onlydeps'});
$cmd .= " ".quotemeta($_[1]);
if ($_[3]) {
	&open_execute_command(OUT, "$cmd 2>&1", 1);
	while(<OUT>) {
		print &html_escape($_);
		}
	close(OUT);
	return $? ? "Emerge error" : undef;
	}
else {
	local $out;
	&open_execute_command(OUT, "$cmd 2>&1 | tail -10", 1);
	while(<OUT>) {
		$out .= $_;
		}
	close(OUT);
	return $? ? "<pre>$out</pre>" : undef;
	}
}

# check_files(package)
# Fills in the %files array with information about the files belonging
# to some package. Values in %files are  path type user group size error
sub check_files
{
local $i = 0;
local (@files, %filesmap);
local %packages;
&list_packages($_[0]);
&open_readfile(CONTENTS, "$pkg_dir/$packages{0,'class'}/$packages{0,'name'}-$packages{0,'version'}/CONTENTS");
while(<CONTENTS>) {
	s/\r|\n//g;
	local @l = split(/\s+/);
	$files{$i,'path'} = $l[1];
	$files{$i,'type'} = $l[0] eq 'dir' ? 1 :
			    $l[0] eq 'sym' ? 3 : 0;
	local $real = &translate_filename($l[1]);
	local @st = stat($real);
	$files{$i,'user'} = getpwuid($st[4]);
	$files{$i,'group'} = getgrgid($st[5]);
	$files{$i,'size'} = $st[7];
	if (!-e $l[1]) {
		$files{$i,'error'} = "Does not exist";
		}
	elsif ($l[0] eq 'sym') {
		$files{$i,'link'} = $l[3];
		local $lnk = readlink($real);
		$files{$i,'error'} = "Incorrect link" if ($l[3] ne $lnk);
		}
	elsif ($l[0] eq 'obj') {
		push(@files, $l[1]);
		$filesmap{$l[1]} = $i;
		$files{$i,'md5'} = $l[2];
		}
	$i++;
	}
close(CONTENTS);
if (&has_command("md5sum")) {
	&open_execute_command(MD5, "md5sum ".join(" ", @files), 1, 1);
	while(<MD5>) {
		local ($md, $fn) = split(/\s+/);
		local $n = $filesmap{$fn};
		if ($md ne $files{$n,'md5'}) {
			$files{$n,'error'} = "Checksum failed";
			}
		}
	close(MD5);
	}
return $i;
}

# installed_file(file)
# Given a filename, fills %file with details of the given file and returns 1.
# If the file is not known to the package system, returns 0
# Usable values in %file are  path type user group mode size packages
sub installed_file
{
local ($cf, $type, @packs);
local $real_dir = &translate_filename($pkg_dir);
while($cf = <$real_dir/*/*/CONTENTS>) {
	open(FILE, $cf);
	while(<FILE>) {
		local @l = split(/\s+/);
		if ($l[1] eq $_[0]) {
			# Found it!
			$cf =~ /\/([^0-9\/]+)-(\d[^\s\/]+)\/CONTENTS$/;
			push(@packs, $1);
			$type = $l[0] if (!$type);
			}
		}
	close(FILE);
	}
return 0 if (!@packs);

local $real = &translate_filename($_[0]);
local @st = stat($real);
$file{'packages'} = join(' ', @packs);
$file{'path'} = $_[0];
$file{'user'} = getpwuid($st[4]);
$file{'group'} = getgrgid($st[5]);
$file{'mode'} = sprintf "%o", $st[2] & 07777;
$file{'size'} = $st[7];
$file{'link'} = readlink($real);
$file{'type'} = $type eq 'dir' ? 1 :
		$type eq 'sym' ? 3 : 0;
return 1;
}



# delete_package(package, [&options])
# Attempt to remove some package
sub delete_package
{
local $out = &backquote_logged("emerge -u ".quotemeta($_[0])." 2>&1");
return $? ? "<pre>$out</pre>" : undef;
}

sub package_system
{
return "Gentoo Ebuild";
}

sub package_help
{
return "emerge";
}

$has_update_system = 1;

# update_system_input()
# Returns HTML for entering a package to install
sub update_system_input
{
return "$text{'emerge_input'} <input name=update size=20> <input type=button onClick='window.ifield = form.update; chooser = window.open(\"../$module_name/emerge_find.cgi\", \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=600,height=500\")' value=\"$text{'emerge_find'}\">";
}

# update_system_install([package])
# Install some package with emerge
sub update_system_install
{
local $update = $_[0] || $in{'update'};
local $cmd = "emerge ".quotemeta($update);
local @rv;
print "<b>",&text('emerge_install', "<tt>$cmd</tt>"),"</b><p>\n";
print "<pre>\n";
&additional_log('exec', undef, $cmd);
&open_execute_command(CMD, "$cmd 2>&1 </dev/null", 1);
while(<CMD>) {
	print &html_escape($_);
	if (/^\>\>\>\s+([^\/]+)\/([^0-9]+)-(\d\S+)\s+merged\./i) {
		push(@rv, $2);
		}
	}
close(CMD);
print "</pre>\n";
if ($?) { print "<b>$text{'emerge_failed'}</b><p>\n"; }
else { print "<b>$text{'emerge_ok'}</b><p>\n"; }
return @rv;
}

1;

