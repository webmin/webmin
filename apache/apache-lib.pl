# apache-lib.pl
# Common functions for apache configuration

BEGIN { push(@INC, ".."); };
use WebminCore;
$directive_type_count = 20;

if ($module_name ne 'htaccess') {
	&init_config();
	%access = &get_module_acl();
	@access_types = $access{'types'} eq '*' ? (0 .. $directive_type_count)
					: split(/\s+/, $access{'types'});
	}
else {
	@access_types = (0 .. $directive_type_count);
	}
map { $access_types{$_}++ } @access_types;
$site_file = ($config{'webmin_apache'} || $module_config_directory)."/site";
$httpd_info_cache = $module_config_directory."/httpd-info";

# Check if a list of supported modules needs to be built. This is done
# if the Apache binary changes, when Webmin is upgraded, or once every five
# minutes if automatic rebuilding is enabled.
if ($module_name ne 'htaccess') {
	local %oldsite;
	local $httpd = &find_httpd();
	local @st = stat($httpd);
	&read_file($site_file, \%oldsite);
	local @sst = stat($site_file);
	if ($oldsite{'path'} ne $httpd ||
	    $oldsite{'size'} != $st[7] ||
	    $oldsite{'webmin'} != &get_webmin_version() ||
	    $config{'auto_mods'} && $sst[9] < time()-5*60) {
		# Need to build list of supported modules
		local ($ver, $mods) = &httpd_info($httpd);
		if ($ver) {
			local @mods = map { "$_/$ver" } &configurable_modules();
			foreach my $m (@mods) {
				if ($m =~ /(\S+)\/(\S+)/) {
					$httpd_modules{$1} = $2;
					}
				}
			# Call again now that known modules have been set, as
			# sometimes there are dependencies due to LoadModule
			# statements in an IfModule block
			@mods = map { "$_/$ver" } &configurable_modules();
			local %site = ( 'size' => $st[7],
					'path' => $httpd,
					'modules' => join(' ', @mods),
					'webmin' => &get_webmin_version() );
			&lock_file($site_file);
			&write_file($site_file, \%site);
			chmod(0644, $site_file);
			&unlock_file($site_file);
			}
		}
	}

# Read the site-specific setup file, then require in all the module-specific
# .pl files
if (&read_file($site_file, \%site)) {
	local($m, $f, $d);
	$httpd_size = $site{'size'};
	foreach $m (split(/\s+/, $site{'modules'})) {
		if ($m =~ /(\S+)\/(\S+)/) {
			$httpd_modules{$1} = $2;
			}
		}
	foreach $m (keys %httpd_modules) {
		if (!-r "$module_root_directory/$m.pl") {
			delete($httpd_modules{$m});
			}
		}
	foreach $f (split(/\s+/, $site{'htaccess'})) {
		if (-r $f) { push(@htaccess_files, $f); }
		}
	foreach $m (keys %httpd_modules) {
		do "$m.pl";
		}
	foreach $d (split(/\s+/, $site{'defines'})) {
		$httpd_defines{$d}++;
		}
	}

$apache_docbase = $config{'apache_docbase'} ? $config{'apache_docbase'} :
		  $httpd_modules{'core'} >= 2.0 ?
			"http://httpd.apache.org/docs-2.0/mod/" :
			"http://httpd.apache.org/docs/mod/";

# parse_config_file(handle, lines, file, [recursive])
# Parses lines of text from some config file into a data structure. The
# return value is an array of references, one for each directive in the file.
# Each reference points to an associative array containing
#  line -	The line number this directive is at
#  eline -	The line number this directive ends at
#  file -	The file this directive is from
#  type -	0 for a normal directive, 1 for a container directive
#  name -	The name of this directive
#  value -	Value (possibly with spaces)
#  members -	For type 1, a reference to the array of members
#  indent -     Number of spaces before the name
sub parse_config_file
{
local($fh, @rv, $line, %dummy);
$fh = $_[0];
$dummy{'line'} = $dummy{'eline'} = $_[1]-1;
$dummy{'file'} = $_[2];
$dummy{'type'} = 0;
$dummy{'name'} = "dummy";
@rv = (\%dummy);
local %defs;
foreach my $d (&get_httpd_defines()) {
	if ($d =~ /^(\S+)=(.*)$/) {
		$defs{$1} = $2;
		}
	else {
		$defs{$d} = '';
		}
	}
while($line = <$fh>) {
	chop;
	$line =~ s/^\s*#.*$//g;
	if ($line =~ /^\s*<\/(\S+)\s*(.*)>/) {
		# end of a container directive. This can only happen in a
		# recursive call to this function
		$_[1]++;
		last if (lc($_[3]) eq lc($1));
		}
	elsif ($line =~ /^\s*<IfModule\s+(\!?)(\S+)\.c>/i ||
	       $line =~ /^\s*<IfModule\s+(\!?)(\S+)>/i) {
		# start of an IfModule block. Read it, and if the module
		# exists put the directives in this section.
		local ($not, $mod) = ($1, $2);
		local $oldline = $_[1];
		$_[1]++;
		local @dirs = &parse_config_file($fh, $_[1], $_[2], 'IfModule');
		local $altmod = $mod;
		$altmod =~ s/^(\S+)_module$/mod_$1/g;
		local $mpmmod = $mod;
		$mpmmod =~ s/^mpm_//; $mpmmod =~ s/_module$//;
		if (!$not && $httpd_modules{$mod} ||
		    $not && !$httpd_modules{$mod} ||
		    !$not && $httpd_modules{$altmod} ||
		    $not && !$httpd_modules{$altmod} ||
		    !$not && $httpd_modules{$mpmmod} ||
		    $not && !$httpd_modules{$mpmmod}
		    ) {
			# use the directives..
			push(@rv, { 'line', $oldline,
				    'eline', $oldline,
				    'file', $_[2],
				    'name', "<IfModule $not$mod>" });
			push(@rv, @dirs);
			push(@rv, { 'line', $_[1]-1,
				    'eline', $_[1]-1,
				    'file', $_[2],
				    'name', "</IfModule>" });
			}
		}
	elsif ($line =~ /^\s*<IfDefine\s+(\!?)(\S+)>/i) {
		# start of an IfDefine block. Read it, and if the define
		# exists put the directives in this section
		local ($not, $def) = ($1, $2);
		local $oldline = $_[1];
		$_[1]++;
		local @dirs = &parse_config_file($fh, $_[1], $_[2], 'IfDefine');
		if (!$not && defined($defs{$def}) ||
		    $not && !defined($defs{$def})) {
			# use the directives..
			push(@rv, { 'line', $oldline,
				    'eline', $oldline,
				    'file', $_[2],
				    'name', "<IfDefine $not$def>" });
			push(@rv, @dirs);
			push(@rv, { 'line', $_[1]-1,
				    'eline', $_[1]-1,
				    'file', $_[2],
				    'name', "</IfDefine>" });
			}
		}
	elsif ($line =~ /^\s*<IfVersion\s+(\!?)(\S*)\s*(\S+)>/i) {
		# Start of an IfVersion block. Read it, and if the version
		# matches put the directives in this section
		local ($not, $op, $ver) = ($1, $2, $3);
		local $oldline = $_[1];
		$_[1]++;
		local @dirs = &parse_config_file($fh, $_[1], $_[2], 'IfVersion');
		$op ||= "=";
		local $match = 0;
		local $myver = $httpd_modules{'core'};
		$myver =~ s/^(\d+)\.(\d)(\d+)$/$1.$2.$3/;
		if ($op eq "=" || $op eq "==") {
			if ($ver =~ /^\/(.*)\/$/) {
				$match = 1 if ($myver =~ /$1/);
				}
			else {
				$match = 1 if ($myver eq $ver);
				}
			}
		elsif ($op eq ">") {
			$match = 1 if ($myver > $ver);
			}
		elsif ($op eq ">=") {
			$match = 1 if ($myver >= $ver);
			}
		elsif ($op eq "<") {
			$match = 1 if ($myver < $ver);
			}
		elsif ($op eq "<=") {
			$match = 1 if ($myver <= $ver);
			}
		elsif ($op eq "~") {
			$match = 1 if ($myver =~ /$ver/);
			}
		$match = !$match if ($not);
		if ($match) {
			# use the directives..
			push(@rv, { 'line', $oldline,
				    'eline', $oldline,
				    'file', $_[2],
				    'name', "<IfVersion $not$op $ver>" });
			push(@rv, @dirs);
			push(@rv, { 'line', $_[1]-1,
				    'eline', $_[1]-1,
				    'file', $_[2],
				    'name', "</IfVersion>" });
			}
		}
	elsif ($line =~ /^(\s*)<(\S+)\s*(.*)>/) {
		# start of a container directive. The first member is a dummy
		# directive at the same line as the container
		local(%dir, @members);
		%dir = ('line', $_[1],
			'file', $_[2],
			'type', 1,
			'name', $2,
			'value', $3);
		local $indent = $1;
		$dir{'value'} =~ s/\s+$//g;
		$dir{'words'} = &wsplit($dir{'value'});
		$_[1]++;
		@members = &parse_config_file($fh, $_[1], $_[2], $dir{'name'});
		$dir{'members'} = \@members;
		$dir{'eline'} = $_[1]-1;
		$indent =~ s/\t/        /g;
		$dir{'indent'} = length($indent);
		push(@rv, \%dir);
		}
	elsif ($line =~ /^(\s*)(\S+)\s*(.*)$/) {
		# normal directive
		local(%dir);
		%dir = ('line', $_[1],
			'eline', $_[1],
			'file', $_[2],
			'type', 0,
			'name', $2,
			'value', $3);
		local $indent = $1;
		$indent =~ s/\t/        /g;
		$dir{'indent'} = length($indent);
		if ($dir{'value'} =~ s/\\$//g) {
			# multi-line directive!
			while($line = <$fh>) {
				chop($line);
				$cont = ($line =~ s/\\$//g);
				$dir{'value'} .= $line;
				$dir{'eline'} = ++$_[1];
				if (!$cont) { last; }
				}
			}
		$dir{'value'} =~ s/\s+$//g;
		if ($dir{'value'} =~ /^(.*)\$\{([^\}]+)\}(.*)$/) {
			# Contains a variable .. replace with define
			local $v = $defs{$2};
			if ($v) {
				$dir{'value'} = $1.$v.$3;
				}
			}
		$dir{'words'} = &wsplit($dir{'value'});
		push(@rv, \%dir);
		$_[1]++;
		}
	else {
		# blank or comment line
		$_[1]++;
		}
	}
return @rv;
}

