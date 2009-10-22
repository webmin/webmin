# hpux-lib.pl
# Functions for HP-UX package management

sub list_package_system_commands
{
return ("swlist", "swinstall");
}

# list_packages([package]*)
# Fills the array %packages with all or listed packages
sub list_packages
{
local($i, $name, $class, @contents, $products, $title_flag);
$i = 0;
$products = join(' ', @_);
$name = "";
%packages = ( );

open(SW, "swlist -v -a title -a contents |");
while(<SW>) {
	s/#.*$//g;
# bundles and unbundled products
	if (/^  (\S*)/) {
		$name = $1;
		$packages{$i,'name'} = $1;
		$packages{$i,'class'} = $1;
		}
        if (/^bundle/ || /^product/) {
                $title_flag = 1;
                }
	if (/^title\s+(.*)/ && $title_flag) {
		$packages{$i,'desc'} = $1;
		if ($products eq "" || (index $products,$name) ne -1) {
			$i++;
			}
                $title_flag = "";
		}
# bundeled products
	if (/^contents\s+(.*)/) {
		@contents = split(/\./, $1);
		$packages{$i,'name'} = "$name.$contents[0]";
		$packages{$i,'class'} = $name;
		if (($products eq "" ||
		     (index $products,"$contents[0]") ne -1) &&
		    $packages{$i,'name'} ne $packages{$i - 1,'name'} ) {
			$i++;
			}
		}
	}
close(SW);

return $i;
}

# package_info(package)
# Returns an array of package information in the order
#  name, class, description, arch, version, vendor, installtime
sub package_info
{
local(@name, $level, $name, $class, $desc, $arch, $version, $vendor, $date);

$name = $_[0];
@name = split(/\./, $name);
$class = $name[0];

open(SW, "swlist -l product -v -a vendor.title -a title -a revision -a architecture -a date $name | ");
while(<SW>) {
	s/#.*$//g;
	if (/^date\s+(.*)/ &&
	    ($name[1] eq "" && $date eq "" || $name[1] ne "")) {
		$date = $1;
		}
	if (/^architecture\s+(.*)/ &&
	    ($name[1] eq "" && $arch eq "" || $name[1] ne "")) {
		$arch = $1;
		}
	if (/^revision\s+(.*)/ &&
	    ($name[1] eq "" && $version eq "" || $name[1] ne "")) {
		$version = $1;
		}
	if (/^vendor\.title\s+(.*)/ &&
	    ($name[1] eq "" && $vendor eq "" || $name[1] ne "")) {
		$vendor = $1;
		}
	if (/^title\s+(.*)/ &&
	    ($name[1] eq "" && $desc eq "" || $name[1] ne "")) {
		$desc = $1;
		}
	}
close(SW);

return ($name, $class, $desc, $arch, $version, $vendor, $date);
}

# is_package(file)
# Check if some file is a package file
sub is_package
{
local($out);
$out = `swlist -s $_[0] 2>&1`;
return $out !~ /ERROR:   /;
}

# file_packages(file)
# Returns a list of all packages in the given file, in the form
#  package description
sub file_packages
{
local(@list);
open(SW, "swlist -s $_[0] |");
while(<SW>) {
	s/#.*$//g;
	if (/^  (\S*)\s+(\S*)/) {
		push (@list, "$1 $2");
		}
	}
close(SW);

return @list;
}

# install_options(file, package)
# Outputs HTML for choosing install options for some package
sub install_options
{
print &ui_table_row($text{'hpux_create_target_path'},
	&ui_yesno_radio("create_target_path", 1));

print &ui_table_row($text{'hpux_mount_all_filesystems'},
	&ui_yesno_radio("mount_all_filesystems", 1));

print &ui_table_row($text{'hpux_reinstall'},
	&ui_yesno_radio("reinstall", 0));

print &ui_table_row($text{'hpux_reinstall_files'},
	&ui_yesno_radio("reinstall_files", 1));

print &ui_table_row($text{'hpux_reinstall_files_use_cksum'},
	&ui_yesno_radio("reinstall_files_use_cksum", 1));

print &ui_table_row($text{'hpux_allow_multiple_versions'},
	&ui_yesno_radio("allow_multiple_versions", 0));

print &ui_table_row($text{'hpux_defer_configure'},
	&ui_yesno_radio("defer_configure", 0));

print &ui_table_row($text{'hpux_autorecover_product'},
	&ui_yesno_radio("autorecover_product", 0));

print &ui_table_row($text{'hpux_allow_downdate'},
	&ui_yesno_radio("allow_downdate", 0));

print &ui_table_row($text{'hpux_allow_incompatible'},
	&ui_yesno_radio("allow_incompatible", 0));

print &ui_table_row($text{'hpux_autoselect_dependencies'},
	&ui_yesno_radio("autoselect_dependencies", 1));

print &ui_table_row($text{'hpux_enforce_dependencies'},
	&ui_yesno_radio("enforce_dependencies", 1));

print &ui_table_row($text{'hpux_enforce_scripts'},
	&ui_yesno_radio("enforce_scripts", 1));

print &ui_table_row($text{'hpux_enforce_dsa'},
	&ui_yesno_radio("enforce_dsa", 1));

print &ui_table_row($text{'hpux_root'},
	&ui_textbox("root", "/", 50)." ".
	&file_chooser_button("root", 1), 3);
}

