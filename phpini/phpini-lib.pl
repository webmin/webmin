# Functions for managing the PHP configuration file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();

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
	open(CONFIG, $file) || return undef;
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
			if (/^(;?)php_admin_value\[(\S+)\]\s*=\s*(.*)/) {
				# Found an FPM config that sets a PHP variable
				push(@rv, { 'name' => $2,
					    'value' => $3,
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

# save_directive(&config, name, [value], [newsection], [neverquote])
# Updates a single entry in the PHP config file
sub save_directive
{
local ($conf, $name, $value, $newsection, $noquote) = @_;
$newsection ||= "PHP";
local $old = &find($name, $conf, 0);
local $cmt = &find($name, $conf, 1);
local $fmt = $old ? $old->{'fmt'} : @$conf ? $conf->[0]->{'fmt'} : "fpm";
local $lref;
if ($fmt eq "ini") {
	$newline = $name." = ".
		   ($value !~ /\s/ || $noquote ? $value :
		    $value =~ /"/ ? "'$value'" : "\"$value\"");
	}
else {
	$newline = "php_admin_value[".$name."] = ".$value;
	}
if (defined($value) && $old) {
	# Update existing value
	$lref = &read_file_lines($old->{'file'});
	$lref->[$old->{'line'}] = $newline;
	$old->{'value'} = $value;
	}
elsif (defined($value) && !$old && $cmt) {
	# Update existing commented value
	$lref = &read_file_lines($cmt->{'file'});
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
		$lref = &read_file_lines($lastfile);
		}
	else {
		# Just add at the end
		$lastfile = @$conf ? $conf->[0]->{'file'} : undef;
		$lastfile || &error("Don't know which file to add to");
		$lref = &read_file_lines($lastfile);
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
	$lref = &read_file_lines($old->{'file'});
	splice(@$lref, $old->{'line'}, 1);
	@$conf = grep { $_ ne $old } @$conf;
	&renumber($conf, $old->{'line'}, -1);
	}
elsif (!defined($value) && $old && !$cmt) {
	# Turn a value into a comment
	$lref = &read_file_lines($old->{'file'});
	$old->{'enabled'} = 0;
	$lref->[$old->{'line'}] = "; ".$lref->[$old->{'line'}];
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
	return $f if (-r $f);
	}
if (-r $config{'alt_php_ini'} && @inis) {
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
if ($access{'global'}) {
	foreach my $ai (split(/\t+/, $config{'php_ini'})) {
		local ($f, $d) = split(/=/, $ai);
		push(@rv, [ $f, $d || $text{'file_global'} ]);
		}
	}
foreach my $ai (split(/\t+/, $access{'php_inis'})) {
	local ($f, $d) = split(/=/, $ai);
	push(@rv, [ $f, $d || $f ]);
	}
if (&foreign_installed("virtual-server")) {
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

# onoff_radio(name)
# Returns a field for editing a binary configuration value
sub onoff_radio
{
local ($name) = @_;
local $v = &find_value($name, $conf);
return &ui_radio($name, lc($v) eq "on" || lc($v) eq "true" ||
			lc($v) eq "yes" || $v eq "1" ? "On" : $v ? "Off" : "",
		 [ !$v ? ( [ "", $text{'default'} ] ) : ( ),
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
		&virtual_server::push_all_print();
		&virtual_server::set_all_null_print();
		&virtual_server::restart_php_fpm_server();
		&virtual_server::pop_all_print();
		}
	}
}

# get_config_as_user([file])
# Like get_config, but reads with permissions of the ACL user
sub get_config_as_user
{
local ($file) = @_;
if ($access{'user'} && $access{'user'} ne 'root' && $< == 0) {
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
if ($access{'user'} && $access{'user'} ne 'root' && $< == 0) {
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
if ($access{'user'} && $access{'user'} ne 'root' && $< == 0) {
	return &eval_as_unix_user(
                $access{'user'}, sub { &write_file_contents($file, $data) });
	}
else {
	&write_file_contents($file, $data);
	}
}

# flush_file_lines_as_user(file)
# Writes out a file as the Unix user configured in this module's ACL
sub flush_file_lines_as_user
{
local ($file) = @_;
if ($access{'user'} && $access{'user'} ne 'root' && $< == 0) {
	&eval_as_unix_user($access{'user'}, 
		sub { &flush_file_lines($file) });
	}
else {
	&flush_file_lines($file);
	}
}

1;

