# cygwin-lib.pl
# Functions for cygwin + redhat package management

use vars '$hasrpm'; $hasrpm = (-f "/usr/bin/rpm.exe");
use vars '$db'; $db = "/etc/setup/installed.db";

sub validate_package_system
{
return -r $db ? undef : &text('cygwin_edb', "<tt>$db</tt>");
}

# list_packages([package]*)
# Fills the array %packages with all or listed packages
sub list_packages
{
my (@pkgs) = @_;
my $allpkgs = (@_ == 0);
local($i, $list); $i = 0;
%packages = ( );
if (&open_tempfile(DB, $db)) {
    while (<DB>) {
	#suppress packages that begin with an underscore
	if (/^([^_][^\s]*)\s+([^\s]+)\s+(\d+)/) {
	    #TODO: classes, descriptions
	    my ($name, $ver, $class, $desc) = ($1, $2, "cygwin", "");
	    my $qmname = quotemeta($name);
	    next if ! $allpkgs && ! grep(/^$qmname$/, @pkgs);
	    $ver =~ s/.*?[_\-](\d.*)\.tar\..*/$1/;
	    $packages{$i, 'name'} = $name;
	    $packages{$i, 'class'} = $class;
	    $packages{$i, 'version'} = $ver;
	    $packages{$i, 'desc'} = $desc;
	    $i++;
	    @pkgs = grep { $_ ne $name } @pkgs if ! $allpkgs;
	}
	last if (! $allpkgs && @pkgs == 0);
    }
    close(DB);
    @_ = @pkgs;
}
return $i if ! $hasrpm || (! $allpkgs && @pkgs == 0);

$list = @_ ? join(' ', map { quotemeta($_) } @_) : "-a";
&open_execute_command(RPM, "rpm -q $list --queryformat \"%{NAME}\\n%{VERSION}-%{RELEASE}\\n%{GROUP}\\n%{SUMMARY}\\n\\n\"", 1, 1);
while($packages{$i,'name'} = <RPM>) {
	chop($packages{$i,'name'});
	chop($packages{$i,'version'} = <RPM>);
	chop($packages{$i,'class'} = <RPM>);
	while(<RPM>) {
		s/\r|\n/ /g;
		last if (!/\S/);
		$packages{$i,'desc'} .= $_;
		}
	$i++;
	}
close(RPM);
return $i;
}

