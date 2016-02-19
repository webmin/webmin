# debian-lib.pl
# Functions for debian DPKG package management

sub list_package_system_commands
{
return ("dpkg");
}

# list_packages([package]*)
# Fills the array %packages with a list of all packages
sub list_packages
{
local $i = 0;
local $arg = @_ ? join(" ", map { quotemeta($_) } @_) : "";
%packages = ( );
&open_execute_command(PKGINFO, "COLUMNS=1024 dpkg --list $arg", 1, 1);
while(<PKGINFO>) {
	next if (/^\|/ || /^\+/);
	if (/^[uirph]i..(\S+)\s+(\S+)\s+(.*)/) {
		$packages{$i,'name'} = $1;
		$packages{$i,'class'} = &alphabet_name($1);
		$packages{$i,'version'} = $2;
		$packages{$i,'desc'} = $3;
		if ($packages{$i,'version'} =~ /^(\d+):(.*)$/) {
			$packages{$i,'epoch'} = $1;
			$packages{$i,'version'} = $2;
			}
		if ($packages{$i,'name'} =~ /^(\S+):(\S+)$/) {
			$packages{$i,'name'} = $1;
			$packages{$i,'arch'} = $2;
			}
		$i++;
		}
	}
close(PKGINFO);
return $i;
}

sub alphabet_name
{
return lc($_[0]) =~ /^[a-e]/ ? "A-E" :
       lc($_[0]) =~ /^[f-j]/ ? "F-J" :
       lc($_[0]) =~ /^[k-o]/ ? "K-O" :
       lc($_[0]) =~ /^[p-t]/ ? "P-T" :
       lc($_[0]) =~ /^[u-z]/ ? "U-Z" : "Other";
}