# install_package(file, package)
# Install the given package from the given file, using options from %in
sub install_package
{
local $in = $_[2] ? $_[2] : \%in;
foreach $o ('create_target_path',
	    'mount_all_filesystems',
	    'reinstall',
	    'reinstall_files',
	    'reinstall_files_use_cksum',
	    'allow_multiple_versions',
	    'defer_configure',
	    'autorecover_product',
	    'allow_downdate',
	    'allow_incompatible',
	    'autoselect_dependencies',
	    'enforce_dependencies',
	    'enforce_scripts',
	    'enforce_dsa') {
	if ($in->{$o}) { $opts .= " -x $o=true"; }
	else { $opts .= " -x $o=false"; }
	}
if ($in->{'root'} =~ /^\/.+/) {
	if (!(-d $in->{'root'})) {
		return "Root directory '$in->{'root'}' does not exist";
		}
	$opts .= " -r $in->{'root'}";
	}
$out = &backquote_logged("swinstall -s $_[0] $opts $_[1] 2>&1");
if ($?) { return "<pre>$out</pre>"; }
return undef;
}

# check_files(package)
# Fills in the %files array with information about the files belonging
# to some package.
sub check_files
{
local($i, $path); $i = -1;
open(SW, "swlist -l file -v -a path -a owner -a group -a type -a link_source -a size $_[0] | ");
while(<SW>) {
	s/#.*$//g;
	if (/^path\s+(.*)/) {
		$i++;
		$files{$i,'path'} = $1;
		$files{$i,'size'} = "-";
		$files{$i,'user'} = "-";
		$files{$i,'group'} = "-";
		$files{$i,'link'} = "";
		$path = $1;
		}
	if (/^owner\s+(.*)/ && $path ne "") {
		$files{$i,'user'} = $1;
		}
	if (/^group\s+(.*)/ && $path ne "") {
		$files{$i,'group'} = $1;
		}
	if (/^type\s+(.*)/ && $path ne "") {
                $files{$i,'type'} = $1 eq "f" ? 0 :
                                    $1 eq "d" ? 1 :
                                    $1 eq "s" ? 3 :
                                    $1 eq "h" ? 4 :
                                    -1;
		}
	if (/^link_source\s+(.*)/ && $path ne "") {
		$files{$i,'link'} = $1;
		}
	if (/^size\s+(.*)/ && $path ne "") {
		$files{$i,'size'} = $1;
		$path = "";
		}
	$files{$i,'error'} = "\n";
	}
close(SW);
return $i;
}

# installed_file(file)
# Given a filename, fills %file with details of the given file and returns 1.
# If the file is not known to the package system, returns 0
sub installed_file
{
local($path, $search, @tmp, $product, $product_flag, $path_flag);
$search = $_[0];

open(SW, "swlist -l file -v -a path -a owner -a group -a type -a link_source -a mode -a size | ");
while(<SW>) {
#	s/#.*$//g;
        if (/^product/) {
                $product_flag = 1;
                }
	if (/^# (\S*)/ && $product_flag) {
		@tmp = split(/\./, $1);
		$product = $tmp[0];
                $product_flag = "";
		}
	if (/^path\s+(.*)/) {
		if ($1 eq $search) {
			$file{'path'} = $1;
			$file{'size'} = "-";
			$file{'user'} = "-";
			$file{'mode'} = "-";	
			$file{'group'} = "-";
			if ((index $file{'packages'},$product) eq -1) {
				$file{'packages'} = join(' ', $product, $file{'packages'});
				}
			$path_flag = 1;
			}
		else {
			$path_flag = "";
			}
		}
	if (/^owner\s+(.*)/ && $path_flag) {
		$file{'user'} = $1;
		}
	if (/^group\s+(.*)/ && $path_flag) {
		$file{'group'} = $1;
		}
	if (/^type\s+(.*)/ && $path_flag) {
                $file{'type'} = $1 eq "f" ? 0 :
                                $1 eq "d" ? 1 :
                                $1 eq "s" ? 3 :
                                $1 eq "h" ? 4 :
                                -1;
		}
	if (/^link_source\s+(.*)/ && $path_flag) {
		$file{'link'} = $1;
		}
	if (/^mode\s+(.*)/ && $path_flag) {
		$file{'mode'} = $1;
		}
	if (/^size\s+(.*)/ && $path_flag) {
		$file{'size'} = $1;
		}
	$file{'error'} = "\n";
	}
close(SW);

if ($file{'packages'} ne "") { return 1; }
else { undef(%file); return 0; }
}

# delete_package(package)
# Attempt to remove some package
sub delete_package
{
$out = &backquote_logged("swremove $_[0] 2>&1");
if ($out) { return "<pre>$out</pre>"; }
return undef;
}

sub package_system
{
return "HP-UX SW";
}

sub package_help
{
return "swinstall swlist swremove";
}

1;