# wsplit(string)
# Splits a string like  foo "foo \"bar\"" bazzz  into an array of words
sub wsplit
{
local($s, @rv); $s = $_[0];
$s =~ s/\\\"/\0/g;
while($s =~ /^"([^"]*)"\s*(.*)$/ || $s =~ /^(\S+)\s*(.*)$/) {
	$w = $1; $s = $2;
	$w =~ s/\0/"/g; push(@rv, $w);
	}
return \@rv;
}

# wjoin(word, word, ...)
sub wjoin
{
local(@rv, $w);
foreach $w (@_) {
	if ($w =~ /^\S+$/) { push(@rv, $w); }
	else { push(@rv, "\"$w\""); }
	}
return join(' ', @rv);
}

# find_directive(name, &directives, [1stword])
# Returns the values of directives matching some name
sub find_directive
{
local (@vals, $ref);
foreach $ref (@{$_[1]}) {
	if (lc($ref->{'name'}) eq lc($_[0])) {
		push(@vals, $_[2] ? $ref->{'words'}->[0] : $ref->{'value'});
		}
	}
return wantarray ? @vals : !@vals ? undef : $vals[$#vals];
}

# find_directive_struct(name, &directives)
# Returns references to directives matching some name
sub find_directive_struct
{
local (@vals, $ref);
foreach $ref (@{$_[1]}) {
	if (lc($ref->{'name'}) eq lc($_[0])) {
		push(@vals, $ref);
		}
	}
return wantarray ? @vals : !@vals ? undef : $vals[$#vals];
}

# find_vdirective(name, &virtualdirectives, &directives, [1stword])
# Looks for some directive in a <VirtualHost> section, and then in the 
# main section
sub find_vdirective
{
if ($_[1]) {
	$rv = &find_directive($_[0], $_[1], $_[3]);
	if ($rv) { return $rv; }
	}
return &find_directive($_[0], $_[2], $_[3]);
}

# get_config()
# Returns the entire config structure
sub get_config
{
local($acc, $res, $lnum, $conf, @virt, $v, $mref, $inc);
if (@get_config_cache) {
	return \@get_config_cache;
	}

# read primary config file
($conf) = &find_httpd_conf();
return undef if (!$conf);
my %seenfiles;
@get_config_cache = &get_config_file($conf, \%seenfiles);

# Read main resource and access config files
$lnum = 0;
$res = &find_directive("ResourceConfig", \@get_config_cache);
if (!$res) { $res = $config{'srm_conf'}; }
if (!$res) { $res = "$config{'httpd_dir'}/conf/srm.conf"; }
if (!-r &translate_filename($res)) {
	$res = "$config{'httpd_dir'}/etc/srm.conf";
	}
push(@get_config_cache, &get_config_file($res, \%seenfiles));

$lnum = 0;
$acc = &find_directive("AccessConfig", \@get_config_cache);
if (!$acc) { $acc = $config{'access_conf'}; }
if (!$acc) { $acc = "$config{'httpd_dir'}/conf/access.conf"; }
if (!-r &translate_filename($acc)) {
	$acc = "$config{'httpd_dir'}/etc/access.conf";
	}
push(@get_config_cache, &get_config_file($acc, \%seenfiles));

# Read extra config files in VirtualHost sections
@virt = &find_directive_struct("VirtualHost", \@get_config_cache);
foreach $v (@virt) {
	my %seenfiles;
	$mref = $v->{'members'};
	foreach $idn ("ResourceConfig", "AccessConfig", "Include", "IncludeOptional") {
		foreach $inc (&find_directive_struct($idn, $mref)) {
			local @incs = &expand_apache_include(
					$inc->{'words'}->[0]);
			foreach my $ginc (@incs) {
				push(@$mref, &get_config_file($ginc,
							      \%seenfiles));
				}
			}
		}
	}

return \@get_config_cache;
}

# get_config_file(filename, [&seen-files])
# Returns a list of config hash refs from some file
sub get_config_file
{
my ($file, $seen) = @_;

# Convert sites-enabled to real path in sites-available
$file = &simplify_path(&resolve_links($file));
return ( ) if ($seen && $seen->{$file}++);
local @rv;
if (opendir(DIR, $file)) {
	# Is a directory .. parse all files!
	local @files = readdir(DIR);
	closedir(DIR);
	foreach my $f (sort { $a cmp $b } @files) {
		next if ($f =~ /^\./);
		push(@rv, &get_config_file("$file/$f", $seen));
		}
	}
else {
	# Just a normal config file
	local $lnum = 0;
	&open_readfile(CONF, $file);
	@rv = &parse_config_file(CONF, $lnum, $file);
	close(CONF);
	}

# Expand Include directives
foreach $inc (&find_directive_struct("Include", \@rv),
	      &find_directive_struct("IncludeOptional", \@rv)) {
	local @incs = &expand_apache_include($inc->{'words'}->[0]);
	foreach my $ginc (@incs) {
		push(@rv, &get_config_file($ginc, $seen));
		}
	}

return @rv;
}

# expand_apache_include(dir)
# Given an include directive value, returns a list of matching files
sub expand_apache_include
{
local ($incdir) = @_;
if ($incdir !~ /^\//) { $incdir = "$config{'httpd_dir'}/$incdir"; }
if ($incdir =~ /^(.*)\[\^([^\]]+)\](.*)$/) {
	# A glob like /etc/[^.#]*.conf , which cannot be handled
	# by Perl's glob function!
	local $before = $1;
	local $after = $3;
	local %reject = map { $_, 1 } split(//, $2);
	$reject{'*'} = $reject{'?'} = $reject{'['} = $reject{']'} =
	  $reject{'/'} = $reject{'$'} = $reject{'('} = $reject{')'} =
	  $reject{'!'} = 1;
	local $accept = join("", grep { !$reject{$_} } map { chr($_) } (32 .. 126));
	$incdir = $before."[".$accept."]".$after;
	}
return sort { $a cmp $b } glob($incdir);
}

# get_virtual_config(index|name)
# Returns the Apache config block with some index in the main config, or name
sub get_virtual_config
{
local ($name) = @_;
local $conf = &get_config();
local ($c, $v);
if (!$name) {
	# Whole config
	$c = $conf;
	$v = undef;
	}
elsif ($name =~ /^\d+$/) {
	# By index
	$c = $conf->[$name]->{'members'};
	$v = $conf->[$name];
	}
else {
	# Find by name, in servername:port format
	my ($sn, $sp) = split(/:/, $name);
	VHOST: foreach my $virt (&find_directive_struct("VirtualHost", $conf)) {
		local $vp = $virt->{'words'}->[0] =~ /:(\d+)$/ ? $1 : 80;
		next if ($vp != $sp);
		local $vn = &find_directive("ServerName", $virt->{'members'});
		if (lc($vn) eq lc($sn) || lc($vn) eq lc("www.".$sn)) {
			$c = $virt->{'members'};
			$v = $virt;
			last VHOST;
			}
		foreach my $n (&find_directive_struct("ServerAlias",
						      $virt->{'members'})) {
			local @lcw = map { lc($_) } @{$n->{'words'}};
			if (&indexof($sn, @lcw) >= 0 ||
			    &indexof("www.".$sn, @lcw) >= 0) {
				$c = $virt->{'members'};
				$v = $virt;
				last VHOST;
				}
			}
		}
	}
return wantarray ? ($c, $v) : $c;
}

# get_htaccess_config(file)
sub get_htaccess_config
{
local($lnum, @conf);
&open_readfile(HTACCESS, $_[0]);
@conf = &parse_config_file(HTACCESS, $lnum, $_[0]);
close(HTACCESS);
return \@conf;
}

# save_directive(name, &values, &parent-directives, &config, [always-at-end])
# Updates the config file(s) and the directives structure with new values
# for the given directives.
# If a directive's value is merely being changed, then its value only needs
# to be updated in the directives array and in the file.
sub save_directive
{
local($i, @old, $lref, $change, $len, $v);
@old = &find_directive_struct($_[0], $_[2]);
local @files;
for($i=0; $i<@old || $i<@{$_[1]}; $i++) {
	$v = ${$_[1]}[$i];
	if ($i >= @old) {
		# a new directive is being added. If other directives of this
		# type exist, add it after them. Otherwise, put it at the end of
		# the first file in the section
		if ($change && !$_[4]) {
			# Have changed some old directive.. add this new one
			# after it, and update change
			local(%v, $j);
			%v = (	"line", $change->{'line'}+1,
				"eline", $change->{'line'}+1,
				"file", $change->{'file'},
				"type", 0,
				"name", $_[0],
				"value", $v,
				"words", &wsplit($v) );
			$j = &indexof($change, @{$_[2]})+1;
			&renumber($_[3], $v{'line'}, $v{'file'}, 1);
			splice(@{$_[2]}, $j, 0, \%v);
			$lref = &read_file_lines($v{'file'});
			push(@files, $v{'file'});
			splice(@$lref, $v{'line'}, 0, "$_[0] $v");
			$change = \%v;
			}
		else {
			# Adding a new directive to the end of the list
			# in this section
			local($f, %v, $j);
			$f = $_[2]->[0]->{'file'};
			for($j=0; $_[2]->[$j]->{'file'} eq $f; $j++) { }
			$lref = &read_file_lines($f);
			if ($_[2] eq $_[3]) {
				# Top-level, so add to the end of the file
				$l = scalar(@$lref) + 1;
				}
			else {
				# Add after last directive in the same section
				$l = $_[2]->[$j-1]->{'eline'}+1;
				}
			%v = (	"line", $l,
				"eline", $l,
				"file", $f,
				"type", 0,
				"name", $_[0],
				"value", $v,
				"words", &wsplit($v) );
			&renumber($_[3], $l, $f, 1);
			splice(@{$_[2]}, $j, 0, \%v);
			push(@files, $f);
			splice(@$lref, $l, 0, "$_[0] $v");
			}
		}
	elsif ($i >= @{$_[1]}) {
		# a directive was deleted
		$lref = &read_file_lines($old[$i]->{'file'});
		push(@files, $old[$i]->{'file'});
		$idx = &indexof($old[$i], @{$_[2]});
		splice(@{$_[2]}, $idx, 1);
		$len = $old[$i]->{'eline'} - $old[$i]->{'line'} + 1;
		splice(@$lref, $old[$i]->{'line'}, $len);
		&renumber($_[3], $old[$i]->{'line'}, $old[$i]->{'file'}, -$len);
		}
	else {
		# just changing the value
		$lref = &read_file_lines($old[$i]->{'file'});
		push(@files, $old[$i]->{'file'});
		$len = $old[$i]->{'eline'} - $old[$i]->{'line'} + 1;
		&renumber($_[3], $old[$i]->{'eline'}+1,
			  $old[$i]->{'file'},1-$len);
		$old[$i]->{'value'} = $v;
		$old[$i]->{'words'} = &wsplit($v);
		$old[$i]->{'eline'} = $old[$i]->{'line'};
		splice(@$lref, $old[$i]->{'line'}, $len,
			(" " x $old[$i]->{'indent'}).$_[0]." ".$v);
		$change = $old[$i];
		}
	}
return &unique(@files);
}

# save_directive_struct(&old-directive, &directive, &parent-directives,
#			&config, [firstline-only])
# Updates, creates or removes only multi-line directive like a <virtualhost>
sub save_directive_struct
{
local ($olddir, $newdir, $pconf, $conf, $first) = @_;
return if (!$olddir && !$newdir);	# Nothing to do
local $file = $olddir ? $olddir->{'file'} :
	      $newdir->{'file'} ? $newdir->{'file'} : $pconf->[0]->{'file'};
local $lref = &read_file_lines($file);
local $oldlen = $olddir ? $olddir->{'eline'}-$olddir->{'line'}+1 : undef;
local @newlines = $newdir ? &directive_lines($newdir) : ( );
if ($olddir && $newdir) {
	# Update in place
	if ($first) {
		# Just changing first and last line, like virtualhost IP
		$lref->[$olddir->{'line'}] = $newlines[0];
		$lref->[$olddir->{'eline'}] = $newlines[$#newlines];
		$olddir->{'name'} = $newdir->{'name'};
		$olddir->{'value'} = $newdir->{'value'};
		}
	else {
		# Re-writing whole block
		&renumber($conf, $olddir->{'eline'}+1, $file,
			  scalar(@newlines)-$oldlen);
		local $idx = &indexof($olddir, @$pconf);
		$pconf->[$idx] = $newdir if ($idx >= 0);
		$newdir->{'file'} = $olddir->{'file'};
		$newdir->{'line'} = $olddir->{'line'};
		$newdir->{'eline'} = $olddir->{'line'}+scalar(@newlines)-1;
		splice(@$lref, $olddir->{'line'}, $oldlen, @newlines);

		# Update sub-directive lines and files too
		if ($newdir->{'type'}) {
			&recursive_set_lines_files($newdir->{'members'},
						   $newdir->{'line'}+1,
						   $newdir->{'file'});
			}
		}
	}
elsif ($olddir && !$newdir) {
	# Remove
	splice(@$lref, $olddir->{'line'}, $oldlen);
	local $idx = &indexof($olddir, @$pconf);
	splice(@$pconf, $idx, 1) if ($idx >= 0);
	&renumber($conf, $olddir->{'line'}, $olddir->{'file'}, -$oldlen);
	}
elsif (!$olddir && $newdir) {
	# Add to file, at end of specific file or parent section
	local ($addline, $addpos);
	if ($newdir->{'file'}) {
		$addline = scalar(@$lref);
		$addpos = scalar(@$pconf);
		}
	else {
		for($addpos=0; $addpos < scalar(@$pconf) &&
			       $pconf->[$addpos]->{'file'} eq $file;
		    $addpos++) {
			# Find last parent directive in same file
			}
		$addpos--;
		$addline = $pconf->[$addpos]->{'eline'}+1;
		}
	$newdir->{'file'} = $file;
	$newdir->{'line'} = $addline;
	$newdir->{'eline'} = $addline + scalar(@newlines) - 1;
	&renumber($conf, $addline, $file, scalar(@newlines));
	splice(@$pconf, $addpos, 0, $newdir);
	splice(@$lref, $addline, 0, @newlines);

	# Update sub-directive lines and files too
	if ($newdir->{'type'}) {
		&recursive_set_lines_files($newdir->{'members'},
					   $newdir->{'line'}+1,
					   $newdir->{'file'});
		}
	}
}

# recursive_set_lines_files(&directives, first-line, file)
# Update the line numbers and filenames in a list of directives
sub recursive_set_lines_files
{
my ($dirs, $line, $file) = @_;
foreach my $dir (@$dirs) {
	$dir->{'line'} = $line;
	$dir->{'file'} = $file;
	if ($dir->{'type'}) {
		# Do sub-members too
		&recursive_set_lines_files($dir->{'members'}, $line+1, $file);
		$line += scalar(@{$dir->{'members'}})+1;
		$dir->{'eline'} = $line;
		}
	else {
		$dir->{'eline'} = $line;
		}
	$line++;
	}
return $line;
}

# delete_file_if_empty(file)
# If a virtual host file is now empty, delete it (and any link to it)
sub delete_file_if_empty
{
local ($file) = @_;
local $lref = &read_file_lines($file, 1);
foreach my $l (@$lref) {
	return 0 if ($l =~ /\S/);
	}
&unflush_file_lines($file);
unlink($file);
&delete_webfile_link($file);
}

# renumber(&config, line, file, offset)
# Recursively changes the line number of all directives from some file 
# beyond the given line.
sub renumber
{
local($d);
if (!$_[3]) { return; }
foreach $d (@{$_[0]}) {
	if ($d->{'file'} eq $_[2] && $d->{'line'} >= $_[1]) {
		$d->{'line'} += $_[3];
		}
	if ($d->{'file'} eq $_[2] && $d->{'eline'} >= $_[1]) {
		$d->{'eline'} += $_[3];
		}
	if ($d->{'type'}) {
		&renumber($d->{'members'}, $_[1], $_[2], $_[3]);
		}
	}
}

# server_root(path)
# Convert a relative path to being under the server root
sub server_root
{
if (!$_[0]) { return undef; }
elsif ($_[0] =~ /^\//) { return $_[0]; }
else { return "$config{'httpd_dir'}/$_[0]"; }
}

sub dump_config
{
local($c, $mref);
print "<table border>\n";
print "<tr> <td>Name</td> <td>Value</td> <td>File</td> <td>Line</td> </tr>\n";
foreach $c (@_) {
	printf "<tr> <td>%s</td> <td>%s</td><td>%s</td><td>%s</td> </tr>\n",
		$c->{'name'}, $c->{'value'}, $c->{'file'}, $c->{'line'};
	if ($c->{'type'}) {
		print "<tr> <td colspan=4>\n";
		$mref = $c->{'members'};
		&dump_config(@$mref);
		print "</td> </tr>\n";
		}
	}
print "</table>\n";
}

sub def
{
return $_[0] ? $_[0] : $_[1];
}

# make_directives(ref, version, module)
sub make_directives
{
local(@rv, $aref);
$aref = $_[0];
local $ver = $_[1];
if ($ver =~ /^(1)\.(3)(\d+)$/) {
	$ver = sprintf "%d.%d%2.2d", $1, $2, $3;
	}
foreach $d (@$aref) {
	local(%dir);
	$dir{'name'} = $d->[0];
	$dir{'multiple'} = $d->[1];
	$dir{'type'} = int($d->[2]);
	$dir{'subtype'} = $d->[2] - $dir{'type'};
	$dir{'module'} = $_[2];
	$dir{'version'} = $ver;
	$dir{'priority'} = $d->[5];
	foreach $c (split(/\s+/, $d->[3])) { $dir{$c}++; }
	if (!$d->[4]) { push(@rv, \%dir); }
	elsif ($d->[4] =~ /^-([\d\.]+)$/ && $ver < $1) { push(@rv, \%dir); }
	elsif ($d->[4] =~ /^([\d\.]+)$/ && $ver >= $1) { push(@rv, \%dir); }
	elsif ($d->[4] =~ /^([\d\.]+)-([\d\.]+)$/ && $ver >= $1 && $ver < $2)
		{ push(@rv, \%dir); }
	}
return @rv;
}


# editable_directives(type, context)
# Returns an array of references to associative arrays, one for each 
# directive of the given type that can be used in the given context
sub editable_directives
{
local($m, $func, @rv, %done);
foreach $m (keys %httpd_modules) {
	$func = $m."_directives";
	if (defined(&$func)) {
		push(@rv, &$func($httpd_modules{$m}));
		}
	}
@rv = grep { $_->{'type'} == $_[0] && $_->{$_[1]} &&
	     !$done{$_->{'name'}}++ } @rv;
@rv = grep { &can_edit_directive($_->{'name'}) } @rv;
@rv = sort { local $td = $a->{'subtype'} <=> $b->{'subtype'};
	     local $pd = $b->{'priority'} <=> $a->{'priority'};
	     local $md = $a->{'module'} cmp $b->{'module'};
	     $td ? $td : $pd ? $pd : $md ? $md : $a->{'name'} cmp $b->{'name'} }
		@rv;
return @rv;
}

# can_edit_directive(name)
# Returns 1 if the Apache directive named can be edited by the current user
sub can_edit_directive
{
local ($name) = @_;
if ($access{'dirsmode'} == 0) {
	return 1;
	}
else {
	local %dirs = map { lc($_), 1 } split(/\s+/, $access{'dirs'});
	if ($access{'dirsmode'} == 1) {
		return $dirs{lc($name)};
		}
	else {
		return !$dirs{lc($name)};
		}
	}
}

# generate_inputs(&editors, &directives, [&skip])
# Displays a 2-column list of options, for use inside a table
sub generate_inputs
{
local($e, $sw, @args, @rv, $func, $lastsub);
foreach $e (@{$_[0]}) {
	if (defined($lastsub) && $lastsub != $e->{'subtype'}) {
		print &ui_table_hr();
		}
	$lastsub = $e->{'subtype'};

	# Build arg list for the editing function. Each arg can be a single
	# directive struct, or a reference to an array of structures.
	$func = "edit";
	undef(@args);
	foreach $ed (split(/\s+/, $e->{'name'})) {
		local(@vals);
		$func .= "_$ed";
		@vals = &find_directive_struct($ed, $_[1]);
		if ($e->{'multiple'}) { push(@args, \@vals); }
		elsif (!@vals) { push(@args, undef); }
		else { push(@args, $vals[$#vals]); }
		}
	push(@args, $e);

	# call the function
	@rv = &$func(@args);
	local $names;
	if ($config{'show_names'} || $userconfig{'show_names'}) {
		$names = " (";
		foreach $ed (split(/\s+/, $e->{'name'})) {
			# nodo50 v0.1 - Change 000004 - Open new window for Help in Apache module and mod_apachessl Help from http://www.apache-ssl.org and
			# nodo50 v0.1 - Change 000004 - Abre nueva ventana para Ayuda del módulo Apache y para mod_apachessl busca la Ayuda en http://www.apache-ssl.org and
			$names .= "<tt>".&ui_link( ($e->{'module'} eq 'mod_apachessl' ? 'http://www.apache-ssl.org/docs.html#'.$ed : $apache_docbase."/".$e->{'module'}.".html#".lc($ed)), $ed )."</tt>&nbsp;";
			#$names .= "<tt><a href='".$apache_docbase."/".$e->{'module'}.".html#".lc($ed)."'>".$ed."</a></tt> ";
			# nodo50 v0.1 - Change 000004 - End
			}
		$names .= ")";
		}
	if ($rv[0] >= 2) {
		# spans 2 columns..
		if ($rv[0] == 3) {
			# Takes up whole row
			print &ui_table_row(undef, $rv[2], 4);
			}
		else {
			# Has title on left
			print &ui_table_row($rv[1], $rv[2], 3);
			}
		}
	else {
		# only spans one column
		print &ui_table_row($rv[1], $rv[2]);
		}
	}
}

# parse_inputs(&editors, &directives, &config)
# Reads user choices from a form and update the directives and config files.
sub parse_inputs
{
# First call editor functions to get new values. Each function returns
# an array of references to arrays containing the new values for the directive.
&before_changing();
&lock_apache_files();
foreach $e (@{$_[0]}) {
	@dirs = split(/\s+/, $e->{'name'});
	$func = "save_".join('_', @dirs);
	@rv = &$func($e);
	for($i=0; $i<@dirs; $i++) {
		push(@chname, $dirs[$i]);
		push(@chval, $rv[$i]);
		}
	}

# Assuming everything went OK, update the configuration
for($i=0; $i<@chname; $i++) {
	&save_directive($chname[$i], $chval[$i], $_[1], $_[2]);
	}
&flush_file_lines();
&unlock_apache_files();
&after_changing();
}

# opt_input(value, name, default, size)
sub opt_input
{
return &ui_opt_textbox($_[1], $_[0], $_[3], $_[2]);
}

# parse_opt(name, regexp, error, [noquotes])
sub parse_opt
{
local($i, $re);
local $v = $in{$_[0]};
if ($in{"$_[0]_def"}) { return ( [ ] ); }
for($i=1; $i<@_; $i+=2) {
	$re = $_[$i];
	if ($v !~ /$re/) { &error($_[$i+1]); }
	}
return ( [ $v =~ /\s/ && !$_[3] ? "\"$v\"" : $v ] );
}

# choice_input(value, name, default, [choice]+)
# Each choice is a display,value pair
sub choice_input
{
my($i, $rv);
for($i=3; $i<@_; $i++) {
	$_[$i] =~ /^([^,]*),(.*)$/;
	$rv .= &ui_oneradio($_[1], $2, $1, lc($2) eq lc($_[0]) ||
				!defined($_[0]) && lc($2) eq lc($_[2]))."\n";
	}
return $rv;
}

# choice_input_vert(value, name, default, [choice]+)
# Each choice is a display,value pair
sub choice_input_vert
{
my($i, $rv);
for($i=3; $i<@_; $i++) {
	$_[$i] =~ /^([^,]*),(.*)$/;
	$rv .= &ui_oneradio($_[1], $2, $1, lc($2) eq lc($_[0]) ||
				!defined($_[0]) && lc($2) eq lc($_[2]))."<br>\n";
	}
return $rv;
}

# parse_choice(name, default)
sub parse_choice
{
if (lc($in{$_[0]}) eq lc($_[1])) { return ( [ ] ); }
else { return ( [ $in{$_[0]} ] ); }
}

# select_input(value, name, default, [choice]+)
sub select_input
{
my($i, @sel);
my $selv;
for($i=3; $i<@_; $i++) {
	$_[$i] =~ /^([^,]*),(.*)$/;
	if (lc($2) eq lc($_[0]) || !defined($_[0]) && lc($2) eq lc($_[2])) {
		$selv = $2;
		}
	push(@sel, [ $2, $1 || "&nbsp;" ]);
	}
return &ui_select($_[1], $selv, \@sel, 1);
}

# parse_choice(name, default)
sub parse_select
{
return &parse_choice(@_);
}

# handler_input(value, name)
sub handler_input
{
my($m, $func, @hl, @sel, $h);
my $conf = &get_config();
push(@hl, "");
foreach $m (keys %httpd_modules) {
	$func = $m."_handlers";
	if (defined(&$func)) {
		push(@hl, &$func($conf, $httpd_modules{$m}));
		}
	}
if (&indexof($_[0], @hl) < 0) { push(@hl, $_[0]); }
foreach $h (&unique(@hl)) {
    push(@sel, [$h, $h, ($h eq $_[0] ? "selected" : "")] );
	}
push(@sel, ["None", "&lt;".$text{'core_none'}."&gt;", ($_[0] eq "None" ? "selected" : "")] );
return &ui_select($_[1], undef, \@sel, 1);
}

# parse_handler(name)
sub parse_handler
{
if ($in{$_[0]} eq "") { return ( [ ] ); }
else { return ( [ $in{$_[0]} ] ); }
}

# filters_input(&values, name)
sub filters_input
{
local($m, $func, @fl, $rv, $f);
local $conf = &get_config();
foreach $m (keys %httpd_modules) {
	$func = $m."_filters";
	if (defined(&$func)) {
		push(@fl, &$func($conf, $httpd_modules{$m}));
		}
	}
foreach $f (@{$_[0]}) {
	push(@fl, $f) if (&indexof($f, @fl) < 0);
	}
foreach $f (&unique(@fl)) {
    $rv .= &ui_checkbox($_[1], $f, $f, (&indexof($f, @{$_[0]}) < 0 ? 0 : 1 ) ); 
	}
return $rv;
}

# parse_filters(name)
sub parse_filters
{
local @f = split(/\0/, $in{$_[0]});
return @f ? ( [ join(";", @f) ] ) : ( [ ] );
}



# virtual_name(struct, [forlog])
sub virtual_name
{
if ($_[0]) {
	local $n = &find_directive("ServerName", $_[0]->{'members'});
	if ($n) {
		return &html_escape($_[0]->{'value'} =~ /:(\d+)$/ ? "$n:$1"
								  : $n);
		}
	else {
		return &html_escape(
			$_[0]->{'value'} =~ /^\[(\S+)\]$/ ? $1 :
			$_[0]->{'value'} =~ /^\[(\S+)\]:(\d+)$/ ? "$1:$2" :
				$_[0]->{'value'});
		}
	}
else { return $_[1] ? "*" : $text{'default_serv'}; }
}

# dir_name(struct)
# Given a <directory> or similar structure, return a human-readable description
sub dir_name
{
$_[0]->{'name'} =~ /^(Directory|Files|Location|Proxy)(Match)?$/;
my ($dfm, $mat) = ($1, $2);
if ($dfm eq "Proxy" && !$mat && $_[0]->{'words'}->[0] eq "*") {
	# Proxy for all
	return $text{'dir_proxyall'};
	}
elsif ($mat) {
	# Match-type directive
	return "$dfm regexp <tt>".&html_escape($_[0]->{'words'}->[0])."</tt>";
	}
elsif ($_[0]->{'words'}->[0] eq "~") {
	# Regular expression
	return "$dfm regexp <tt>".&html_escape($_[0]->{'words'}->[1])."</tt>";
	}
else {
	# Exact match
	return "$dfm <tt>".&html_escape($_[0]->{'words'}->[0])."</tt>";
	}
}

# list_user_file(file, &user,  &pass)
sub list_user_file
{
local($_);
&open_readfile(USERS, $_[0]);
while(<USERS>) {
	/^(\S+):(\S+)/;
	push(@{$_[1]}, $1); $_[2]->{$1} = $2;
	}
close(USERS);
}


# config_icons(context, program)
# Displays up to 18 icons, one for each type of configuration directive, for
# some context (global, virtual, directory or htaccess)
sub config_icons
{
local ($ctx, $prog) = @_;
local($m, $func, $e, %etype, $i, $c);
foreach $m (sort { $a cmp $b } (keys %httpd_modules)) {
        $func = $m."_directives";
	if (defined(&$func)) {
		foreach $e (&$func($httpd_modules{$m})) {
			if ($e->{$ctx}) { $etype{$e->{'type'}}++; }
			}
		}
        }
local (@titles, @links, @icons);
for($i=0; $text{"type_$i"}; $i++) {
	if ($etype{$i} && $access_types{$i}) {
		push(@links, $prog."type=$i");
		push(@titles, $text{"type_$i"});
		push(@icons, "images/type_icon_$i.gif");
		}
	}
for($i=2; $i<@_; $i++) {
	if ($_[$i]) {
		push(@links, $_[$i]->{'link'});
		push(@titles, $_[$i]->{'name'});
		push(@icons, $_[$i]->{'icon'});
		}
	}
&icons_table(\@links, \@titles, \@icons, 5);
print "<p>\n";
}

# restart_button()
# Returns HTML for a link to put in the top-right corner of every page
sub restart_button
{
local $rv;
$args = "redir=".&urlize(&this_url());
local @rv;
if (&is_apache_running()) {
	if ($access{'apply'}) {
		push(@rv, &ui_link("restart.cgi?$args", $text{'apache_apply'}) );
		}
	if ($access{'stop'}) {
		push(@rv, &ui_link("stop.cgi?$args", $text{'apache_stop'}) );
		}
	}
elsif ($access{'stop'}) {
	push(@rv, &ui_link("start.cgi?$args", $text{'apache_start'}) );
	}
return join("<br>\n", @rv);
}

# this_url()
# Returns the URL in the apache directory of the current script
sub this_url
{
local($url);
$url = $ENV{'SCRIPT_NAME'};
if ($ENV{'QUERY_STRING'} ne "") { $url .= "?$ENV{'QUERY_STRING'}"; }
return $url;
}

# find_all_directives(config, name)
# Recursively finds all directives of some type
sub find_all_directives
{
local(@rv, $d);
foreach $d (@{$_[0]}) {
	if ($d->{'name'} eq $_[1]) { push(@rv, $d); }
	if ($d->{'type'} == 1) {
		push(@rv, &find_all_directives($d->{'members'}, $_[1]));
		}
	}
return @rv;
}

# httpd_info(executable)
# Returns the httpd version and modules array
sub httpd_info
{
local ($cmd) = @_;
$cmd = &has_command($cmd);
local @st = stat($cmd);
local %cache;
&read_file_cached($httpd_info_cache, \%cache);
if ($cache{'cmd'} eq $cmd && $cache{'time'} == $st[9]) {
	# Cache looks up to date
	return ($cache{'version'}, [ split(/\s+/, $cache{'mods'}) ]);
	}
local(@mods, $verstr, $ver, $minor);
$verstr = &backquote_command(quotemeta($cmd)." -v 2>&1");
if ($config{'httpd_version'}) {
	$config{'httpd_version'} =~ /(\d+)\.([\d\.]+)/;
	$ver = $1; $minor = $2; $minor =~ s/\.//g; $ver .= ".$minor";
	}
elsif ($verstr =~ /Apache(\S*)\/(\d+)\.([\d\.]+)/) {
	# standard apache
	$ver = $2; $minor = $3; $minor =~ s/\.//g; $ver .= ".$minor";
	}
elsif ($verstr =~ /HP\s*Apache-based\s*Web\s*Server(\S*)\/(\d+)\.([\d\.]+)/) {
	# HP's apache
	$ver = $2; $minor = $3; $minor =~ s/\.//g; $ver .= ".$minor";
	}
elsif ($verstr =~ /Red\s*Hat\s+Secure\/2\.0/i) {
	# redhat secure server 2.0
	$ver = 1.31;
	}
elsif ($verstr =~ /Red\s*Hat\s+Secure\/3\.0/i) {
	# redhat secure server 3.0
	$ver = 1.39;
	}
elsif (&has_command("rpm") &&
       &backquote_command("rpm -q apache 2>&1") =~ /^apache-(\d+)\.([\d\.]+)/) {
	# got version from the RPM
	$ver = $1; $minor = $2; $minor =~ s/\.//g; $ver .= ".$minor";
	}
else {
	# couldn't get version
	return (0, undef);
	}
if ($ver < 1.2) {
	# apache 1.1 has no -l option! Use the standard list
	@mods = ("core", "mod_mime", "mod_access", "mod_auth", "mod_include",
		 "mod_negotiation", "mod_dir", "mod_cgi", "mod_userdir",
		 "mod_alias", "mod_env", "mod_log_common");
	}
else {
	# ask apache for the module list
	@mods = ("core");
	&open_execute_command(APACHE, "\"$_[0]\" -l 2>/dev/null", 1);
	while(<APACHE>) {
		if (/(\S+)\.c/) { push(@mods, $1); }
		}
	close(APACHE);
	if ($?) {
		# httpd crashed! Use last known good set of modules
		local %oldsite;
		&read_file($site_file, \%oldsite);
		if ($oldsite{'modules'}) {
			@mods = split(/\s+/, $oldsite{'modules'});
			}
		}
	@mods = &unique(@mods);
	}
$cache{'cmd'} = $cmd;
$cache{'time'} = $st[9];
$cache{'version'} = $ver;
$cache{'mods'} = join(" ", @mods);
&write_file($httpd_info_cache, \%cache);
return ($ver, \@mods);
}

# print_line(directive, text, indent, link)
sub print_line
{
local $line = $_[0]->{'line'} + 1;
local $lstr = "$_[0]->{'file'} ($line)";
local $txt = join("", @{$_[1]});
local $left = 85 - length($lstr) - $_[2];
if (length($txt) > $left) {
	$txt = substr($txt, 0, $left)." ..";
	}
local $txtlen = length($txt);
$txt = &html_escape($txt);
print " " x $_[2];
if ($_[3]) {
	print &ui_link($_[3], $txt);
	}
else { print $txt; }
print " " x (90 - $txtlen - $_[2] - length($lstr));
print $lstr,"\n";
}

# can_edit_virt(struct)
sub can_edit_virt
{
return 1 if ($access{'virts'} eq '*');
local %vcan = map { $_, 1 } split(/\s+/, $access{'virts'});
local ($can) = grep { $vcan{$_} } &virt_acl_name($_[0]);
return $can ? 1 : 0;
}

# virt_acl_name(struct)
# Give a virtual host, returns a list of names that could be used in the ACL
# to refer to it
sub virt_acl_name
{
return ( "__default__" ) if (!$_[0]);
local $n = &find_directive("ServerName", $_[0]->{'members'});
local @rv;
local $p;
if ($_[0]->{'value'} =~ /(:\d+)/) { $p = $1; }
if ($n) {
	push(@rv, $n.$p);
	}
else {
	push(@rv, $_[0]->{'value'});
	}
foreach $n (&find_directive_struct("ServerAlias", $_[0]->{'members'})) {
	local $a;
	foreach $a (@{$n->{'words'}}) {
		push(@rv, $a.$p);
		}
	}
return @rv;
}

# allowed_auth_file(file)
sub allowed_auth_file
{
local $_;
return 1 if ($access{'dir'} eq '/');
return 0 if ($_[0] =~ /\.\./);
local $f = &server_root($_[0], &get_config());
return 0 if (-l $f && !&allowed_auth_file(readlink($f)));
local $l = length($access{'dir'});
return length($f) >= $l && substr($f, 0, $l) eq $access{'dir'};
}

# directory_exists(file)
# Returns 1 if the directory in some path exists
sub directory_exists
{
local $path = &server_root($_[0], &get_config());
if ($path =~ /^(\S*\/)([^\/]+)$/) {
	return -d $1;
	}
else {
	return 0;
	}
}

# allowed_doc_dir(dir)
# Returns 1 if some directory is under the allowed root for alias targets
sub allowed_doc_dir
{
return $access{'aliasdir'} eq '/' ||
       $_[0] !~ /^\// ||	# Relative path, like for <Files>
       &is_under_directory($access{'aliasdir'}, $_[0]);
}

sub lock_apache_files
{
local $conf = &get_config();
local $f;
@main::locked_apache_files = &unique(map { $_->{'file'} } @$conf);
foreach $f (@main::locked_apache_files) {
	&lock_file($f);
	}
}

sub unlock_apache_files
{
local $conf = &get_config();
local $f;
foreach $f (@main::locked_apache_files) {
	&unlock_file($f);
	}
@main::locked_apache_files = ( );
}

# directive_lines(directive, ...)
sub directive_lines
{
local @rv;
foreach $d (@_) {
	next if ($d->{'name'} eq 'dummy');
	if ($d->{'type'}) {
		push(@rv, "<$d->{'name'} $d->{'value'}>");
		push(@rv, &directive_lines(@{$d->{'members'}}));
		push(@rv, "</$d->{'name'}>");
		}
	else {
		push(@rv, "$d->{'name'} $d->{'value'}");
		}
	}
return @rv;
}

# test_config()
# If possible, test the current configuration and return an error message,
# or undef.
sub test_config
{
if ($httpd_modules{'core'} >= 1.301) {
	# Test the configuration with the available command
	local $cmd;
	if ($config{'test_apachectl'} &&
	    -x &translate_filename($config{'apachectl_path'})) {
		# Test with apachectl
		$cmd = "\"$config{'apachectl_path'}\" configtest";
		}
	else {
		# Test with httpd
		local $httpd = &find_httpd();
		$cmd = "\"$httpd\" -d \"$config{'httpd_dir'}\" -t";
		if ($config{'httpd_conf'}) {
			$cmd .= " -f \"$config{'httpd_conf'}\"";
			}
		foreach $d (&get_httpd_defines()) {
			$cmd .= " -D$d";
			}
		}
	local $out = &backquote_command("$cmd 2>&1");
	if ($out && $out !~ /(syntax|Checking).*\s+ok/i) {
		return $out;
		}
	}
return undef;
}

# before_changing()
# If testing all changes, backup the config files so they can be reverted
# if necessary.
sub before_changing
{
if ($config{'test_always'} || $access{'test_always'}) {
	local $conf = &get_config();
	local @files = &unique(map { $_->{'file'} } @$conf);
	local $/ = undef;
	local $f;
	foreach $f (@files) {
		if (&open_readfile(BEFORE, $f)) {
			$before_changing{$f} = <BEFORE>;
			close(BEFORE);
			}
		}
	}
}

# after_changing()
# If testing all changes, test now and revert the configs and show an error
# message if a problem was found.
sub after_changing
{
if ($config{'test_always'} || $access{'test_always'}) {
	local $err = &test_config();
	if ($err) {
		# Something failed .. revert all files
		&rollback_apache_config();
		&error(&text('eafter', "<pre>$err</pre>"));
		}
	}
}

# rollback_apache_config()
# Copy back all config files from their originals
sub rollback_apache_config
{
local $f;
foreach $f (keys %before_changing) {
	&open_tempfile(AFTER, ">$f");
	&print_tempfile(AFTER, $before_changing{$f});
	&close_tempfile(AFTER);
	}
}

# find_httpd_conf()
# Returns the path to the http.conf file, and the last place looked
# (without any translation).
sub find_httpd_conf
{
local $conf = $config{'httpd_conf'};
return ( -f &translate_filename($conf) ? $conf : undef, $conf ) if ($conf);
$conf = "$config{'httpd_dir'}/conf/httpd.conf";
$conf = "$config{'httpd_dir'}/conf/httpd2.conf"
	if (!-f &translate_filename($conf));
$conf = "$config{'httpd_dir'}/etc/httpd.conf"
	if (!-f &translate_filename($conf));
$conf = "$config{'httpd_dir'}/etc/httpd2.conf"
	if (!-f &translate_filename($conf));
$conf = undef if (!-f &translate_filename($conf));
return ( $conf, "$config{'httpd_dir'}/conf/httpd.conf" );
}

# find_httpd()
# Returns the path to the httpd executable, by appending '2' if necessary
sub find_httpd
{
return $config{'httpd_path'}
	if (-x &translate_filename($config{'httpd_path'}) &&
	    !-d &translate_filename($config{'httpd_path'}));
return $config{'httpd_path'}.'2'
	if (-x &translate_filename($config{'httpd_path'}.'2') &&
	    !-d &translate_filename($config{'httpd_path'}.'2'));
return undef;
}

# get_pid_file()
# Returns the path to the PID file (without any translation)
sub get_pid_file
{
return $config{'pid_file'} if ($config{'pid_file'});
local $conf = &get_config();
local $pidfilestr = &find_directive_struct("PidFile", $conf);
local $pidfile = $pidfilestr ? $pidfilestr->{'words'}->[0]
		       	     : "logs/httpd.pid";
return &server_root($pidfile, $conf);
}

# restart_apache()
# Re-starts Apache, and returns undef on success or an error message on failure
sub restart_apache
{
local $pidfile = &get_pid_file();
if ($config{'apply_cmd'} eq 'restart') {
	# Call stop and start functions
	local $err = &stop_apache();
	return $err if ($err);
	local $stopped = &wait_for_apache_stop();
	local $err = &start_apache();
	return $err if ($err);
	}
elsif ($config{'apply_cmd'}) {
	# Use the configured start command
	&clean_environment();
	local $out = &backquote_logged("$config{'apply_cmd'} 2>&1");
	&reset_environment();
	&wait_for_graceful() if ($config{'apply_cmd'} =~ /graceful/);
	if ($?) {
		return "<pre>".&html_escape($out)."</pre>";
		}
	}
elsif (-x &translate_filename($config{'apachectl_path'})) {
	# Use apachectl to restart
	if ($httpd_modules{'core'} >= 2) {
		# Do a graceful restart
		&clean_environment();
		local $out = &backquote_logged(
			"$config{'apachectl_path'} graceful 2>&1");
		&reset_environment();
		&wait_for_graceful();
		if ($?) {
			return "<pre>".&html_escape($out)."</pre>";
			}
		}
	else {
		&clean_environment();
		local $out = &backquote_logged(
			"$config{'apachectl_path'} restart 2>&1");
		&reset_environment();
		if ($out !~ /httpd restarted/) {
			return "<pre>".&html_escape($out)."</pre>";
			}
		}
	}
else {
	# send SIGHUP directly
	&open_readfile(PID, $pidfile) || return &text('restart_epid', $pidfile);
	<PID> =~ /(\d+)/ || return &text('restart_epid2', $pidfile);
	close(PID);
	&kill_logged('HUP', $1) || return &text('restart_esig', $1);
	&wait_for_graceful();
	}
return undef;
}

# wait_for_graceful([timeout])
# Wait for some time for Apache to complete a graceful restart
sub wait_for_graceful
{
local $timeout = $_[0] || 10;
local $errorlog = &get_error_log();
return -1 if (!$errorlog || !-r $errorlog);
local @st = stat($errorlog);
my $start = time();
while(time() - $start < $timeout) {
	sleep(1);
	open(ERRORLOG, $errorlog);
	seek(ERRORLOG, $st[7], 0);
	local $/ = undef;
	local $rest = <ERRORLOG>;
	close(ERRORLOG);
	if ($rest =~ /resuming\s+normal\s+operations/i) {
		return 1;
		}
	}
return 0;
}

# stop_apache()
# Attempts to stop the running Apache process, and returns undef on success or
# an error message on failure
sub stop_apache
{
local $out;
if ($config{'stop_cmd'}) {
	# use the configured stop command
	$out = &backquote_logged("($config{'stop_cmd'}) 2>&1");
	if ($?) {
		return "<pre>".&html_escape($out)."</pre>";
		}
	}
elsif (-x $config{'apachectl_path'}) {
	# use the apachectl program
	$out = &backquote_logged("($config{'apachectl_path'} stop) 2>&1");
	if ($httpd_modules{'core'} >= 2 ? $? : $out !~ /httpd stopped/) {
		return "<pre>".&html_escape($out)."</pre>";
		}
	}
else {
	# kill the process
	$pidfile = &get_pid_file();
	open(PID, $pidfile) || return &text('stop_epid', $pidfile);
	<PID> =~ /(\d+)/ || return &text('stop_epid2', $pidfile);
	close(PID);
	&kill_logged('TERM', $1) || return &text('stop_esig', $1);
	}
return undef;
}

# start_apache()
# Attempts to start Apache, and returns undef on success or an error message
# upon failure.
sub start_apache
{
local ($out, $cmd);
&clean_environment();
if ($config{'start_cmd'}) {
	# use the configured start command
	if ($config{'stop_cmd'}) {
		# execute the stop command to clear lock files
		&system_logged("($config{'stop_cmd'}) >/dev/null 2>&1");
		}
	$out = &backquote_logged("($config{'start_cmd'}) 2>&1");
	&reset_environment();
	if ($?) {
		return "<pre>".&html_escape($out)."</pre>";
		}
	}
elsif (-x $config{'apachectl_path'}) {
	# use the apachectl program
	$cmd = "$config{'apachectl_path'} start";
	$out = &backquote_logged("($cmd) 2>&1");
	&reset_environment();
	}
else {
	# start manually
	local $httpd = &find_httpd();
	$cmd = "$httpd -d $config{'httpd_dir'}";
	if ($config{'httpd_conf'}) {
		$cmd .= " -f $config{'httpd_conf'}";
		}
	foreach $d (&get_httpd_defines()) {
		$cmd .= " -D$d";
		}
	local $temp = &transname();
	local $rv = &system_logged("( $cmd ) >$temp 2>&1 </dev/null");
	$out = &read_file_contents($temp);
	unlink($temp);
	&reset_environment();
	}

# Check if Apache may have failed to start
local $slept;
if ($out =~ /\S/ && $out !~ /httpd\s+started/i) {
	sleep(3);
	if (!&is_apache_running()) {
		return "<pre>".&html_escape($cmd)." :\n".
			       &html_escape($out)."</pre>";
		}
	$slept = 1;
	}

# check if startup was successful. Later apache version return no
# error code, but instead fail to start and write the reason to
# the error log file!
sleep(3) if (!$slept);
local $conf = &get_config();
if (!&is_apache_running()) {
	# Not running..  find out why
	local $errorlogstr = &find_directive_struct("ErrorLog", $conf);
	local $errorlog = $errorlogstr ? $errorlogstr->{'words'}->[0]
				       : "logs/error_log";
	if ($out =~ /\S/) {
		return "$text{'start_eafter'} : <pre>$out</pre>";
		}
	elsif ($errorlog eq 'syslog' || $errorlog =~ /^\|/) {
		return $text{'start_eunknown'};
		}
	else {
		$errorlog = &server_root($errorlog, $conf);
		$out = `tail -5 $errorlog`;
		return "$text{'start_eafter'} : <pre>$out</pre>";
		}
	}
return undef;
}

# get_error_log()
# Returns the path to the global error log, if possible
sub get_error_log
{
local $conf = &get_config();
local $errorlogstr = &find_directive_struct("ErrorLog", $conf);
local $errorlog = $errorlogstr ? $errorlogstr->{'words'}->[0]
			       : "logs/error_log";
$errorlog = &server_root($errorlog, $conf);
return $errorlog;
}

sub is_apache_running
{
if ($gconfig{'os_type'} eq 'windows') {
	# No such thing as a PID file on Windows
	local ($pid) = &find_byname("Apache.exe");
	return $pid;
	}
else {
	# Check PID file
	local $pidfile = &get_pid_file();
	return &check_pid_file($pidfile);
	}
}

# wait_for_apache_stop([secs])
# Wait 30 (by default) seconds for Apache to stop. Returns 1 if OK, 0 if not
sub wait_for_apache_stop
{
local $secs = $_[0] || 30;
for(my $i=0; $i<$secs; $i++) {
	return 1 if (!&is_apache_running());
	sleep(1);
	}
return 0;
}

# configurable_modules()
# Returns a list of Apaches that are compiled in or dynamically loaded, and
# supported by Webmin.
sub configurable_modules
{
local ($ver, $mods) = &httpd_info(&find_httpd());
local @rv;
local $m;

# Add compiled-in modules
foreach $m (@$mods) {
	if (-r "$module_root_directory/$m.pl") {
		push(@rv, $m);
		}
	}

# Add dynamically loaded modules
local $conf = &get_config();
foreach $l (&find_directive_struct("LoadModule", $conf)) {
	if ($l->{'words'}->[1] =~ /(mod_\S+)\.(so|dll)/ &&
	    -r "$module_root_directory/$1.pl") {
		push(@rv, $1);
		}
	elsif ($l->{'words'}->[1] =~ /libssl\.so/ &&
	       -r "$module_root_directory/mod_apachessl.pl") {
		push(@rv, "mod_apachessl");
		}
	elsif ($l->{'words'}->[1] =~ /lib([^\/\s]+)\.(so|dll)/ &&
	       -r "$module_root_directory/mod_$1.pl") {
		push(@rv, "mod_$1");
		}
	}
undef(@get_config_cache);	# Cache is no longer valid

# Add dynamically loaded modules
if ($config{'apachectl_path'}) {
	&open_execute_command(APACHE,
		"$config{'apachectl_path'} -M 2>/dev/null", 1);
	while(<APACHE>) {
		if (/(\S+)_module/ && -r "$module_root_directory/mod_${1}.pl") {
			push(@rv, "mod_${1}");
			}
		}
	close(APACHE);
	}

return &unique(@rv);
}

# get_httpd_defines(automatic-only)
# Returns a list of defines that need to be passed to Apache
sub get_httpd_defines
{
local ($auto) = @_;
if (@get_httpd_defines_cache) {
	return @get_httpd_defines_cache;
	}
local @rv;
if (!$auto) {
	push(@rv, keys %httpd_defines);
	}
if ($config{'defines_file'}) {
	# Add defines from an environment file, which can be in
	# the format :
	# OPTIONS='-Dfoo -Dbar'
	# or regular name=value format
	local %def;
	&read_env_file($config{'defines_file'}, \%def);
	if ($config{'defines_name'} && $def{$config{'defines_name'}}) {
		# Looking for var like OPTIONS='-Dfoo -Dbar'
		local $var = $def{$config{'defines_name'}};
		foreach my $v (split(/\s+/, $var)) {
			if ($v =~ /^-[Dd](\S+)$/) {
				push(@rv, $1);
				}
			else {
				push(@rv, $v);
				}
			}
		}
	else {
		# Looking for regular name=value directives.
		# Remove $SUFFIX variable seen on debian that is computed
		# dynamically, but is usually empty.
		foreach my $k (keys %def) {
			$def{$k} =~ s/\$SUFFIX//g;
			push(@rv, $k."=".$def{$k});
			}
		}
	}
foreach my $md (split(/\t+/, $config{'defines_mods'})) {
	# Add HAVE_ defines from modules
	opendir(DIR, $md);
	while(my $m = readdir(DIR)) {
		if ($m =~ /^(mod_|lib)(.*).so$/i) {
			push(@rv, "HAVE_".uc($2));
			}
		}
	closedir(DIR);
	}
foreach my $d (split(/\s+/, $config{'defines'})) {
	push(@rv, $d);
	}
@get_httpd_defines_cache = @rv;
return @rv;
}

# create_webfile_link(file)
# Creates a link in the debian-style link directory for a new website's file
sub create_webfile_link
{
local ($file) = @_;
if ($config{'link_dir'}) {
	local $short = $file;
	$short =~ s/^.*\///;
	local $linksrc = "$config{'link_dir'}/$short";
	&lock_file($linksrc);
	symlink($file, $linksrc);
	&unlock_file($linksrc);
	}
}

# delete_webfile_link(file)
# If the given path is in a directory like /etc/apache2/sites-available, delete
# the link to it from /etc/apache2/sites-enabled
sub delete_webfile_link
{
local ($file) = @_;
if ($config{'link_dir'}) {
	local $short = $file;
	$short =~ s/^.*\///;
	opendir(LINKDIR, $config{'link_dir'});
	foreach my $f (readdir(LINKDIR)) {
		if ($f ne "." && $f ne ".." &&
		    (&simplify_path(
		       &resolve_links($config{'link_dir'}."/".$f)) eq $file ||
		     $short eq $f)) {
			&unlink_logged($config{'link_dir'}."/".$f);
			}
		}
	closedir(LINKDIR);
	}
}

# can_configure_apache_modules()
# Returns 1 if the distro has a way of selecting enabled Apache modules
sub can_configure_apache_modules
{
if ($gconfig{'os_type'} eq 'debian-linux') {
	# Debian and Ubuntu use an /etc/apacheN/mods-enabled dir
	return -d "$config{'httpd_dir'}/mods-enabled" &&
	       -d "$config{'httpd_dir'}/mods-available";
	}
else {
	return 0;
	}
}

# list_configured_apache_modules()
# Returns a list of all Apache modules. Each is a hash containing a mod and
# enabled, disabled and available flags.
sub list_configured_apache_modules
{
if ($gconfig{'os_type'} eq 'debian-linux') {
	# Find enabled modules
	local @rv;
	local $edir = "$config{'httpd_dir'}/mods-enabled";
	opendir(EDIR, $edir);
	foreach my $f (readdir(EDIR)) {
		if ($f =~ /^(\S+)\.load$/) {
			push(@rv, { 'mod' => $1, 'enabled' => 1 });
			}
		}
	closedir(EDIR);

	# Add available modules
	local $adir = "$config{'httpd_dir'}/mods-available";
	opendir(ADIR, $adir);
	foreach my $f (readdir(ADIR)) {
		if ($f =~ /^(\S+)\.load$/) {
			local ($got) = grep { $_->{'mod'} eq $1 } @rv;
			if (!$got) {
				push(@rv, { 'mod' => $1, 'disabled' => 1 });
				}
			}
		}
	closedir(ADIR);

	# XXX modules from apt-get

	return sort { $a->{'mod'} cmp $b->{'mod'} } @rv;
	}
else {
	# Not supported
	return ( );
	}
}

# add_configured_apache_module(module)
# Updates the Apache configuration to use some module. Returns undef on success,
# or an error message on failure.
sub add_configured_apache_module
{
local ($mod) = @_;
if ($gconfig{'os_type'} eq 'debian-linux') {
	# XXX download from apt-get ?

	# Enable with a2enmod if installed
	if (&has_command("a2enmod")) {
		local $out = &backquote_logged(
				"a2enmod ".quotemeta($mod)." 2>&1");
		return $? ? $out : undef;
		}
	else {
		# Fall back to creating links
		local $adir = "$config{'httpd_dir'}/mods-available";
		local $edir = "$config{'httpd_dir'}/mods-enabled";
		opendir(ADIR, $adir);
		foreach my $f (readdir(ADIR)) {
			if ($f =~ /^\Q$mod->{'mod'}\E\./) {
				&symlink_logged("$adir/$f", "$edir/$f") ||
					return $!;
				}
			}
		closedir(ADIR);
		return undef;
		}
	}
else {
	return "Operating system does not support Apache modules";
	}
}

# remove_configured_apache_module(module)
# Updates the Apache configuration to stop using some module. Returns undef
# on success, or an error message on failure.
sub remove_configured_apache_module
{
local ($mod) = @_;
if ($gconfig{'os_type'} eq 'debian-linux') {
	# Disable with a2dismod if installed
	if (&has_command("a2dismod")) {
		local $out = &backquote_logged(
				"a2dismod ".quotemeta($mod)." 2>&1");
		return $? ? $out : undef;
		}
	else {
		# Fall back to removing links
		local $edir = "$config{'httpd_dir'}/mods-enabled";
		opendir(EDIR, $edir);
		foreach my $f (readdir(EDIR)) {
			if ($f =~ /^\Q$mod->{'mod'}\E\./) {
				&unlink_logged("$edir/$f");
				}
			}
		closedir(EDIR);
		return undef;
		}
	}
else {
	return "Operating system does not support Apache modules";
	}
}

# is_virtualmin_domain(&virt)
# Returns the domain hash if some virtualhost is managed by Virtualmin
sub is_virtualmin_domain
{
local ($virt) = @_;
return 0 if ($config{'allow_virtualmin'});
local $n = &find_directive("ServerName", $virt->{'members'});
return undef if (!$n);
return undef if (!&foreign_check("virtual-server"));
&foreign_require("virtual-server");
local $d = &virtual_server::get_domain_by("dom", $n);
return $d if ($d);
$n =~ s/^www\.//i;
local $d = &virtual_server::get_domain_by("dom", $n);
return $d;
}

1;

