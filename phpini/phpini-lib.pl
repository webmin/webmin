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

# Possible php.ini under domain's home dir
if (&foreign_check("virtual-server")) {
	&foreign_require("virtual-server");
	my %vmap = map { $_->[0], $_ }
		       &virtual_server::list_available_php_versions();
	if ($file =~ /etc\/php(\S+)\/php.ini/) {
		my $ver = $1;
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
	my $ver = $1;
	my $binary = &has_command("php$ver");
	return $binary if ($binary);
	}

# Given PHP version, e.g. `php7.4` as a string try to get binary
if ($file =~ /^php.*?([\d\.]+)$/) {
	my $ver = $1;
	my $nodot = $ver;
	$nodot =~ s/\.//g;
	my $binary = &has_command("php$ver") ||
	             &has_command("php$nodot");
	return $binary if ($binary);
	}
return &has_command("php");
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
($phpver) = $phpver =~ /^PHP\s+([\d\.]+)/;
return $phpver;
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
if ($file && &get_config_fmt($file) eq "fpm" &&
    &foreign_check("virtual-server")) {
	# Looks like FPM format ... maybe a pool restart is needed
	&foreign_require("virtual-server");
	if (defined(&virtual_server::restart_php_fpm_server)) {
		my $conf;
		if (-r $file) {
			my @conf;
			@conf = grep { &is_under_directory($_->{'dir'}, $file) }
				     &virtual_server::list_php_fpm_configs();
			if (@conf) {
				$conf = &virtual_server::get_php_fpm_config(
						$conf[0]->{'shortversion'});
				}
			}
		&virtual_server::push_all_print();
		&virtual_server::set_all_null_print();
		&virtual_server::restart_php_fpm_server($conf);
		&virtual_server::pop_all_print();
		}
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

1;