# package_info(package)
# Returns an array of package information in the order
#  name, class, description, arch, version, vendor, installtime
sub package_info
{
local $qm = quotemeta($_[0]);

# First check if it is really installed, and not just known to the package
# system in some way
local $out = &backquote_command("dpkg --list $qm 2>&1", 1);
local @lines = split(/\r?\n/, $out);
if ($lines[$#lines] !~ /^.[ih]/) {
	return ( );
	}

# Get full status
local $out;
if (&has_command("apt-cache")) {
	$out = &backquote_command("apt-cache show $qm 2>&1", 1);
	$out =~ s/[\0-\177]*\r?\n\r?\n(Package:)/\\1/;	# remove available ver
	}
else {
	$out = &backquote_command("dpkg --print-avail $qm 2>&1", 1);
	}
return () if ($? || $out =~ /Package .* is not available/i);
local @rv = ( $_[0], &alphabet_name($_[0]) );
push(@rv, $out =~ /Description:\s+([\0-\177]*\S)/i ? $1
						   : $text{'debian_unknown'});
push(@rv, $out =~ /Architecture:\s+(\S+)/i ? $1 : $text{'debian_unknown'});
push(@rv, $out =~ /Version:\s+(\S+)/i ? $1 : $text{'debian_unknown'});
push(@rv, $out =~ /Maintainer:\s+(.*)/i ? &html_escape($1)
					 : $text{'debian_unknown'});
push(@rv, $text{'debian_unknown'});
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
&open_execute_command(PKGINFO, "dpkg --listfiles $qm", 1, 1);
while($file = <PKGINFO>) {
	$file =~ s/\r|\n//g;
	next if ($file !~ /^\/[^\.]/);
	local @st = stat($file);
	$files{$i,'path'} = $file;
	$files{$i,'type'} = -l $file ? 3 :
			    -d $file ? 1 : 0;
	$files{$i,'user'} = getpwuid($st[4]);
	$files{$i,'group'} = getgrgid($st[5]);
	$files{$i,'mode'} = sprintf "%o", $st[2] & 07777;
	$files{$i,'size'} = $st[7];
	$files{$i,'link'} = readlink($file);
	$i++;
	}
return $i;
}

# package_files(package)
# Returns a list of all files in some package
sub package_files
{
local ($pkg) = @_;
local $qn = quotemeta($pkg);
local @rv;
&open_execute_command(RPM, "dpkg --listfiles $qn", 1, 1);
while(<RPM>) {
	s/\r|\n//g;
	push(@rv, $_);
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
local $qm = quotemeta($_[0]);
local $out = &backquote_command("dpkg --search $qm 2>&1", 1);
return 0 if ($out =~ /not\s+found|no\s+path\s+found/i);
$out =~ s/:\s+\S+\n$//;
local @pkgin = split(/[\s,]+/, $out);
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

# is_package(file)
sub is_package
{
local $qm = quotemeta($_[0]);
local $out = &backquote_command("dpkg --info $qm 2>&1", 1);
return $? || $out !~ /Package:/ ? 0 : 1;
}

# file_packages(file)
# Returns a list of all packages in the given file, in the form
#  package description
sub file_packages
{
local $qm = quotemeta($_[0]);
local $out = &backquote_command("dpkg --info $qm 2>&1", 1);
local $name;
if ($out =~ /Package:\s+(\S+)/i && ($name=$1) &&
    $out =~ /Description:\s+(.*)/i) {
	return ( "$name $1" );
	}
return ();
}

# install_options(file, package)
# Outputs HTML for choosing install options
sub install_options
{
print &ui_table_row($text{'debian_depends'},
	&ui_yesno_radio("depends", 0));

print &ui_table_row($text{'debian_conflicts'},
	&ui_yesno_radio("conflicts", 0));

print &ui_table_row($text{'debian_overwrite'},
	&ui_yesno_radio("overwrite", 0));

print &ui_table_row($text{'debian_downgrade'},
	&ui_yesno_radio("downgrade", 0));
}

# install_package(file, package)
# Installs the package in the given file, with options from %in
sub install_package
{
local $in = $_[2] ? $_[2] : \%in;
local $args = ($in->{'depends'} ? " --force-depends" : "").
	      ($in->{'conflicts'} ? " --force-conflicts" : "").
	      ($in->{'overwrite'} ? " --force-overwrite" : "").
	      ($in->{'downgrade'} ? " --force-downgrade" : "");
local $qm = quotemeta($_[0]);
$ENV{'DEBIAN_FRONTEND'} = 'noninteractive';
local $out = &backquote_logged("dpkg --install $args $qm 2>&1 </dev/null");
if ($?) {
	return "<pre>$out</pre>";
	}
return undef;
}

# delete_options(package)
# Outputs HTML for package uninstall options
sub delete_options
{
print "<b>$text{'delete_purge'}</b>\n";
print &ui_yesno_radio("purge", 0),"<br>\n";

if ($update_system eq "apt") {
	print "<b>$text{'delete_depstoo'}</b>\n";
	print &ui_yesno_radio("depstoo", 0),"<br>\n";
	}
}

# delete_package(package, [&options], version)
# Totally remove some package
sub delete_package
{
local $qm = quotemeta($_[0]);
$ENV{'DEBIAN_FRONTEND'} = 'noninteractive';
local $out;
if ($_[1]->{'depstoo'}) {
	# Use apt-get
	local $flag = $_[1]->{'purge'} ? "--purge" : "";
	$out = &backquote_logged("apt-get -y autoremove $flag $qm 2>&1 </dev/null");
	}
else {
	# Use dpkg command
	local $flag = $_[1]->{'purge'} ? "--purge" : "--remove";
	$out = &backquote_logged("dpkg $flag $qm 2>&1 </dev/null");
	}
if ($? || $out =~ /which isn.t installed/i) {
	return "<pre>$out</pre>";
	}
return undef;
}

sub package_system
{
return $text{'debian_manager'};
}

sub package_help
{
return "dpkg";
}

1;

