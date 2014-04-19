# rpm-lib.pl
# Functions for redhat linux package management

sub list_package_system_commands
{
return ("rpm");
}

# list_packages([package]*)
# Fills the array %packages with all or listed packages
sub list_packages
{
local($i, $list); $i = 0;
$list = @_ ? join(' ', map { quotemeta($_) } @_) : "-a";
%packages = ( );
&open_execute_command(RPM, "rpm -q $list --queryformat \"%{NAME}\\n%{VERSION}-%{RELEASE}\\n%{EPOCH}\\n%{GROUP}\\n%{ARCH}\\n%{SUMMARY}\\n\\n\"", 1, 1);
while($packages{$i,'name'} = <RPM>) {
	chop($packages{$i,'name'});
	chop($packages{$i,'version'} = <RPM>);
	chop($packages{$i,'epoch'} = <RPM>);
	$packages{$i,'epoch'} = undef if ($packages{$i,'epoch'} eq '(none)');
	chop($packages{$i,'class'} = <RPM>);
	chop($packages{$i,'arch'} = <RPM>);
	while(<RPM>) {
		s/\r|\n/ /g;
		last if (!/\S/);
		$packages{$i,'desc'} .= $_;
		}
	if ($packages{$i,'name'} eq 'gpg-pubkey') {
		# Bogus pseudo-package we don't want to include
		$packages{$i,'desc'} = undef;
		$i--;
		}
	$i++;
	}
close(RPM);
return 0 if ($?);	# couldn't find the package
return $i;
}

# package_info(package, [version])
# Returns an array of package information in the order
#  name, class, description, arch, version, vendor, installtime
sub package_info
{
local(@rv, @tmp, $d);
local $n = $_[1] ? "$_[0]-$_[1]" : $_[0];
&open_execute_command(RPM, "rpm -q $n --queryformat \"%{NAME}\\n%{GROUP}\\n%{ARCH}\\n%{VERSION}-%{RELEASE}\\n%{VENDOR}\\n%{INSTALLTIME}\\n\" 2>/dev/null", 1, 1);
@tmp = <RPM>;
chop(@tmp);
local $ex = close(RPM);
if (!@tmp || $tmp[0] =~ /not\s+installed/) { return (); }
&open_execute_command(RPM, "rpm -q $n --queryformat \"%{DESCRIPTION}\"", 1, 1);
while(<RPM>) { $d .= $_; }
close(RPM);
return ($tmp[0], $tmp[1], $d, $tmp[2], $tmp[3], $tmp[4], &make_date($tmp[5]));
}

# is_package(file)
# Check if some file is a package file
sub is_package
{
local($out);
local $real = &translate_filename($_[0]);
if (-d $real) {
	# a directory .. see if it contains any .rpm files
	opendir(DIR, $real);
	local @list = grep { /\.rpm$/ } readdir(DIR);
	closedir(DIR);
	return @list ? 1 : 0;
	}
elsif ($real =~ /\*|\?/) {
	# a wildcard .. see what it matches
	local @list = glob($real);
	return @list ? 1 : 0;
	}
else {
	# just a normal file .. check if it is an RPM and not an SRPM
	local $qm = quotemeta($_[0]);
	$out = &backquote_command("rpm -q -p $qm 2>&1", 1);
	if ($out =~ /does not appear|No such file|with major numbers|not an rpm/i || $?) {
		return 0;
		}
	&open_execute_command(OUT, "rpm -q -p -l $qm 2>&1", 1, 1);
	while(<OUT>) {
		return 0 if (/^([^\/\s]+)\.spec$/);
		}
	close(OUT);
	return 1;
	}
}

# file_packages(file)
# Returns a list of all packages in the given file, in the form
#  package-version description
sub file_packages
{
local $real = &translate_filename($_[0]);
local $qm = quotemeta($_[0]);
if (-d $real) {
	local @rv;
	&open_execute_command(RPM, "cd $qm ; rpm -q -p *.rpm --queryformat \"%{NAME} %{SUMMARY}\\n\" 2>&1", 1, 1);
	while(<RPM>) {
		chop;
		push(@rv, $_) if (!/does not appear|query of.*failed|warning:/);
		}
	close(RPM);
	return @rv;
	}
elsif ($_[0] =~ /\*|\?/) {
	local @rv;
	&open_execute_command(RPM, "rpm -q -p $_[0] --queryformat \"%{NAME} %{SUMMARY}\\n\" 2>&1", 1);
	while(<RPM>) {
		chop;
		push(@rv, $_) if (!/does not appear|query of.*failed|warning:/);
		}
	close(RPM);
	return @rv;
	}
else {
	local($out);
	$out = &backquote_command("rpm -q -p $qm --queryformat \"%{NAME} %{SUMMARY}\\n\" 2>&1", 1);
	$out =~ s/warning:.*\n//;
	$out =~ s/\n//g;
	return ($out);
	}
}