# package_info(package, version)
# Returns an array of package information in the order
#  name, class, description, arch, version, vendor, installtime
sub package_info
{
my @cygdata = cygwin_pkg_info(@_);
return @cygdata if @cygdata > 0;
return undef if ! $hasrpm;

local(@rv, @tmp, $d);
local $n = $_[1] ? "$_[0]-$_[1]" : $_[0];
local $qm = quotemeta($n);
&open_execute_command(RPM, "rpm -q $qm --queryformat \"%{NAME}\\n%{GROUP}\\n%{ARCH}\\n%{VERSION}-%{RELEASE}\\n%{VENDOR}\\n%{INSTALLTIME}\\n\" 2>/dev/null", 1, 1);
@tmp = <RPM>;
chop(@tmp);
if (!@tmp) { return (); }
close(RPM);
&open_execute_command(RPM, "rpm -q $qm --queryformat \"%{DESCRIPTION}\"", 1, 1);
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
if (-d $_[0]) {
	# a directory .. see if it contains any .rpm or .tar.bz2 files
	opendir(DIR, $real);
	local @list = grep { /([^\s]+[_\-](\d[^\s]*|src)-\d[^\s]*\.tar\.bz2|\.rpm)$/} readdir(DIR);
	closedir(DIR);
	return @list ? 1 : 0;
	}
elsif ($_[0] =~ /\*|\?/) {
	# a wildcard .. see what it matches
	local @list = glob($real);
	return @list ? 1 : 0;
	}
else {
	# just a normal file ..check if it is an RPM and not an SRPM or tar.bz2
	return 1 if $_[0] =~ /[^\s]+[_\-](\d[^\s]*|src)-\d[^\s]*\.tar\.bz2$/;
	local $qm = quotemeta($_[0]);
	$out = &backquote_command("rpm -q -p $qm 2>&1", 1);
	if ($out =~ /does not appear|No such file|with major numbers/i) {
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
	opendir(DIR, $real);
	@rv = grep { s/.*\/([^\s]+)[_\-]((\d[^\s]*|src)-\d[^\s]*)\.tar\.bz2$/$1/ } readdir(DIR);
	closedir(DIR);
	&open_execute_command(RPM, "cd $qm && rpm -q -p *.rpm --queryformat \"%{NAME} %{SUMMARY}\\n\" 2>&1", 1, 1);
	while(<RPM>) {
		chop;
		push(@rv, $_) if (!/does not appear|query of.*failed|warning:/);
		}
	close(RPM);
	return @rv;
	}
elsif ($_[0] =~ /\*|\?/) {
	local @rv;
	my @p = &backquote_command("ls $_[0]");
	@rv = grep { s/.*\/([^\s]+)[_\-]((\d[^\s]*|src)-\d[^\s]*)\.tar\.bz2$/$1/ } @p;
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
	$out = $_[0];
	return $out
	    if $out =~ s/.*\/([^\s]+)[_\-]((\d[^\s]*|src)-\d[^\s]*)\.tar\.bz2$/$1/;
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
    my ($file, $pkg) = @_;
    if ($file =~ /\/[^\s]+[_\-]src[_\-]\d[^\s]*\.tar\.bz2$/) {
	# No options
    } elsif ($file =~ /\/[^\s]+[_\-]\d[^\s]*-\d[^\s]*\.tar\.bz2$/) {
	print &ui_table_row(undef, "<b>$text{'cygwin_warnuse'}</b>", 4);

	print &yesno_input($text{'rpm_upgrade'}, "upgrade", 1, 0, 1);
	print &yesno_input($text{'rpm_replacepkgs'}, "replacepkgs", 1, 0);

	print &yesno_input($text{'rpm_noscripts'}, "noscripts", 0, 1);
    } else {
	print &yesno_input($text{'rpm_upgrade'}, "upgrade", 1, 0, 1);
	print &yesno_input($text{'rpm_replacepkgs'}, "replacepkgs", 1, 0);

	print &yesno_input($text{'rpm_nodeps'}, "nodeps", 1, 0);
	print &yesno_input($text{'rpm_oldpackage'}, "oldpackage", 1, 0);

	print &yesno_input($text{'rpm_noscripts'}, "noscripts", 0, 1);
	print &yesno_input($text{'rpm_excludedocs'}, "excludedocs", 0, 1);

	print &yesno_input($text{'rpm_notriggers'}, "notriggers", 0, 1);
	print &yesno_input($text{'rpm_ignoresize'}, "ignoresize", 0, 1);

	print &yesno_input($text{'rpm_replacefiles'}, "replacefiles", 1, 0);
    }
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
	    if ($f =~ /\/([^\s]+[_\-]src[_\-]\d[^\s]*)\.tar\.bz2$/) {
		$out = $1;
	    } elsif ($f =~ /^([^\s]+[_\-]\d[^\s]*-\d[^\s]*)\.tar\.bz2$/) {
		$out = $1;
	    } else {
		next if ($f !~ /\.rpm$/);
		$out = &backquote_command("rpm -q -p $file/$f --queryformat \"%{NAME}\\n\" 2>&1");
		$out =~ s/warning:.*\n//;
		$out =~ s/\n//;
	    }
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
	    if ($f =~ /\/([^\s]+[_\-]src[_\-]\d[^\s]*)\.tar\.bz2$/) {
		$out = $1;
	    } elsif ($f =~ /\/([^\s]+[_\-]\d[^\s]*-\d[^\s]*)\.tar\.bz2$/) {
		$out = $1;
	    } else {
		$out = &backquote_command("rpm -q -p $f --queryformat \"%{NAME}\\n\" 2>&1", 1);
		$out =~ s/warning:.*\n//;
		$out =~ s/\n//;
	    }
		if ($out eq $_[1]) {
			$file = $f;
			last;
			}
		}
	&error(&text('rpm_erpm', $_[1], $out)) if ($file eq $_[0]);
	}
local $temp = &transname();
local $rv;
if ($file =~ /\/[^\s]+[_\-]src[_\-]\d[^\s]*\.tar\.bz2$/) {
    $rv = install_cygwin_src_pkg($file, $temp, $in->{'root'});
} elsif ($file =~ /\/[^\s]+[_\-]\d[^\s]*-\d[^\s]*\.tar\.bz2$/) {
    my $run_scripts = 1;
    $run_scripts = 0 if defined($in->{'noscripts'}) && $in->{'noscripts'} == 1;
    $rv = install_cygwin_pkg($file, $temp, $in->{'root'}, $run_scripts,
			     $in->{'replacepkgs'}, $in->{'upgrade'});
} else {
    $rv = &system_logged("rpm -i $opts ".quotemeta($file)." >$temp 2>&1");
}
local $out = "";
if (! open(FILE, "<$temp")) {
    warn "could not open $temp: $!\n";
} else {
    $out = join('', <FILE>);
    close(FILE);
    $out =~ s/warning:.*\n//;
    unlink($temp);
}
if ($rv) {
	return "<pre>$out</pre>";
	}
return undef;
}

