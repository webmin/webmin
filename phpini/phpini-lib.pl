# Functions for managing the PHP configuration file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();

# Fix language strings that refer to MySQL
if (&foreign_check("mysql")) {
	&foreign_require("mysql");
	&mysql::fix_mysql_text(\%text);
	}

# get_config_fmt(file)
# Returns a format code for php.ini or FPM config files
sub get_config_fmt
{
local ($file) = @_;
return $file =~ /\.conf$/ ? "fpm" : "ini";
}

# get_config([file])
# Returns an array ref of PHP configuration directives from some file 
sub get_config
{
local ($file) = @_;
$file ||= &get_default_php_ini();
local $fmt = &get_config_fmt($file);
if (!defined($get_config_cache{$file})) {
	local @rv = ( );
	local $lnum = 0;
	local $section;
	open(CONFIG, "<".$file) || return undef;
	if ($fmt eq "ini") {
		# Classic php.ini format
		while(<CONFIG>) {
			s/\r|\n//g;
			s/\s+$//;
			local $uq;
			if (/^(;?)\s*(\S+)\s*=\s*"(.*)"/ ||
			    /^(;?)\s*(\S+)\s*=\s*'(.*)'/ ||
			    ($uq = ($_ =~ /^(;?)\s*(\S+)\s*=\s*(.*)/))) {
				# Found a variable (php.ini format)
				push(@rv, { 'name' => $2,
					    'value' => $3,
					    'enabled' => !$1,
					    'line' => $lnum,
					    'file' => $file,
					    'section' => $section,
					    'fmt' => $fmt,
					  });
				if ($uq) {
					# Remove any comments
					$rv[$#rv]->{'value'} =~ s/\s+;.*$//;
					}
				}
			elsif (/^\[(.*)\]/) {
				# A new section
				$section = $1;
				}
			$lnum++;
			}
		}
	else {
		# FPM config file format, with php options
		while(<CONFIG>) {
			s/\r|\n//g;
			s/\s+$//;
			if (/^(;?)(php_admin_value|php_value)\[(\S+)\]\s*=\s*(.*)/) {
				# Found an FPM config that sets a PHP variable
				push(@rv, { 'name' => $3,
					    'value' => $4,
					    'admin' => $2 eq "php_admin_value" ? 1 : 0,
					    'enabled' => !$1,
					    'line' => $lnum,
					    'file' => $file,
					    'fmt' => $fmt,
					  });
				}
			$lnum++;
			}
		}
	close(CONFIG);
	$get_config_cache{$file} = \@rv;
	}
return $get_config_cache{$file};
}

# find(name, &config, [disabled-mode])
# Look up a directive by name
sub find
{
local ($name, $conf, $mode) = @_;
local @rv = grep { lc($_->{'name'}) eq lc($name) &&
		   ($mode == 0 && $_->{'enabled'} ||
		    $mode == 1 && !$_->{'enabled'} ||
		    $mode == 2) } @$conf;
return wantarray ? @rv : $rv[0];
}

sub find_value
{
local @rv = map { $_->{'value'} } &find(@_);
return $rv[0];
}

# save_directive(&config, name, [value|&values], [newsection], [neverquote])
# Updates a single entry in the PHP config file
sub save_directive
{
local ($conf, $name, $values, $newsection, $noquote) = @_;
my @values = ref($values) ? @$values : ( $values );
$newsection ||= "PHP";
my @old = &find($name, $conf, 0);
my @cmt = &find($name, $conf, 1);
my $fmt = @old ? $old[0]->{'fmt'} : @$conf ? $conf->[0]->{'fmt'} : "fpm";
my $lref;
for(my $i=0; $i<@old || $i<@values; $i++) {
	my $old = $i<@old ? $old[$i] : undef;
	my $value = $i<@values ? $values[$i] : undef;
	my $cmt = $i<@cmt ? $cmt[$i] : undef;
	if ($fmt eq "ini") {
		$newline = $name." = ".
			   ($value !~ /\s/ || $noquote ? $value :
			    $value =~ /"/ ? "'$value'" : "\"$value\"");
		}
	else {
		my $n = !$old || $old->{'admin'} ? "php_admin_value"
						 : "php_value";
		$newline = $n."[".$name."] = ".$value;
		}
	if (defined($value) && $old) {
		# Update existing value
		$lref = &read_file_lines_as_user($old->{'file'});
		$lref->[$old->{'line'}] = $newline;
		$old->{'value'} = $value;
		}
	elsif (defined($value) && !$old && $cmt) {
		# Update existing commented value
		$lref = &read_file_lines_as_user($cmt->{'file'});
		$lref->[$cmt->{'line'}] = $newline;
		$cmt->{'value'} = $value;
		$cmt->{'enabled'} = 1;
		}
	elsif (defined($value) && !$old && !$cmt) {
		# Add a new value, at the end of the section
		my ($lastline, $lastfile);
		if ($fmt eq "ini") {
			# Find last directive in requested php.ini section
			my $last;
			foreach my $c (@$conf) {
				if ($c->{'section'} eq $newsection) {
					$last = $c;
					}
				}
			$last || &error("Could not find any values in ".
					"section $newsection");
			$lastfile = $last->{'file'};
			$lastline = $last->{'line'};
			$lref = &read_file_lines_as_user($lastfile);
			}
		else {
			# Just add at the end
			$lastfile = @$conf ? $conf->[0]->{'file'} : undef;
			if (!$lastfile) {
				my @allfiles = keys %get_config_cache;
				$lastfile = $allfiles[0] if (@allfiles == 1);
				}
			$lastfile || &error("Don't know which file to add to");
			$lref = &read_file_lines_as_user($lastfile);
			$lastline = scalar(@$lref);
			}

		# Found last value in the section - add after it
		splice(@$lref, $lastline+1, 0, $newline);
		&renumber($conf, $lastline, 1);
		push(@$conf, { 'name' => $name,
			       'value' => $value,
			       'enabled' => 1,
			       'file' => $lastfile,
			       'line' => $lastline+1,
			       'section' => $newsection,
			     });
		}
	elsif (!defined($value) && $old && $cmt) {
		# Totally remove a value
		$lref = &read_file_lines_as_user($old->{'file'});
		splice(@$lref, $old->{'line'}, 1);
		@$conf = grep { $_ ne $old } @$conf;
		&renumber($conf, $old->{'line'}, -1);
		}
	elsif (!defined($value) && $old && !$cmt) {
		# Turn a value into a comment
		$lref = &read_file_lines_as_user($old->{'file'});
		$old->{'enabled'} = 0;
		$lref->[$old->{'line'}] = "; ".$lref->[$old->{'line'}];
		}
	}
}

sub renumber
{
local ($conf, $line, $oset) = @_;
foreach my $c (@$conf) {
	$c->{'line'} += $oset if ($c->{'line'} > $line);
	}
}

# can_php_config(file)
# Returns 1 if some config file can be edited
sub can_php_config
{
local ($file) = @_;
return &indexof($file, map { $_->[0] } &list_php_configs()) >= 0 ||
       $access{'anyfile'};
}

# get_default_php_ini()
# Returns the first php.ini that exists
sub get_default_php_ini
{
local @inis = split(/\t+/, $config{'php_ini'});
foreach my $ai (@inis) {
	local ($f, $d) = split(/=/, $ai);
	local @f = glob($f);
	return $f[0] if (@f && -r $f[0]);
	}
if ($config{'alt_php_ini'} && -r $config{'alt_php_ini'} && @inis) {
	# Fall back to default file
	local ($f) = split(/=/, $inis[0]);
	&copy_source_dest($config{'alt_php_ini'}, $f);
	return $f;
	}
return undef;
}

# list_php_configs()
# Returns a list of allowed config files and descriptions
sub list_php_configs
{
local @rv;
&get_default_php_ini();		# Force copy of sample ini file

# Add system-wide INI files
if ($access{'global'}) {
	foreach my $ai (split(/\t+/, $config{'php_ini'})) {
		local ($f, $d) = split(/=/, $ai);
		foreach my $fp (split(/,/, $f)) {
			foreach my $gf (glob($fp)) {
				push(@rv, [ $gf, $d || $text{'file_global'} ]);
				}
			}
		}
	}

# Add INI files from ACL
foreach my $ai (split(/\t+/, $access{'php_inis'})) {
	local ($f, $d) = split(/=/, $ai);
	foreach my $fp (split(/,/, $f)) {
		foreach my $gf (glob($fp)) {
			push(@rv, [ $gf, $d || $gf ]);
			}
		}
	}

# Convert dirs to files
foreach my $i (@rv) {
	if (-d $i->[0] && -r "$i->[0]/php.ini") {
		$i->[0] = "$i->[0]/php.ini";
		}
	}

# Add PHP INI files from Virtualmin
if ($access{'global'} && &foreign_check("virtual-server")) {
	&foreign_require("virtual-server");
	foreach my $v (&virtual_server::list_available_php_versions()) {
		if ($v->[0]) {
			my $ini = &virtual_server::get_global_php_ini($v->[0]);
			push(@rv, [ $ini, "PHP $v->[0]" ]) if ($ini && -r $ini);
			}
		}
	}

my %done;
return grep { !$done{$_->[0]}++ } @rv;
}

# get_php_ini_dir(file)
# Given a file like /etc/php.ini, return the include directory for additional
# .ini files that load modules, like /etc/php.d
sub get_php_ini_dir
{
my ($file) = @_;
my $file1 = $file;
my $file2 = $file;
my $file3 = $file;
$file1 =~ s/\/php.ini$/\/php.d/;
$file2 =~ s/\/php.ini$/\/conf.d/;
$file3 =~ s/\/php-fpm.conf$/\/php.d/;
return -d $file1 ? $file1 :
       -d $file2 ? $file2 :
       -d $file3 ? $file3 : undef;
}

# get_php_info(name, version)
# Returns PHP version and short version, and the binary path
sub get_php_info
{
my ($name, $version) = @_;
$version =~ s/\-.*$//;
my $bin;
foreach my $b ($name, $name."-cgi", $name."-fpm", "php-".$version) {
	if ($bin = &has_command($b)) {
		last;
		}
	}
if ($bin) {
	my $out = &backquote_command("$bin -v 2>&1");
	if ($out =~ /(^|\n)PHP\s+([\d\.]+)/) {
		$version = $2;
		}
	}
my $shortver = $version;
$shortver =~ s/^(\d+\.\d+).*$/$1/;
if ($shortver =~ /^5\./) {
	$shortver = "5";
	}
return ($version, $shortver, $bin);
}

# get_php_ini_binary(file)
# Given a php.ini path, try to guess the PHP command for it
# Examples: 
#   caller: get_php_binary_version("/etc/php/8.3/fpm/pool.d/www.conf");
#   return: /bin/php8.3
#
#   caller: get_php_binary_version("/etc/opt/remi/php81/php.ini");
#   return: /bin/php81
#
#   caller: get_php_binary_version("php7.4");
#   return: /bin/php7.4 or /bin/php74
sub get_php_ini_binary
{
my ($file) = @_;
my $ver;

# Possible php.ini under domain's home dir
if (&foreign_check("virtual-server")) {
	&foreign_require("virtual-server");
	my %vmap = map { $_->[0], $_ }
		       &virtual_server::list_available_php_versions();
	if ($file =~ /etc\/php(\S+)\/php.ini/) {
		$ver = $1;
		my $nodot = $ver;
		$nodot =~ s/\.//g;
		my $php = $vmap{$ver} || $vmap{$nodot};
		if ($php && $php->[1]) {
			my $binary = $php->[1];
			$binary =~ s/-cgi//;
			return $binary;
			}
		}
	}

# Try to get version from the path, e.g.
# RHEL and derivatives /etc/opt/remi/php83
# Debian/Ubuntu /etc/php/8.3/fpm/pool.d/www.conf
#   RHEL and derivatives   Debian/Ubuntu
if ($file =~ /php(\d+)/ || $file =~ /php\/([\d\.]+)/) {
	$ver = $1;
	my $binary = &has_command("php$ver") ||
		     &has_command("php$ver-cgi");
	return $binary if ($binary);
	}

# Given PHP version, e.g. `php7.4` as a string try to get binary
if ($file =~ /^php.*?([\d\.]+)$/) {
	$ver = $1;
	my $nodot = $ver;
	$nodot =~ s/\.//g;
	my $binary = &has_command("php$ver") ||
	             &has_command("php$nodot") ||
		     &has_command("php$ver-cgi") ||
                     &has_command("php$nodot-cgi");
	return $binary if ($binary);
	}

return $ver ? undef : &has_command("php");
}

# get_php_ini_version(file)
# Given an ini file, return the version number for it if possible
sub get_php_ini_version
{
my ($file) = @_;
my $ver;

# Try to get version from the path, e.g.
# RHEL and derivatives /etc/opt/remi/php83
# Debian/Ubuntu /etc/php/8.3/fpm/pool.d/www.conf
#   RHEL and derivatives   Debian/Ubuntu
if ($file =~ /php(\d+)/ || $file =~ /php\/([\d\.]+)/) {
	my $ver = $1;
	$ver =~ s/^(\d)(\d+)$/$1.$2/;
	return $ver;
	}

# Given PHP version, e.g. `php7.4` as a string try to get binary
if ($file =~ /^php.*?([\d\.]+)$/) {
	my $ver = $1;
	$ver =~ s/^(\d)(\d+)$/$1.$2/;
	return $ver;
	}

return undef;
}

# get_php_binary_version(file|version-string)
# Given a php.ini path or binary, try to guess the
# PHP command and extract version for it
# Examples: 
#   caller: get_php_binary_version("/etc/php/8.3/fpm/pool.d/www.conf");
#   return: 8.3.0
#   caller: get_php_binary_version("/etc/opt/remi/php81/php.ini");
#   return: 8.1.2
#   caller: get_php_binary_version("php7.4");
#   return: 7.4.33
sub get_php_binary_version
{
my ($file) = @_;
my $phpbinary = &get_php_ini_binary($file || $in{'file'});
return undef if (!$phpbinary);
my $phpver = &backquote_command("$phpbinary -v 2>&1");
if ($phpver =~ /(^|\n)PHP\s+([\d\.]+)/) {
	return $2;
	}
return undef;
}

# get_php_ini_bootup(file)
# Given an ini file, return the bootup action for it
sub get_php_ini_bootup
{
my ($file) = @_;
return undef if (!&foreign_installed("init"));
&foreign_require("init");
# Versioned PHP-FPM config, e.g. /etc/php/8.3/fpm/php.ini on Debian
# or /etc/opt/remi/php83/php-fpm.conf on EL systems
if ($file =~ /php(\d{1,2})/ || $file =~ /php\/(\d\.\d)/) {
	my $shortver = $1;
	my $nodot = $shortver;
	$nodot =~ s/\.//;
	foreach my $init ("php${shortver}-fpm",
                          "php-fpm${shortver}",
                          "rh-php${nodot}-php-fpm",
                          "php${nodot}-php-fpm") {
                my $st = &init::action_status($init);
		if ($st) {
			return $init;
			}
		}
	}
# Default /etc/php-fpm.conf config primarily on EL systems
elsif ($file =~ /\/(php-fpm)\.conf/) {
	my $init = $1;
	my $st = &init::action_status($init);
	if ($st) {
		return $init;
		}
	}
return undef;
}

# php_version_test_against(version, comparison-operator, [file|version-string])
# Given PHP version test if matches with currently installed or given
# Returns 1 if given version matches to the given and/or installed, 0 if not matches
#
# Examples:
#   caller: php_version_test_against("7.4");
#   return: 1 if version 7.4 is lower or equal to the current (current is 7.4.33)
#   -----------------------------------------------------------------------------
#   caller: php_version_test_against("7.3", undef, "/etc/opt/remi/php81/php.ini");
#   return: 0 because version 7.3 is lower and not equal to found/instaled 8.1
#   -----------------------------------------------------------------------------
#   caller: php_version_test_against("7.4.33", undef, "php7.4.33");
#   return: 1 because version 7.4.33 is lower or equal to found/instaled 7.4.33
#   -----------------------------------------------------------------------------
#   caller: php_version_test_against("7.4.33", undef, "php7.3.3");
#   return: 0 because version 7.4.33 is greater found/instaled 7.3.3
#   -----------------------------------------------------------------------------
#   caller: php_version_test_against("7.3", undef, "php7.2");
#   return: 0 because version 7.3 is greater found/instaled 7.2
#   -----------------------------------------------------------------------------
#   caller: php_version_test_against('7.4.33', '<=', 'php7.4');
#   return: 1 for version 7.4.33 because PHP 7.4 is installed and version 7.4.33
# -----------------------------------------------------------------------------
#   caller: php_version_test_against('7.4.34', '<=', 'php7.4');
#   return: 0 because version 7.4.34 is not lower or equal than intalled (7.4.33)
sub php_version_test_against
{
my ($version, $cmp, $file) = @_;
my $curr_php = &get_php_binary_version($file);
return undef if (!$curr_php);
$cmp ||= '>=';
# Normalize the base version
if ($version =~ /^\d+\.\d+$/) {
	# 7.4
	$curr_php =~ s/(\d+\.\d+)(.*)/$1/;
	}
if ($version =~ /^\d+$/) {
	# 7
	$curr_php =~ s/(\d+)(.*)/$1/;
	}
if (&compare_version_numbers($version, $cmp, $curr_php)) {
	return 1;
	}
return 0;
}

# php_version_test_minimum(version, [file|version-string])
# Returns minimum version of PHP agaisnt installed or given
sub php_version_test_minimum
{
my ($version, $file) = @_;
return &php_version_test_against($version, '<=', $file);
}

# php_version_test_maximum(version, [file|version-string])
# Returns maximum version of PHP agaisnt installed or given
sub php_version_test_maximum
{
my ($version, $file) = @_;
return &php_version_test_against($version, '>=', $file);
}

# onoff_radio(name)
# Returns a field for editing a binary configuration value
sub onoff_radio
{
local ($name) = @_;
local $v = &find_value($name, $conf);
return &ui_radio($name, lc($v) eq "on" || lc($v) eq "true" ||
			lc($v) eq "yes" || $v eq "1" ? "On" : $v ? "Off" : "",
		 [ [ "", $text{'default'} ],
		   [ "On", $text{'yes'} ],
		   [ "Off", $text{'no'} ] ]);
}

# graceful_apache_restart([file])
# Signal a graceful Apache restart, to pick up new php.ini settings
sub graceful_apache_restart
{
local ($file) = @_;
if (&foreign_installed("apache")) {
	&foreign_require("apache", "apache-lib.pl");
	if (&apache::is_apache_running() &&
	    $apache::httpd_modules{'core'} >= 2 &&
	    &has_command($apache::config{'apachectl_path'})) {
		&clean_environment();
		&system_logged("$apache::config{'apachectl_path'} graceful >/dev/null 2>&1");
		&reset_environment();
		}
	}
my $init = &get_php_ini_bootup($file);
if ($init) {
	# There's an associated FPM bootup action
	&foreign_require("init");
	&init::reload_action($init);
	}
if ($file && &get_config_fmt($file) eq "ini" &&
	&foreign_installed("virtual-server") && 
	&foreign_installed("virtualmin-nginx")) {
	&foreign_require("virtual-server");
	&foreign_require("virtualmin-nginx", "virtual_feature.pl");
	my @dom = grep { &is_under_directory($_->{'home'}, $file) } 
	              &virtual_server::list_domains();
	&virtualmin_nginx::feature_restart_web_php($dom[0])
	    if (@dom);
	}
}

# should_switch_user(file)
# Returns 1 if file ops should be done as the access user
sub should_switch_user
{
my ($file) = @_;
return $access{'user'} && $access{'user'} ne 'root' && $< == 0 &&
       !&is_under_directory("/etc", $file);
}

# get_config_as_user([file])
# Like get_config, but reads with permissions of the ACL user
sub get_config_as_user
{
local ($file) = @_;
if (&should_switch_user($file)) {
	local $rv = &eval_as_unix_user(
		$access{'user'}, sub { &get_config($file) });
	if ((!$rv || !@$rv) && $!) {
		&error(&text('file_eread', &html_escape($file), $!));
		}
	return $rv;
	}
else {
	return &get_config($file);
	}
}

# read_file_contents_as_user(file)
sub read_file_contents_as_user
{
local ($file) = @_;
if (&should_switch_user($file)) {
	return &eval_as_unix_user(
		$access{'user'}, sub { &read_file_contents($file) });
	}
else {
	return &read_file_contents($file);
	}
}

# write_file_contents_as_user(file, data)
# Writes out the contents of some file
sub write_file_contents_as_user
{
local ($file, $data) = @_;
if (&should_switch_user($file)) {
	return &eval_as_unix_user(
                $access{'user'}, sub { &write_file_contents($file, $data) });
	}
else {
	&write_file_contents($file, $data);
	}
}

# read_file_lines_as_user(file, ...)
sub read_file_lines_as_user
{
local @args = @_;
if (&should_switch_user($file)) {
	return &eval_as_unix_user(
		$access{'user'}, sub { &read_file_lines(@args) });
	}
else {
	return &read_file_lines(@args);
	}
}

# flush_file_lines_as_user(file)
# Writes out a file as the Unix user configured in this module's ACL
sub flush_file_lines_as_user
{
local ($file, $eof, $ignore) = @_;
if (&should_switch_user($file)) {
	&eval_as_unix_user($access{'user'}, 
		sub { &flush_file_lines($file, $eof, $ignore) });
	}
else {
	&flush_file_lines($file, $eof, $ignore);
	}
}

# list_available_extensions(&conf, file)
# Returns a list of all available PHP extension modules
sub list_available_extensions
{
my ($conf, $file) = @_;
my $dir = &find_value("extension_dir", $conf);
if (!$dir) {
	# Figure it out from the PHP command
	my $binary = &get_php_ini_binary($file);
	if ($binary) {
		my $out = &backquote_command("$binary -i 2>/dev/null </dev/null");
		if ($out =~ /extension_dir\s+=>\s+(\S+)/) {
			$dir = $1;
			}
		}
	}
if ($dir) {
	# Get all the extensions
	opendir(DIR, $dir);
	my @exts = grep { /\.so$/ } readdir(DIR);
	closedir(DIR);
	return @exts;
	}
return ();
}

# list_default_value(file, value, no-cache)
# Returns a list of all available PHP extension modules
sub list_default_value
{
my ($file, $value, $nocache) = @_;
my $binary = &get_php_ini_binary($file);
if ($binary) {
	my $out = $main::list_default_value_cache{$binary};
	if ($nocache || !$out) {
		# Return defaults (without using any config file)
		$out = &backquote_command("$binary --no-php-ini -i 2>/dev/null </dev/null");
		$main::list_default_value_cache{$binary} = $out;
		}
	# Get default master value
	if ($out =~ /\Q$value\E\s+\=>\s+\S+\s+\=>\s+(\S+)/) {
		return $1;
		}
	}
return undef;
}

# opt_help(text, php-opt-name)
# Returns the link to the PHP manual for some option
sub opt_help
{
my ($text, $opt) = @_;
my $opt_name = $opt;
$opt_name =~ s/_/-/g;
my $php_opt_default = &list_default_value($in{'file'}, $opt);
my $optdef = defined($php_opt_default) ? $php_opt_default : "<em>$text{'opt_default_unknown'}</em>";
$php_opt_default = "<strong>".&text('opt_default', "<br>$opt = $optdef")."</strong>";
my $link = "https://www.php.net/$opt_name";
return "@{[&ui_text_wrap($text)]}".&ui_link($link, &ui_help($php_opt_default), 'ui_link_help', 'target="_blank"');
}

sub list_known_disable_functions
{
return ( "exec", "passthru", "shell_exec", "system", "proc_open", "popen", "curl_exec", "curl_multi_exec", "parse_ini_file", "show_source", "mail" );
}

# list_php_ini_modules(dir)
# Returns a list of hash refs with details of PHP module include files in
# a directory
sub list_php_ini_modules
{
my ($dir) = @_;
my @rv;
opendir(DIR, $dir);
foreach my $f (readdir(DIR)) {
	next if ($f !~ /\.ini$/);
	my $path = "$dir/$f";
	my $ini = { 'file' => $f,
		    'path' => $path,
		    'dir' => $dir,
		  };
	# Check for the extension line
	my $lref = &read_file_lines($path, 1);
	foreach my $l (@$lref) {
		if ($l =~ /^\s*(;?)\s*(zend_)?extension\s*=\s*(\S+(\.so)?)/) {
			$ini->{'enabled'} = $1 ? 0 : 1;
			$ini->{'mod'} = $3;
			$ini->{'mod'} =~ s/\.so$//;
			}
		}
	if (-l $path) {
		# Debian-style, where the link means that the module is enabled
		$ini->{'link'} = &resolve_links($path);
		$ini->{'enabled'} = 1;
		}
	push(@rv, $ini);
	}
closedir(DIR);
my $availdir = &simplify_path("$dir/../../mods-available");
if (opendir(DIR, $availdir)) {
	# On debian, there is another directory of link destinations for all
	# modules that are available
	foreach my $f (readdir(DIR)) {
		next if ($f !~ /\.ini$/);
		my $path = "$availdir/$f";
		my ($already) = grep { $_->{'link'} eq $path } @rv;
		next if ($already);
		my $ini = { 'file' => $f,
			    'path' => $path,
			    'dir' => $dir,
			    'enabled' => 0,
			    'available' => 1,
			  };
		my $lref = &read_file_lines($path, 1);
		foreach my $l (@$lref) {
			if ($l =~ /^\s*(;?)\s*(zend_)?extension\s*=\s*(\S+(\.so)?)/) {
				$ini->{'mod'} = $3;
				$ini->{'mod'} =~ s/\.so$//;
				}
			}
		push(@rv, $ini);
		}
	closedir(DIR);
	}
return sort { $a->{'mod'} cmp $b->{'mod'} } @rv;
}

# enable_php_ini_module(&ini, enabled?)
# Enable or disable a module loaded from a php.ini include file
sub enable_php_ini_module
{
my ($ini, $enable) = @_;
return if ($ini->{'enabled'} == $enable);
if ($ini->{'link'} || $ini->{'available'}) {
	# Enable is done via a symlink
	if ($enable && $ini->{'available'}) {
		# Create the link
		my ($dis) = glob($ini->{'dir'}."/*-".$ini->{'mod'}.
				 ".ini.disabled");
		if ($dis) {
			my $newlink = $dis;
			$newlink =~ s/\.disabled$//;
			&rename_logged($dis, $newlink);
			}
		else {
			my $newlink = $ini->{'dir'}."/10-".$ini->{'mod'}.".ini";
			&symlink_logged($ini->{'path'}, $newlink);
			}
		}
	elsif (!$enable && $ini->{'link'}) {
		# Rename the link
		&rename_logged($ini->{'path'}, $ini->{'path'}.".disabled");
		}
	}
else {
	# Just edit the extension= line and comment in or out
	&lock_file($ini->{'path'});
	my $lref = &read_file_lines($ini->{'path'});
	foreach my $l (@$lref) {
		if ($enable && !$ini->{'enabled'}) {
			$l =~ s/^\s*;\s*(extension\s*=\s*(\S+)(\.so)?)/$1/;
			}
		elsif (!$enable && $ini->{'enabled'}) {
			$l =~ s/^\s*(extension\s*=\s*(\S+)(\.so)?)/;$1/;
			}
		}
	&flush_file_lines($ini->{'path'});
	&unlock_file($ini->{'path'});
	}
}

# php_module_packages(mod, version, version-from-filename)
# Returns possible package names for a given PHP module and PHP version
sub php_module_packages
{
my ($m, $fullver, $filever) = @_;
&foreign_require("software");
my $ver = $fullver;
$ver =~ s/^(\d+\.\d+)\..*$/$1/;
my $nodotphpver = $ver;
$nodotphpver =~ s/\.//;
my @poss;
if ($software::update_system eq "csw") {
	# On Solaris, packages are named like php52_mysql
	push(@poss, "php".$nodotphpver."_".$m);
	}
elsif ($software::update_system eq "ports") {
	# On FreeBSD, names are like php52-mysql
	push(@poss, "php".$nodotphpver."-".$m);
	}
else {
	if ($software::update_system eq "apt") {
		push(@poss, "php".$ver."-".$m);
		}
	else {
		push(@poss, "php".$nodotphpver."-".$m);
		push(@poss, "php".$nodotphpver."-php-pecl-".$m);
		}
	if ($software::update_system eq "apt" && $m eq "pdo_mysql") {
		# On Debian, the pdo_mysql module is in the mysql module
		push(@poss, "php".$ver."-mysql", "php-mysql");
		}
	elsif ($software::update_system eq "yum" &&
	       ($m eq "domxml" || $m eq "dom") && $ver >= 5) {
		# On Redhat, the domxml module is in php-domxml
		push(@poss, "php".$nodotphpver."-xml", "php-xml");
		}
	if ($ver =~ /\./ && $software::update_system eq "yum") {
		# PHP 5.3+ packages from software collections are
		# named like php54-php-mysql or sometimes even
		# php54-php-mysqlnd
		unshift(@poss, "php".$nodotphpver."-php-".$m);
		unshift(@poss, "rh-php".$nodotphpver."-php-".$m);
		if ($m eq "mysql") {
			unshift(@poss, "rh-php".$nodotphpver.
					   "-php-mysqlnd");
			}
		}
	elsif ($software::update_system eq "yum" &&
	       $fullphpver =~ /^5\.3/) {
		# If PHP 5.3 is being used, packages may start with
		# php53- or rh-php53-
		my @vposs = grep { /^php5-/ } @poss;
		push(@poss, map { my $p = $_;
				  $p =~ s/php5/php53/;
				  ($p, "rh-".$p) } @vposs);
		}
	unshift(@poss, "php-".$m) if (!$filever);
	}
return @poss;
}

# list_php_base_packages()
# Returns a list of hash refs, one per PHP version installed, with the
# following keys :
# name - Package name
# system - Package system
# ver - Package version
# phpver - PHP version
sub list_php_base_packages
{
&foreign_require("software");
my $n = &software::list_packages();
my @rv;
my %done;
for(my $i=0; $i<$n; $i++) {
	my $name = $software::packages{$i,'name'};
	next unless ($name =~ /^((?:rh-)?(php(?:\d[\d.]*)??)(?:-php)?-common|php\d*[\d.]*)$/);
	$name = $2 || $1;
	my ($phpver, $shortver, $bin) =
		&get_php_info($name, $software::packages{$i,'version'});
	push(@rv, { 'name' => $software::packages{$i,'name'},
		    'system' => $software::packages{$i,'system'},
		    'ver' => $software::packages{$i,'version'},
		    'shortver' => $shortver,
		    'phpver' => $phpver,
		    'binary' => $bin, });
	}
# Fill in missing binary path for the default version that is later discarded
# from the view
my %bin;
foreach my $pkg (@rv) {
	$pkg->{'binary'} ||= $bin{$pkg->{'shortver'}};
	$bin{$pkg->{'shortver'}} ||= $pkg->{'binary'};
	}
# Sort and remove duplicates
@rv = sort { $b->{'name'} cmp $a->{'name'} } @rv;
@rv = grep { !$done{$_->{'shortver'}}++ } @rv;
return sort { &compare_version_numbers($a->{'ver'}, $b->{'ver'}) } @rv;
}

# list_all_php_module_packages(base-package)
# Returns all install packages for PHP extensions of a given base package
sub list_all_php_module_packages
{
my ($base) = @_;
$base =~ s/-common$//;
my @rv;
&foreign_require("software");
my $n = &software::list_packages();
for(my $i=0; $i<$n; $i++) {
	my $name = $software::packages{$i,'name'};
	next if ($name !~ /^\Q$base\E-/);
	push(@rv, { 'name' => $name,
		    'system' => $software::packages{$i,'system'},
		    'ver' => $software::packages{$i,'version'},
		  });
	}
return @rv;
}

# list_available_php_packages()
# Returns a list of hash refs, one per PHP version available, with the
# following keys :
# name - Package name
# ver - Package version
# shortver - Short PHP version
# phpver - PHP version
sub list_available_php_packages
{
&foreign_require("package-updates");
my @rv;
foreach my $pkg (&package_updates::list_available()) {
	my $name = $pkg->{'name'};
	next unless ($name =~ /^((?:rh-)?(php(?:\d[\d.]*)??)(?:-php)?-common|php\d*[\d.]*)$/);
	$name = $2 || $1;
	# Skip the standard php-common meta package on Debian and Ubuntu, which
	# never have a dash
	next if ($pkg->{'system'} eq 'apt' &&
		 $pkg->{'name'}   eq 'php-common' &&
		 $pkg->{'version'} !~ /-/);
	my ($phpver, $shortver, $bin) = &get_php_info($name, $pkg->{'version'});
	push(@rv, { 'name' => $pkg->{'name'},
		    'ver' => $pkg->{'version'},
		    'shortver' => $shortver,
                    'phpver' => $phpver,
		  });
	}
return sort { &compare_version_numbers($a->{'ver'}, $b->{'ver'}) } @rv;
}

# list_best_available_php_packages()
# Returns the best available PHP package for the system prioritizing common
# packages on Linux distributions and normal PHP package name on FreeBSD
sub list_best_available_php_packages
{
my @rv = &list_available_php_packages();
my %best;
foreach my $pkg (@rv) {
	$best{$pkg->{'shortver'}} //= $pkg;
	$best{$pkg->{'shortver'}} = $pkg if ($pkg->{'name'} =~ /-common$/);
	}
@rv = values(%best) if (%best);
return sort { &compare_version_numbers($a->{'ver'}, $b->{'ver'}) } @rv;
}

# get_virtualmin_php_map()
# Return a hash mapping PHP versions like 5 or 7.2 to a list of domains, or
# undef if Virtualmin isn't installed
sub get_virtualmin_php_map
{
my %vmap;
&foreign_check("virtual-server") || return undef;
&foreign_require("virtual-server");
foreach my $d (&virtual_server::list_domains()) {
	my $v = $d->{'php_mode'} eq 'fpm' ? $d->{'php_fpm_version'}
					  : $d->{'php_version'};
	if ($v) {
		$vmap{$v} ||= [ ];
		push(@{$vmap{$v}}, $d);
		}
	}
return \%vmap;
}

# list_all_php_version_packages(&base-pkg)
# Returns all package names for installed packages related to one PHP package,
# such as those for extensions
sub list_all_php_version_packages
{
my ($pkg) = @_;
&foreign_require("software");
my @rv = map { $_->{'name'} }
	     &list_all_php_module_packages($pkg->{'name'});
my $base = $pkg->{'name'};
$base =~ s/-php-common$//;
$base =~ s/-common$//;
my @poss = ( $base."-runtime", $base );
foreach my $p (@poss) {
	my @info = &software::package_info($p);
	next if (!@info);
	push(@rv, $p);
	}
return @rv;
}

# extend_installable_php_packages(&packages)
# Given a list of PHP packages to install, create a new list with the version
# and name to include packages that also need to be installed, such as -cli or
# -fpm.
sub extend_installable_php_packages
{
my ($pkgs) = @_;
my @pkgs;
my @extra = ('cli', 'fpm');
foreach my $pkg (@{$pkgs}) {
	my $p = { 'name' => $pkg->{'name'},
		  'ver'  => $pkg->{'shortver'} };
	$p->{'name'} .= ' '.join(' ', map { "$1-$_" } @extra)
		if ($p->{'name'} =~ /^(.*)-common$/);
	push(@pkgs, $p);
	}
return @pkgs;
}

# delete_php_base_package(&package, &installed)
# Delete a PHP package, and return undef on success or an error on failure
sub delete_php_base_package
{
my ($pkg, $installed) = @_;
my @targets = &list_all_php_version_packages($pkg);
my $deb_want_deps = (grep { $_ eq 'php-common' } @targets) && @{$installed} > 1;
foreach my $p (@targets) {
	my @info = &software::package_info($p);
	next if (!@info);
	my $err = &software::delete_package($p,
		{ nodeps => 1,
		  purge => 1,
		  ( !$deb_want_deps ? ( depstoo => 1 ) : () ) });
	return &html_strip($err) if ($err);
	}
return undef;
}

1;

