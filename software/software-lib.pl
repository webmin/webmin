# software-lib.pl
# A generalized system for package management on solaris, linux, etc..

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
$heiropen_file = "$module_config_directory/heiropen";

# Use the appropriate function set for whatever package management system
# we are using.
do "$config{package_system}-lib.pl";

if ($config{'update_system'} eq '*') {
	# User specifically doesn't want any
	$update_system = undef;
	}
elsif ($config{'update_system'}) {
	# User-specified system
	$update_system = $config{'update_system'};
	}
else {
	# Guess which update system we are using
	if (&has_command($config{'apt_mode'} ? "aptitude" : "apt-get")) {
		$update_system = "apt";
		}
	elsif (&has_command("yum") && -r "/etc/yum.conf") {
		$update_system = "yum";
		}
	elsif (&has_command("up2date") && &has_command("rhn_check")) {
		$update_system = "rhn";
		}
	elsif (-x "/opt/csw/bin/pkg-get" || &has_command("pkg-get") ||
	       -x "/opt/csw/bin/pkgutil" || &has_command("pkgutil")) {
		$update_system = "csw";
		}
	elsif (&has_command("urpmi")) {
		$update_system = "urpmi";
		}
	elsif (&has_command("emerge")) {
		$update_system = "emerge";
		}
	elsif (&has_command("cupdate")) {
		# not done yet!
		}
	}
if ($update_system) {
	do $update_system."-lib.pl";
	$has_update_system = 1;
	}

# uncompress_if_needed(file, disposable)
# If some file needs to be uncompressed or ungzipped, do it and return the
# new temp file path. Otherwise, return the original path.
sub uncompress_if_needed
{
return $_[0] if (&is_readonly_mode());	# don't even bother
open(PFILE, $_[0]);
read(PFILE, $two, 2);
close(PFILE);
if ($two eq "\037\235") {
	if (!&has_command("uncompress")) {
		&unlink_file($_[0]) if ($_[1]);
		&error($text{'soft_euncompress'});
		}
	local $temp = $_[0] =~ /\/([^\/]+)\.Z/i ? &tempname("$1")
						: &tempname();
	local $out = `uncompress -c $_[0] 2>&1 >$temp`;
	unlink($_[0]) if ($_[1]);
	if ($?) {
		unlink($temp);
		&error(&text('soft_euncmsg', $out));
		}
	return $temp;
	}
elsif ($two eq "\037\213") {
	if (!&has_command("gunzip")) {
		unlink($_[0]) if ($_[1]);
		&error($text{'soft_egzip'});
		}
	local $temp = $_[0] =~ /\/([^\/]+)\.gz/i ? &tempname("$1")
						 : &tempname();
	local $out = `gunzip -c $_[0] 2>&1 >$temp`;
	unlink($_[0]) if ($_[1]);
	if ($?) {
		unlink($temp);
		&error(&text('soft_egzmsg', $out));
		}
	return $temp;
	}
return $_[0];
}

# show_package_info(package, version, [no-installed-message])
sub show_package_info
{
@pinfo = &package_info($_[0], $_[1]);
return () if (!@pinfo);

print &ui_subheading(&text('do_success', $_[0])) if (!$_[2]);
print &ui_table_start($text{'edit_details'}, "width=100%", 4,
		      [ "width=20%", undef, "width=20%", undef ]);

# Package description
if ($pinfo[2]) {
	$desc = &html_escape(&entities_to_ascii($pinfo[2]));
	$desc =~ s/\r?\n/&nbsp;<br>/g;
	print &ui_table_row($text{'edit_desc'}, "<tt>$desc</tt>", 3);
	}

# Name
print &ui_table_row($text{'edit_pack'}, &html_escape($pinfo[0]));

# Class, if any
print &ui_table_row($text{'edit_class'},
	$pinfo[1] ? &html_escape($pinfo[1]) : $text{'edit_none'});

# Version number
print &ui_table_row($text{'edit_ver'},
	&html_escape($pinfo[4]));

# Vendor
print &ui_table_row($text{'edit_vend'},
	&html_escape(&entities_to_ascii($pinfo[5])));

# Architecture
print &ui_table_row($text{'edit_arch'},
	&html_escape($pinfo[3]));

# Install date
print &ui_table_row($text{'edit_inst'},
	&html_escape($pinfo[6]));

print &ui_table_end();

return @pinfo;
}

@type_map = (	$text{'soft_reg'}, $text{'soft_dir'},  $text{'soft_spec'},
		$text{'soft_sym'}, $text{'soft_hard'}, $text{'soft_edit'} );

# get_heiropen()
# Returns an array of open categories
sub get_heiropen
{
open(HEIROPEN, $heiropen_file);
local @heiropen = <HEIROPEN>;
chop(@heiropen);
close(HEIROPEN);
return @heiropen;
}

