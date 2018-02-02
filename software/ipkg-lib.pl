# ipkg-lib.pl
# Functions for synology IPKG package management

use POSIX;
chop($system_arch = `uname -m`);
$package_dir = "/var/db/pkg";
$has_update_system = 1;
$no_package_install = 1;

sub list_package_system_commands
{
return ("ipkg");
}

# list_packages([package]*)
# Fills the array %packages with a list of all packages
# ipkg extension: if ALL is specified list also uninstalled packages
sub list_packages
{
local $i = 0;
local $arg = join(" ", map { quotemeta($_) } @_);
%packages = ( );
&open_execute_command(PKGINFO, "ipkg info", 1, 1);
while(<PKGINFO>) {
		$_ =~ s/\r|\n//g;
		local ($param, $val) = split(/: /, $_);
		if ($param eq 'Package') {
			$name=$val;
		} elsif ($param eq 'Version') {
			$version=$val;
		} elsif ($param eq 'Description') {
			$desc=$val;
		} elsif ($param eq 'Section') {
			$class=$val;
		} elsif ($param eq 'Installed-Time') {
			$inst=$val;
		} elsif ($val eq '') {
		    next if (! $inst && $arg ne "ALL");
			$packages{$i,'name'} = $name;
			$packages{$i,'version'} = $version;
			$packages{$i,'desc'} = $desc;
			$packages{$i,'install'} = $inst;  
			#$packages{$i,'class'} = $class; 
			# generate categories from names, lib and x
			$name =~ m/^(..[^-0-9]*)/;
			local $cat= $1;
			if ($class =~ m/^(audio|editor|games)/) {
				$cat=$1;
			} elsif ($cat =~ m/^(audio|auto|diff|lib|ffmpeg|gnu|gtk|perl|net|ncurses)/) {
				$cat=$1;
			} elsif ($cat =~ /^x|motif/ && $desc =~ /X |Xorg|X11|XDMCP|Xinerama|Athena|Motif/) {
				$cat = "x11";
			} elsif ($cat =~ /^x/ && $desc eq "") {
				$cat = "x";
			} elsif ($cat =~ /^(esmtp|fetchmail|mail|mini|mutt|mpop|msmtp|pop|postfix|postgrey|procmail|putmail|qpopper|sendmail|xmail)/ ) {
				$cat = "mail";
			} elsif ($cat =~ /^(arc|bzip|cabex|cpio|freeze|gzip|lha|lzo|p7|tar|upx|unarj|xz|zip|zlib|zoo|unzip|unrar)/) {
				$cat = "archiver";
			} 
			$packages{$i,'class'} = $cat; 
			$inst='';
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
local $out = &backquote_command("ipkg info $_[0] 2>&1", 1);
return () if ($?);
local @rv = ( $_[0] );
push(@rv, $out =~ /Section: (.+)/i);
push(@rv, $out =~ /Description: (.+)/i ? $1 : $text{'bsd_unknown'});
push(@rv, $out =~ /Architecture: (.+)/i );
push(@rv, $out =~ /Version: (.+)/i );
push(@rv, $out =~ /Maintainer: (.+)/i);
push(@rv, $out =~ /Installed-Time: (.+)/i ? ctime($out =~ /Installed-Time: (.+)/i) : "not installed");
push(@rv, $out =~ /Installed-Time: (.+)/i ? "" : false);
push(@rv, $out =~ /Installed-Time: (.+)/i ? "" : false);
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
&open_execute_command(PKGINFO, "ipkg files $qm", 1, 1);
while($file = <PKGINFO>) {
	$file =~ s/\r|\n//g;
	next if ($file =~ /^Package /);
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
	&open_execute_command(PKGINFO, "ipkg files $packages{$i,'name'}", 1,1);
	while($file = <PKGINFO>) {
		next if ($file =~ /^Package /);
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


# install_package(file, package)
# Installs the package in the given file, with options from %in
sub install_package
{
local $out = &backquote_logged("ipkg install $_[1] 2>&1");
if ($?) {
	return "<pre>$out</pre>";
	}
return undef;
}

# delete_package(package)
# Totally remove some package
sub delete_package
{
local $out = &backquote_logged("ipkg remove $_[0] 2>&1");
if ($?) { return "<pre>$out</pre>"; }
return undef;
}

sub package_system
{
return &text('bsd_manager', "SYNOLOGY");
}

sub package_help
{
return "ipkg";
}

sub list_update_system_commands
{
return ("ipkg");
}

# update_system_install([package])
# Install some package with IPKG
sub update_system_install
{
local $update = $_[0] || $in{'update'};
local (@rv, @newpacks);
local $cmd = "ipkg install";
print "<b>",&text('IPKG_install', "<tt>$cmd</tt>"),"</b><p>\n";
print "<pre>";
&additional_log('exec', undef, "$cmd $update");
local $qm = join(" ", map { quotemeta($_) } split(/\s+/, $update));
&open_execute_command(CMD, "$cmd $qm", 2);
while(<CMD>) {
	s/\r|\n//g;
	if (/Installing\s+(\S+)\s+/) {
		# Found a package
		local $pkg = $1;
		$pkg =~ s/\-\d.*//;	# remove version
		push(@rv, $pkg);
		}
	print &html_escape($_."\n");
	}
close(CMD);
print "</pre>\n";
if ($?) {
	print "<b>$text{'IPKG_failed'}</b><p>\n";
	return ( );
	}
else {
	print "<b>$text{'IPKG_ok'}</b><p>\n";
	return &unique(@rv);
	}
}

# update_system_form()
# Shows a form for updating all packages on the system
sub update_system_form
{
print &ui_subheading($text{'IPKG_form'});
print &ui_buttons_start();
print &ui_form_start("ipkg_upgrade.cgi");
print &ui_submit($text{'IPKG_update'}, "update"),"<br>\n";
print &ui_submit($text{'IPKG_upgrade'}, "upgrade");
print &ui_form_end(), "</td><td align=\"right\">";
print &ui_form_start("ipkg-tree.cgi");
print &ui_submit($text{'IPKG_index_tree'});
print &ui_form_end();
print &ui_buttons_end();
}

# update_system_resolve(name)
# Converts a standard package name like apache, sendmail or squid into
# the name used by YUM.
sub update_system_resolve
{
local ($name) = @_;
return $name eq "dhcpd" ? "dhcp-server" :
       $name eq "mysql" ? "mariadb" :
       $name eq "openldap" ? "openldap openldap-servers" :
       $name eq "postgresql" ? "postgresql postgresql-server" :
       $name eq "samba" ? "samba-client samba-server" :
                          $name;
}

# update_system_available()
# Returns a list of package names and versions that are available from IPKG
sub update_system_available
{
local @rv;
local %done;
&open_execute_command(PKG, "ipkg list-upgradable", 1, 1);
while(<PKG>) {
	if (/^(\S+)\-(\d[^\-]*)\-([^\.]+)\.(\S+)/) {
		next if ($done{$1,$2}++);
		push(@rv, { 'name' => $1,
			    'version' => $2,
			    'release' => $3,
			    'arch' => $4 });
		}
	}
close(PKG);
return @rv;
}

