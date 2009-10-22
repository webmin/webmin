# pkgadd-lib.pl
# Functions for solaris package management

&foreign_require("proc", "proc-lib.pl");

sub list_package_system_commands
{
return ("pkginfo", "pkgadd", "pkgrm");
}

# list_packages([package]*)
# Fills the array %packages with a list of all packages
sub list_packages
{
local $i = 0;
local $list = join(' ', map { quotemeta($_) } @_);
local $_;
local %indexmap;
%packages = ( );
&open_execute_command(PKGINFO, "pkginfo -x $list", 1, 1);
while(<PKGINFO>) {
	if (/^(\S+)\s*(.*)/) {
		# Package name and description
		$packages{$i,'name'} = $1;
		$packages{$i,'desc'} = $2;
		$indexmap{$1} = $i;
                $i++;
		}
	elsif (/^\s+\((\S+)\)\s*(\S+)/) {
		# Arch and version
		$packages{($i-1),'arch'} = $1;
		$packages{($i-1),'version'} = $2;
		$packages{($i-1),'shortversion'} = $2;
		$packages{($i-1),'shortversion'} =~ s/,REV=.*//;
		}
	}
close(PKGINFO);

# Call pkginfo to get classes
&open_execute_command(PKGINFO, "pkginfo $list", 1, 1);
while(<PKGINFO>) {
	last if (/The following software/i);
	if (/^(\S+)\s+(\S+)\s+(.*)$/) {
		local $idx = $indexmap{$2};
		if (defined($idx)) {
			$packages{$idx,'class'} = $1;
			}
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
local($out, @rv);
local $qm = quotemeta($_[0]);
$out = &backquote_command("pkginfo -l $qm 2>&1", 1);
if ($out =~ /^ERROR:/) { return (); }
push(@rv, $_[0]);
push(@rv, $out =~ /CATEGORY:\s+(.*)\n/ ? $1 : "");
push(@rv, $out =~ /DESC:\s+(.*)\n/ ? $1 :
	  $out =~ /NAME:\s+(.*)\n/ ? $1 : $_[0]);
push(@rv, $out =~ /ARCH:\s+(.*)\n/ ? $1 : $text{'pkgadd_unknown'});
push(@rv, $out =~ /VERSION:\s+(.*)\n/ ? $1 : $text{'pkgadd_unknown'});
push(@rv, $out =~ /VENDOR:\s+(.*)\n/ ? $1 : $text{'pkgadd_unknown'});
push(@rv, $out =~ /INSTDATE:\s+(.*)\n/ ? $1 : $text{'pkgadd_unknown'});
return @rv;
}

# is_package(file)
# Tests if some file is a valid package file
sub is_package
{
local $real = &translate_filename($_[0]);
local $qm = quotemeta($_[0]);
if (-d $real && !-r "$real/pkginfo") {
	# A directory .. see if it contains any package files
	local $rv = 0;
	opendir(DIR, $real);
	foreach $f (readdir(DIR)) {
		next if ($f eq "." || $f eq "..");
		if (&is_package("$_[0]/$f")) {
			$rv = 1;
			last;
			}
		}
	closedir(DIR);
	return $rv;
	}
elsif ($real =~ /\*|\?/) {
	# a wildcard .. see what it matches
	# XXX won't work under translation
	local $f;
	foreach $f (glob($real)) {
		if (&is_package($f)) {
			$rv = 1;
			last;
			}
		}
	return $rv;
	}
else {
	# just a normal file - see if it is a package
	local $out = &backquote_command("pkginfo -d $qm 2>/dev/null");
	return !$? && $out !~ /ERROR/;
	}
}

# file_packages(file)
# Returns a list of all packages in the given file, directory or glob, as an
# array of strings in the form
#  package description
sub file_packages
{
local $real = &translate_filename($_[0]);
local $qm = quotemeta($_[0]);
if (-d $real && !-r "$real/pkgproto") {
	# Scan directory for packages
	local ($f, @rv);
	opendir(DIR, $real);
	while($f = readdir(DIR)) {
		if (&is_package("$_[0]/$f")) {
			local @pkg = &file_packages("$_[0]/$f");
			push(@rv, @pkg);
			}
		}
	closedir(DIR);
	return @rv;
	}
elsif ($real =~ /\*|\?/) {
	# Expand glob of packages
	# XXX won't work under translation
	local ($f, @rv);
	foreach $f (glob($real)) {
		local @pkg = &file_packages($f);
		push(@rv, @pkg);
		}
	return @rv;
	}
else {
	# Just one package file
	local @rv;
	&open_execute_command(OUT, "pkginfo -d $qm", 1, 1);
	while(<OUT>) {
		if (/^(\S+)\s+(\S+)\s+(\S.*)/) {
			push(@rv, "$2 $3");
			}
		}
	close(OUT);
	return @rv;
	}
}

# install_options(file, package)
# Outputs HTML for choosing install options
sub install_options
{
print &ui_table_row(&hlink($text{'pkgadd_root'}, "root"),
	&ui_textbox("root", "/", 50)." ".
	&file_chooser_button("root", 1), 3);
}

# install_package(file, package)
# Installs the package in the given file, with options from %in
sub install_package
{
local(@opts, %seen, $wf, $rv, $old_input);
local $real = &translate_filename($_[0]);
local $qm = quotemeta($_[0]);
local $in = $_[2] ? $_[2] : \%in;
local $has_postinstall = 0; #detect if contains postinstall script

if ($in->{'root'} =~ /^\/.+/) {
	if (!(-d $in->{'root'})) { &error(&text('pkgadd_eroot', $in->{'root'})); }
	push(@opts, "-R", $in->{'root'});
	}
if ($in->{'adminfile'} ne '') {
	push(@opts, "-a", $in->{'adminfile'});
	}
if (-d $real && !-r "$real/pkgproto") {
	# Install one package from a file in this directory
	local $f;
	opendir(DIR, $real);
	while($f = readdir(DIR)) {
		if (&is_package("$_[0]/$f")) {
			local @pkg = &file_packages("$_[0]/$f");
			foreach $pkg (@pkg) {
				local ($name, $desc) = split(/\s+/, $pkg);
				if ($name eq $_[1]) {
					return &install_package("$_[0]/$f", $name);
					}
				}
			}
		}
	closedir(DIR);
	return "Failed to find package $_[1]";
	}
elsif ($real =~ /\?|\*/) {
	# Install one package from a file that matches a glob
	local $f;
	foreach $f (glob($real)) {
		if (&is_package($f)) {
			local @pkg = &file_packages($f);
			foreach $pkg (@pkg) {
				local ($name, $desc) = split(/\s+/, $pkg);
				if ($name eq $_[1]) {
					return &install_package($f, $name);
					}
				}
			}
		}
	return "Failed to find package $_[1]";
	}
else {
	# Install just one package
	local ($ph, $ppid) = &foreign_call("proc", "pty_process_exec_logged",
			   "pkgadd -d $_[0] ".join(" ",@opts)." $_[1]");

	while(1) {
		$wf = &wait_for($ph, '(.*) \[\S+\]',
			     '(This package contains scripts|Executing checkinstall script)',
			     'Installation of .* failed',
			     'Installation of .* was successful',
			     'No changes were made to the system',
			     '\n\/.*\n');
		if ($wf == 0) {
			# some question which should not have appeared before
			if ($seen{$matches[1]}++ > 3) {
				$rv = "<pre>$old_input$wait_for_input</pre>";
				last;
				}
			&sysprint($ph, "y\n");
			}
		elsif ($wf == 1) {
			# This package contains scripts requiring output to
			# be sent to /dev/null.  Abort & redo.
			$rv = undef;
			$has_postinstall = 1;
			&sysprint($ph, "n\n");
			#let the next elsif catch that 'no changes were made'
			#to complete the pkgadd execution.
			}
		elsif ($wf == 2 || $wf == 4 || $wf == -1) {
			# failed for some reason.. give up
			$rv = "<pre>$old_input$wait_for_input</pre>";
			last;
			}
		elsif ($wf == 3) {
			# done ok!
			$rv = undef;
			last;
			}
		$old_input = $wait_for_input;
		}
	close($ph);

	if ($has_postinstall) {
		# Handle case where pkg has scripts that cause pkgadd to open
		# /dev/tty
		my $ret = system_logged("pkgadd -n -a pkgadd-no-ask -d $_[0] ".
					join(" ",@opts).
					" $_[1] 2>&1 > /dev/null")/256;
		#only exit values of 1 & 3 are errors (see pkgadd(1M))
		$rv = ($ret == 1 || $ret == 3)? "pkgadd returned $ret" : undef;
		}

	return $rv;
	}
}


# check_files(package)
# Fills in the %files array with information about the files belonging
# to some package. Values in %files are  path type user group mode size error
sub check_files
{
local($i, %errs, $curr, $line, %file);
undef(%files);
local $qm = quotemeta($_[0]);
$chk = &backquote_command("pkgchk -n $qm 2>&1", 1);
while($chk =~ /^(\S+): (\S+)\n((\s+.*\n)+)([\0-\177]*)$/) {
	if ($1 eq "ERROR") { $errs{$2} = $3; }
	$chk = $5;
	}

&open_execute_command(CHK, "pkgchk -l $qm 2>&1", 1, 1);
FILES: for($i=0; 1; $i++) {
	# read one package
	$curr = "";
	while(1) {
		if (!($line = <CHK>)) { last FILES; }
		if ($line =~ /Current status/) { $line = <CHK>; last; }
		$curr .= $line;
		}

	# extract information
	&parse_pkgchk($curr);
	foreach $k (keys %file) { $files{$i,$k} = $file{$k}; }
	$files{$i,'error'} = $errs{$files{$i,'path'}};
	}
close(CHK);
return $i;
}

# installed_file(file)
# Given a filename, fills %file with details of the given file and returns 1.
# If the file is not known to the package system, returns 0
# Usable values in %file are  path type user group mode size packages
sub installed_file
{
local $temp = &transname();
&open_tempfile(TEMP, ">$temp", 0, 1, 1);
print TEMP "$_[0]\n";
close(TEMP);

$out = &backquote_command("pkgchk -l -i $temp 2>&1", 1);
&unlink_file($temp);
if ($out =~ /\S/) {
	&parse_pkgchk($out);
	return 1;
	}
else { return 0; }
}

# delete_package(package)
# Totally remove some package
sub delete_package
{
local($ph, $pth, $ppid, $wf, %seen, $old_input);
local ($ph, $ppid) = &foreign_call("proc", "pty_process_exec_logged",
				   "pkgrm $_[0]");
if (&wait_for($ph, 'remove this package', 'ERROR')) {
	return "package does not exist";
	}
&sysprint($ph, "y\n");
while(1) {
	$wf = &wait_for($ph, '(.*) \[\S+\]',
			     'Removal of \S+ failed',
			     'Removal of \S+ was successful',
			     '\n\/.*\n');
	if ($wf == 0) {
		# some question which should not have appeared before
		if ($seen{$matches[1]}++) {
			$rv = "<pre>$old_input$wait_for_input</pre>";
			last;
			}
		&sysprint($ph, "y\n");
		}
	elsif ($wf == 1) {
		# failed for some reason.. give up
		$rv = "<pre>$old_input$wait_for_input</pre>";
		last;
		}
	elsif ($wf == 2) {
		# done ok!
		$rv = undef;
		last;
		}
	$old_input = $wait_for_input;
	}
close($ph);
return $rv;
}

# parse_pkgchk(output)
# Parse output about one file from pkgchk into the array %file
sub parse_pkgchk
{
undef(%file);
if ($_[0] =~ /Pathname:\s+(.*)/) { $file{'path'} = $1; }
if ($_[0] =~ /Type:\s+(.*)/) {
	$file{'type'} = $1 eq "regular file" ? 0 :
			$1 eq "directory" ? 1 :
			$1 eq "special file" ? 2 :
			$1 eq "symbolic link" ? 3 :
			$1 eq "linked file" ? 4 :
			$1 eq "volatile file" ? 5 :
			$1 eq "editted file" ? 5 :
			$1 eq "edited file" ? 5 :
			-1;
	}
if ($_[0] =~ /Source of link:\s+(\S+)/) { $file{'link'} = $1; }
if ($_[0] =~ /Expected owner:\s+(\S+)/) { $file{'user'} = $1; }
if ($_[0] =~ /Expected group:\s+(\S+)/) { $file{'group'} = $1; }
if ($_[0] =~ /Expected mode:\s+(\S+)/) { $file{'mode'} = $1; }
if ($_[0] =~ /size \(bytes\):\s+(\d+)/) { $file{'size'} = $1; }
if ($_[0] =~ /following packages:\n(((\s+.*\n)|\n)+)/)
	{ $file{'packages'} = join(' ', grep { $_ ne '' } split(/\s+/, $1)); }
}


sub package_system
{
return $text{'pkgadd_manager'};
}

sub package_help
{
return "pkgadd pkginfo pkgchk pkgrm";
}

1;