#instead of defining install_packages() (which do_install.cgi has a
#couple of design flaws with), make it install them one-by-one.
#<<- no sub install_packages here ->>

# check_files(package, version)
# Fills in the %files array with information about the files belonging
# to some package. Values in %files are  path type user group size error
sub check_files
{
local($i, $_, @w, %errs, $epath); $i = 0;
my @cygdata = cygwin_pkg_info(@_);
my $root = "/";
my $origlst = "${root}etc/setup/$cygdata[0].lst.gz";
if (@cygdata && -f $origlst) {
    #$name, $class, $desc, $arch, $ver, $vendor, $date
    my $lst = uncompress_if_needed($origlst);
    if (&open_readfile(FILES, $lst)) {
	while (<FILES>) {
	    chomp($_);
	    my $f = get_file_info($root . $_);
	    for (qw(path link type user group size error)) {
		$files{$i, $_} = $f->{$_} if defined($f->{$_});
	    }
	    $i++;
	}
	close(FILES);
	&unlink_file($lst) if $origlst ne $lst;
    }
}
return $i if $i > 0 || ! $hasrpm;

local $n = $_[1] ? "$_[0]-$_[1]" : $_[0];
local $qm = quotemeta($n);
&open_execute_command(RPM, "rpm -V $qm", 1, 1);
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
&open_execute_command(RPM, "rpm -q $qm -l --dump", 1, 1);
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

# installed_file(file)
# Given a filename, fills %file with details of the given file and returns 1.
# If the file is not known to the package system, returns 0
# Usable values in %file are  path type user group mode size packages
sub installed_file
{
local($pkg, @w, $_, @pkgs, @vers);
undef(%file);
my $root = "/";

my $file = $_[0];
$file =~ s/^$root//;
local $qm = quotemeta($file);
@pkgs = &backquote_command("zgrep -le '^$qm\$' /etc/setup/*.lst.gz 2>&1", 1);
chomp(@pkgs);
if (@pkgs) {
    grep(s/.*etc\/setup\/(.+)\.lst\.gz/$1/g, @pkgs);
    my $f = get_file_info($root . $file);
    $f->{'packages'} = join(' ', @pkgs);
    if (&open_readfile(LST, $db)) {
	while (<LST>) {
	    if (/^([^\s]+)\s+[^\s]+[_\-]([\d][^\s]\.tar\.bz2)\s/) {
		my ($pkg, $ver) = ($1, $2);
		$f->{'versions'} .= "$ver "
		    if grep(/^$pkg$/, @pkgs);
	    }
	}
	close(LST);
    }
    %file = %$f;
    return 1;
} else {
    return 0 if ! $hasrpm;
}

local $qm = quotemeta($_[0]);
$pkg = &backquote_command("rpm -q -f $qm --queryformat \"%{NAME}\\n\" 2>&1", 1);
if ($pkg =~ /not owned/ || $?) { return 0; }
@pkgs = split(/\n/, $pkg);
$pkg = &backquote_command("rpm -q -f $qm --queryformat \"%{VERSION}-%{RELEASE}\\n\" 2>&1");
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
    my @cygdata = cygwin_pkg_info(@_);
    if (@cygdata) {
	print "<b>$text{'cygwin_warnuse'}</b><br>\n";
    } else {
	print "<b>$text{'delete_nodeps'}</b>\n";
	print &ui_yesno_radio("nodeps", 0),"<br>\n";
    }
print "<b>$text{'delete_noscripts'}</b>\n";
print &ui_yesno_radio("noscripts", 0),"<br>\n";
}

# delete_package(package, [&options], version)
# Attempt to remove some package
sub delete_package
{
    local $in = $_[2] ? $_[2] : \%in;
    my @cygdata = cygwin_pkg_info($_[0], $_[2]);
    if (@cygdata) {
	my $root = "/";
	my $run_scripts = 1;
	$run_scripts = 0 if (defined($in->{'noscripts'}) &&
			     $in->{'noscripts'} == 1);
	local $temp = &transname();
	my $rv = remove_cygwin_pkg($_[0], $temp, $root, $run_scripts);
	if ($rv && &open_readfile(FILE, $temp)) {
	    my $out = join('', <FILE>);
	    close(FILE);
	    unlink($temp);
	    return "<pre>$out</pre>" if $rv;
	}
	return undef;
    }

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
    my $text = "CYGWIN";
    $text .= "/RPM" if $hasrpm;
    return $text;
}

sub package_help
{
return "cygwin";
}

%etype = (	"5", $text{'rpm_md5'},	"S", $text{'rpm_fsize'},
		"L", $text{'rpm_sym'},	"T", $text{'rpm_mtime'},
		"D", $text{'rpm_dev'},	"U", $text{'rpm_user'},
		"M", $text{'rpm_perm'},	"G", $text{'rpm_group'} );

$has_search_system = 1;

sub search_system_input
{
print "<input type=button onClick='window.ifield = document.forms[2].url; chooser = window.open(\"rpmfind.cgi\", \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=600,height=500\")' value=\"$text{'rpm_find'}\">";
}

# file, temp output file, root path
sub install_cygwin_src_pkg
{
    my ($file, $temp, $root) = @_;
    $root .= "/" if $root =~ /[^\/]$/;
    $root .= "usr/src/";
    &system_logged("mkdir -p $root > $temp 2>&1") if ! -d $root;
    my $opts = "-jt";
    $opts .= " -C $root";
    my $pkg = $file;
    $pkg =~ s/[_\-]\d.*//;
    my $rv = &system_logged("tar $opts -f ".quotemeta($file).
			    " >>$temp 2>&1");
    return $rv;
}

# file, temp output file, root path, run_scripts, replace pkgs, upgrade
sub install_cygwin_pkg
{
    my ($file, $temp, $root, $run_scripts, $replace_pkgs, $upgrade) = @_;

    $root .= "/" if $root =~ /[^\/]$/;
    &system_logged("mkdir -p $root > $temp 2>&1") if ! -d $root;
    my $opts = "-jxv";
    $opts .= " -C $root";
    my $pkg = $file;
    $pkg =~ s/.*\/(.+?)[_\-]\d.*/$1/;
    my $setupdir = "${root}etc/setup";
    my $lstfile = "$setupdir/$pkg.lst";

    #the only time we don't check for the same package currently installed
    #is if the user specified to replace pkgs but not to upgrade
    my @cygdata = ();
    unless (! $upgrade && $replace_pkgs) {
	#check to see if a package is already installed
	@cygdata = cygwin_pkg_info($pkg);
	if (@cygdata && $upgrade) {
	    remove_cygwin_pkg($cygdata[0], $temp, $root, $run_scripts);
	}
    }
    if (@cygdata && ! $upgrade && ! $replace_pkgs) {
	if (&open_tempfile(FILE, ">>$temp", 1)) {
	    &print_tempfile(FILE, &text('cygwin_pkgexists', $pkg) . "\n");
	    &close_tempfile(FILE);
	}
	return 1;
    }

    &system_logged("mkdir -p $setupdir") if ! -d $setupdir;
    my $rv = &system_logged("tar $opts -f ".quotemeta($file).
			    " > $lstfile 2>>$temp");
    if ($run_scripts && open(FILE, "<$lstfile")) {
	#run postinstall scripts
	while (<FILE>) {
	    if (/etc\/postinstall\/.*sh/) {
		my $f = quotemeta($_);
		$rv += &system_logged("sh $root$f >> $temp 2>&1");
		$rv += &system_logged("mv -v $root$f $root$f.done>>$temp 2>&1");
	    }
	}
	close(FILE);
    }
    $rv += &system_logged("gzip -f $lstfile >>$temp 2>&1");
    my $db = "$setupdir/installed.db";
    $file =~ s/.*\///;
    if (open(FILE, "<$db")) {
	my @lines = <FILE>;
	close(FILE);
	#avoid windows security issues
	&system_logged("chmod u+w $db >>$temp 2>&1") if ! -w $db;
	&system_logged("chown $ENV{'USERNAME'} $db >>$temp 2>&1")
	    if ! -O $db;
	&lock_file($db);
	if (&open_tempfile(FILE, ">$db", 1)) {
	    #remove the package from the db if it already exists
	    @lines = grep {! /^$pkg /} @lines;
	    #add this package to the end.
	    push(@lines, "$pkg $file 0\n");
	    &print_tempfile(FILE, @lines);
	    &close_tempfile(FILE);
	}
	&unlock_file($db);
    }
    return $rv;
}

# pkg, temp output file, root path, run_scripts
sub remove_cygwin_pkg
{
    my ($pkg, $temp, $root, $run_scripts) = @_;
    $root .= "/" if $root =~ /[^\/]$/;
    my $setupdir = "${root}etc/setup";
    my $lstfile = "$setupdir/$pkg.lst.gz";
    my $rv = 0;

    my @cygdata = cygwin_pkg_info($pkg);
    if (! @cygdata) {
	if (&open_tempfile(FILE, ">$temp", 1)) {
	    &print_tempfile(FILE, "Could not find $pkg\n");
	    &close_tempfile(FILE);
	}

    #kludge: don't get rid of packages on which we depend
    } elsif ($pkg =~ /^(perl|webmin|gzip|tar|bzip2|cygwin|ash)$/) {
	if (&open_tempfile(FILE, ">$temp", 1)) {
	    &print_tempfile(FILE, "Not removing $pkg because of dependencies.\n");
	    &print_tempfile(FILE, "You'll have to force installation of the package.\n");
	    &close_tempfile(FILE);
	}

    #load in the list file
    } elsif (! -f $lstfile || ! open(LST, "gunzip -c $lstfile |")) {
	$rv = 1;
	if (&open_tempfile(FILE, ">$temp")) {
	    &print_tempfile(FILE, "Could not open $lstfile\n");
	    &close_tempfile(FILE);
	}
    } else {
	my @files = <LST>;
	chomp(@files);
	close(LST);

	#run preremove scripts
	if ($run_scripts) {
	    my @scripts = grep(/^etc\/preremove\/.*sh/, @files);
	    foreach (@scripts) {
		my $f = quotemeta($_);
		$rv += system_logged("sh $root$f >> $temp 2>&1");
		$rv += system_logged("mv -v $root$f $root$f.done>>$temp 2>&1");
	    }
	}

	#remove all files except files in etc
	foreach (reverse(@files)) {
	    next if /^etc\//;
	    if (-d $_) {
		my $msg = &unlink_logged($_)? "" : $!;
		$rv++ if $msg ne "";
	    } elsif (-f $_) {
		my $msg = &unlink_logged($_)? "" : $!;
		$rv++ if $msg ne "";
	    }
	}

	#run postremove scripts
	if ($run_scripts) {
	    my @scripts = grep(/^etc\/postremove\/.*sh/, @files);
	    foreach (@scripts) {
		my $f = quotemeta($_);
		$rv += system_logged("sh $root$f >> $temp 2>&1");
		$rv += system_logged("mv -v $root$f $root$f.done>>$temp 2>&1");
	    }
	}

	$rv += system_logged("rm -f $lstfile >>$temp 2>&1");
	my $db = "$setupdir/installed.db";
	lock_file($db);
	if (&open_readfile(FILE, $db)) {
	    my @lines = <FILE>;
	    close(FILE);
	    if (&open_tempfile(FILE, ">$db")) {
		#remove the package from the db
		@lines = grep {! /^$pkg /} @lines;
		&print_tempfile(FILE, @lines);
		&close_tempfile(FILE);
	    }
	}
	unlock_file($db);
    }
    return $rv;
}

#returns: name, class, description, arch, version, vendor, installtime
sub cygwin_pkg_info
{
    my ($pkg_name, $pkg_ver) = @_;
    if (&open_readfile(DB, $db)) {
	while (<DB>) {
	    if (/^([^\s]*)\s+([^\s]+)\s+(\d+)/) {
		#TODO: classes, descriptions, vendor, installtime, arch
		my ($name, $ver, $class, $desc) = ($1, $2, "cygwin", "");
		next if $name ne $pkg_name;
		$ver =~ s/.*?[_\-]([\d+].*)\.tar\..*/$1/;
		next if defined($pkg_ver) && $pkg_ver ne $ver;
		my ($arch, $vendor, $date) = ("i586", "cygwin", undef);
		if (@_ = stat(&translate_filename("/etc/setup/$name.lst.gz"))) {
		    $date = make_date($_[9]);
		}
		close(DB);
		return ($name, $class, $desc, $arch, $ver, $vendor, $date)
	    }
	}
	close(DB);
    }
    return ();
}

# Usable values in %file are  path type user group mode size packages
sub get_file_info
{
    my ($f) = @_;
    my $predetected_error = "";

    #check to make sure if it is a post install script that it was run
    if ($f =~ /\/etc\/postinstall\/.*\.sh$/) {
	if (-e $f) {
	    $predetected_error = $text{'cygwin_badpostscript'};
	} else {
	    #automatically change postinstall script to be .done
	    #since it does not exist
	    $f =~ s%(/etc/postinstall/.*\.sh)$%$1.done%;
	}
    }

    my %file;
    my $real = &translate_filename($f);
    $file{'path'} = $f;
    if (! -l $real && ! -e $real) {
	$file{'error'} = $text{'cygwin_fmissing'};
    } elsif (-d $real) {
	$file{'type'} = 1;
	$file{'error'} = $predetected_error;
	if (@_ = stat($real)) {
	    my @ent = getpwuid($_[4]);
	    $file{'user'} = (@ent && $ent[0] ne "????????")?
		$ent[0] : $_[4];
	    @ent = getgrgid($_[5]);
	    $file{'group'} = (@ent && $ent[0] ne "????????")?
		$ent[0] : $_[5];
	    $file{'size'} = $_[7];
	    $file{'mode'} = sprintf "%o", $_[2] & 07777;
	}
    } elsif (-l $real) {
	$file{'type'} = 3;
	if (@_ = lstat($real)) {
	    my @ent = getpwuid($_[4]);
	    $file{'user'} = (@ent && $ent[0] ne "????????")?
		$ent[0] : $_[4];
	    @ent = getgrgid($_[5]);
	    $file{'group'} = (@ent && $ent[0] ne "????????")?
		$ent[0] : $_[5];
	    $file{'size'} = $_[7];
	    $file{'mode'} = sprintf "%o", $_[2] & 07777;
	    if ($file{'link'} = readlink($real)) {
		my $l = $file{'link'};
		my $lreal = &translate_filename($l);
		my $fb = $f; $fb =~ s/[^\/]*$//;
		$l = $fb . $l if $l !~ /^\//;
		if (! -l $lreal && ! -e $lreal) {
		    $file{'error'} = $text{'cygwin_lmissing'};
		} else {
		    $file{'error'} = $predetected_error;
		}
	    } else {
		$file{'error'} = &text('cygwin_elread', $!);
	    }
	} else {
	    $file{'error'} = &text('cygwin_elstat', $!);
	}
    } else {
	#2 = special file; 0 = regular file
	$file{'type'} = (-f $real)? 0 : 2;
	if (@_ = stat($real)) {
	    my @ent = getpwuid($_[4]);
	    $file{'user'} = (@ent && $ent[0] ne "????????")?
		$ent[0] : $_[4];
	    @ent = getgrgid($_[5]);
	    $file{'group'} = (@ent && $ent[0] ne "????????")?
		$ent[0] : $_[5];
	    $file{'size'} = $_[7];
	    $file{'mode'} = sprintf "%o", $_[2] & 07777;
	    $file{'error'} = $predetected_error;
	} else {
	    $file{'error'} = &text('cygwin_estat', $!);
	}
    }
    return \%file;
}
1;