# save_heiropen(&heir)
sub save_heiropen
{
&open_tempfile(HEIR, ">$heiropen_file");
foreach $h (@{$_[0]}) {
	&print_tempfile(HEIR, $h,"\n");
	}
&close_tempfile(HEIR);
}

# missing_install_link(package, description, return, return-desc)
# Returns HTML for installing some package that is missing, from the
# appropriate update system for this OS. Returns undef if automatic installation
# is not possible for some reason.
# Supported package names are :
#	apache
#	sendmail
#	postfix
#	squid
#	procmail
#	samba
#	mysql
#	postgresql
#	clamav
#	spamassassin
sub missing_install_link
{
local ($name, $desc, $return, $returndesc) = @_;
return undef if (!defined(&update_system_resolve));
return undef if (!&foreign_check($module_name));
local $pkg = &update_system_resolve($name);
return undef if (!$pkg);
local ($cpkg) = caller();
local $caller = eval '$'.$cpkg.'::module_name';
return &text('missing_link', $desc, "../$module_name/install_pack.cgi?source=3&update=".&urlize($pkg)."&return=".&urlize($return)."&returndesc=".&urlize($returndesc)."&caller=".&urlize($caller), $text{$update_system."_name"});
}

# update_system_button(field-name, label)
# Returns HTML for a button that opens the update system search window
sub update_system_button
{
local ($name, $label) = @_;
if (defined(&update_system_available) || defined(&update_system_search)) {
	return "<input type=button onClick='window.ifield = form.$name; chooser = window.open(\"../$module_name/find.cgi\", \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=600,height=500\")' value=\"$label\">";
	}
return undef;
}

# compare_versions(ver1, ver2)
# Returns -1 if ver1 is older than ver2, 1 if newer, 0 if same
sub compare_versions
{
local @sp1 = split(/[\.\-\+]/, $_[0]);
local @sp2 = split(/[\.\-\+]/, $_[1]);
for(my $i=0; $i<@sp1 || $i<@sp2; $i++) {
	local $v1 = $sp1[$i];
	local $v2 = $sp2[$i];
	local $comp;
	if ($v1 =~ /^\d+$/ && $v2 =~ /^\d+$/) {
		# Full numeric compare
		$comp = $v1 <=> $v2;
		}
	elsif ($v1 =~ /^\d+\S*$/ && $v2 =~ /^\d+\S*$/) {
		# Numeric followed by string
		$v1 =~ /^(\d+)(\S*)$/;
		local ($v1n, $v1s) = ($1, $2);
		$v2 =~ /^(\d+)(\S*)$/;
		local ($v2n, $v2s) = ($1, $2);
		$comp = $v1n <=> $v2n;
		if (!$comp) {
			# X.rcN is always older than X
			if ($v1s =~ /^rc\d+$/i && $v2s =~ /^\d*$/) {
				$comp = -1;
				}
			elsif ($v1s =~ /^\d*$/ && $v2s =~ /^rc\d+$/i) {
				$comp = 1;
				}
			else {
				$comp = $v1s cmp $v2s;
				}
			}
		}
	elsif ($v1 =~ /^\d+$/ && $v2 !~ /^\d+$/) {
		# Numeric compared to non-numeric - numeric is always higher
		$comp = 1;
		}
	elsif ($v1 !~ /^\d+$/ && $v2 =~ /^\d+$/) {
		# Non-numeric compared to numeric - numeric is always higher
		$comp = -1;
		}
	else {
		# String compare only
		$comp = $v1 cmp $v2;
		}
	return $comp if ($comp);
	}
return 0;
}

# check_package_system()
# Returns an error message if some command needed by the selected package
# management system is missing.
sub check_package_system
{
local $err;
if (defined(&validate_package_system)) {
	$err = &validate_package_system();
	}
if (defined(&list_package_system_commands)) {
	foreach my $c (&list_package_system_commands()) {
		if (!&has_command($c)) {
			$err ||= &text('index_epackagecmd', &package_system(),
				       "<tt>$c</tt>");
			}
		}
	}
return $err;
}

# check_update_system()
# Returns an error message if some command needed by the selected update
# system is missing.
sub check_update_system
{
return undef if (!$update_system);
local $err;
if (defined(&validate_update_system)) {
	$err = &validate_update_system();
	}
if (defined(&list_update_system_commands)) {
	foreach my $c (&list_update_system_commands()) {
		if (!&has_command($c)) {
			$err ||= &text('index_eupdatecmd',
			    $text{$update_system.'_name'} || uc($update_system),
			    "<tt>$c</tt>");
			}
		}
	}
return $err;
}

1;