# install_options(file, package)
# Outputs HTML for choosing install options for some package
sub install_options
{
print &yesno_input($text{'rpm_upgrade'}, "upgrade", 1, 0, 1);
print &yesno_input($text{'rpm_replacepkgs'}, "replacepkgs", 1, 0);

print &yesno_input($text{'rpm_nodeps'}, "nodeps", 1, 0);
print &yesno_input($text{'rpm_oldpackage'}, "oldpackage", 1, 0);

print &yesno_input($text{'rpm_noscripts'}, "noscripts", 0, 1);
print &yesno_input($text{'rpm_excludedocs'}, "excludedocs", 0, 1);

print &yesno_input($text{'rpm_notriggers'}, "notriggers", 0, 1);
print &yesno_input($text{'rpm_ignoresize'}, "ignoresize", 0, 1);

print &yesno_input($text{'rpm_replacefiles'}, "replacefiles", 1, 0);
print &ui_table_row(&hlink($text{'rpm_root'}, "root"),
		&ui_textbox("root", "/", 50)." ".
		&file_chooser_button("root", 1), 3);
}

sub yesno_input
{
return &ui_table_row(&hlink($_[0], $_[1]),
		     &ui_radio($_[1], int($_[4]),
			       [ [ $_[2], $text{'yes'} ],
				 [ $_[3], $text{'no'} ] ]));
}

# install_package(file, package, [&inputs])
# Install the given package from the given file, using options from %in
sub install_package
{
local $file = $_[0];
local $real = &translate_filename($file);
local $in = $_[2] ? $_[2] : \%in;
local $opts;
foreach $o ('oldpackage', 'replacefiles', 'replacepkgs', 'noscripts',
	    'excludedocs', 'nodeps', 'upgrade', 'notriggers', 'ignoresize') {
	if ($in->{$o}) { $opts .= " --$o"; }
	}
if ($in->{'root'} =~ /^\/.+/) {
	if (!(-d $in{'root'})) {
		return &text('rpm_eroot', $in->{'root'});
		}
	$opts .= " --root $in->{'root'}";
	}
if (-d $real) {
	# Find the package in the directory
	local ($f, $out);
	opendir(DIR, $real);
	while($f = readdir(DIR)) {
		next if ($f !~ /\.rpm$/);
		$out = &backquote_command("rpm -q -p $file/$f --queryformat \"%{NAME}\\n\" 2>&1", 1);
		$out =~ s/warning:.*\n//;
		$out =~ s/\n//;
		if ($out eq $_[1]) {
			$file = "$file/$f";
			last;
			}
		}
	closedir(DIR);
	&error(&text('rpm_erpm', $_[1], $out)) if ($file eq $_[0]);
	}
elsif ($file =~ /\*|\?/) {
	# Find the package in the glob
	# XXX won't work when translation is in effect
	local ($f, $out);
	foreach $f (glob($real)) {
		$out = &backquote_command("rpm -q -p $f --queryformat \"%{NAME}\\n\" 2>&1", 1);
		$out =~ s/warning:.*\n//;
		$out =~ s/\n//;
		if ($out eq $_[1]) {
			$file = $f;
			last;
			}
		}
	&error(&text('rpm_erpm', $_[1], $out)) if ($file eq $_[0]);
	}
local $temp = &transname();
local $rv = &system_logged("rpm -i $opts ".quotemeta($file)." >$temp 2>&1");
local $out = &backquote_command("cat $temp");
$out =~ s/warning:.*\n//;
&unlink_file($temp);
if ($rv) {
	return "<pre>$out</pre>";
	}
return undef;
}

# install_packages(file, [&inputs])
# Installs all the packages in the given file or glob
sub install_packages
{
local $file = $_[0];
local $in = $_[1] ? $_[1] : \%in;
local $opts;
foreach $o ('oldpackage', 'replacefiles', 'replacepkgs', 'noscripts',
	    'excludedocs', 'nodeps', 'upgrade', 'notriggers', 'ignoresize') {
	if ($in->{$o}) { $opts .= " --$o"; }
	}
if ($in->{'root'} =~ /^\/.+/) {
	if (!(-d $in{'root'})) {
		return &text('rpm_eroot', $in->{'root'});
		}
	$opts .= " --root $in->{'root'}";
	}
if (-d &translate_filename($file)) {
	# Install everything in a directory
	$file = "$file/*.rpm";
	}
else {
	# Install packages matching a glob (no need for any special action)
	}
local $temp = &transname();
local $rv = &system_logged("rpm -i $opts $file >$temp 2>&1");
local $out = &backquote_command("cat $temp");
$out =~ s/warning:.*\n//;
unlink($temp);
if ($rv) {
	return "<pre>$out</pre>";
	}
return undef;
}

# check_files(package, version)
# Fills in the %files array with information about the files belonging
# to some package. Values in %files are  path type user group size error
sub check_files
{
local($i, $_, @w, %errs, $epath); $i = 0;
local $n = $_[1] ? "$_[0]-$_[1]" : $_[0];
local $qn = quotemeta($n);
&open_execute_command(RPM, "rpm -V $qn", 1, 1);
while(<RPM>) {
	/^(.{8}) (.) (.*)$/;
	if ($1 eq "missing ") {
		$errs{$3} = $text{'rpm_missing'};
		}
	else {
		$epath = $3;
		@w = grep { $_ ne "." } split(//, $1);
		$errs{$epath} =
			join("\n", map { &text('rpm_checkfail', $etype{$_}) } @w);
		}
	}
close(RPM);
&open_execute_command(RPM, "rpm -q $qn -l --dump", 1, 1);
while(<RPM>) {
	chop;
	@w = split(/ /);
	$files{$i,'path'} = $w[0];
	if ($w[10] ne "X") { $files{$i,'link'} = $w[10]; }
	$files{$i,'type'} = $w[10] ne "X" ? 3 :
			    (-d &translate_filename($w[0])) ? 1 :
			    $w[7] ? 5 : 0;
	$files{$i,'user'} = $w[5];
	$files{$i,'group'} = $w[6];
	$files{$i,'size'} = $w[1];
	$files{$i,'error'} = $w[7] ? "" : $errs{$w[0]};
	$i++;
	}
close(RPM);
return $i;
}

# package_files(package, [version])
# Returns a list of all files in some package
sub package_files
{
local ($pkg, $version) = @_;
local $qn = quotemeta($version ? "$pkg-$version" : $pkg);
local @rv;
&open_execute_command(RPM, "rpm -q -l $qn", 1, 1);
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
local($pkg, @w, $_, @pkgs, @vers);
undef(%file);
local $qm = quotemeta($_[0]);
$pkg = &backquote_command("rpm -q -f $qm --queryformat \"%{NAME}\\n\" 2>&1", 1);
if ($pkg =~ /not owned/ || $?) { return 0; }
@pkgs = split(/\n/, $pkg);
$pkg = &backquote_command("rpm -q -f $qm --queryformat \"%{VERSION}-%{RELEASE}\\n\" 2>&1", 1);
@vers = split(/\n/, $pkg);
&open_execute_command(RPM, "rpm -q $pkgs[0] -l --dump", 1, 1);
while(<RPM>) {
	chop;
	@w = split(/ /);
	if ($w[0] eq $_[0]) {
		$file{'packages'} = join(' ', @pkgs);
		$file{'versions'} = join(' ', @vers);
		$file{'path'} = $w[0];
		if ($w[10] ne "X") { $files{$i,'link'} = $w[10]; }
		$file{'type'} = $w[10] ne "X" ? 3 :
				(-d &translate_filename($w[0])) ? 1 :
				$w[7] ? 5 : 0;
		$file{'user'} = $w[5];
		$file{'group'} = $w[6];
		$file{'mode'} = substr($w[4], -4);
		$file{'size'} = $w[1];
		last;
		}
	}
close(RPM);
return 1;
}

# delete_options(package)
# Outputs HTML for package uninstall options
sub delete_options
{
print "<b>$text{'delete_nodeps'}</b>\n";
print &ui_yesno_radio("nodeps", 0),"<br>\n";

print "<b>$text{'delete_noscripts'}</b>\n";
print &ui_yesno_radio("noscripts", 0),"<br>\n";
}

# delete_package(package, [&options], version)
# Attempt to remove some package
sub delete_package
{
local $opts;
$opts .= $_[1]->{'nodeps'} ? "--nodeps " : "";
$opts .= $_[1]->{'noscripts'} ? "--noscripts " : "";
local $n = $_[2] ? "$_[0]-$_[2]" : $_[0];
local $qm = quotemeta($n);
local $out = &backquote_logged("rpm -e $opts $qm 2>&1");
if ($? || $out =~ /error:/) { return "<pre>$out</pre>"; }
return undef;
}

# delete_packages(&packages, [&options], &versions)
# Attempt to remove multiple packages at once
sub delete_packages
{
local $opts;
$opts .= $_[1]->{'nodeps'} ? "--nodeps " : "";
$opts .= $_[1]->{'noscripts'} ? "--noscripts " : "";
local $cmd = "rpm -e $opts";
local $i;
for($i=0; $i<@{$_[0]}; $i++) {
	if ($_[2]->[$i]) {
		$cmd .= " ".quotemeta($_[0]->[$i]."-".$_[2]->[$i]);
		}
	else {
		$cmd .= " ".quotemeta($_[0]->[$i]);
		}
	}
local $out = &backquote_logged("$cmd 2>&1");
if ($? || $out =~ /error:/) { return "<pre>$out</pre>"; }
return undef;
}

sub package_system
{
return "RPM";
}

sub package_help
{
return "rpm";
}

%etype = (	"5", $text{'rpm_md5'},	"S", $text{'rpm_fsize'},
		"L", $text{'rpm_sym'},	"T", $text{'rpm_mtime'},
		"D", $text{'rpm_dev'},	"U", $text{'rpm_user'},
		"M", $text{'rpm_perm'},	"G", $text{'rpm_group'} );

$has_search_system = 1;

sub search_system_input
{
print "<input type=button onClick='window.ifield = document.forms[2].url; chooser = window.open(\"rpmfind.cgi\", \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=800,height=500\")' value=\"$text{'rpm_find'}\">";
}

1;

