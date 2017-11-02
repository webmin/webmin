# proftpd-lib.pl
# Common functions for the proftpd server config file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# Load the site-specific information on the server executable
&read_file("$module_config_directory/site", \%site);
@ftpaccess_files = split(/\s+/, $site{'ftpaccess'});
opendir(DIR, ".");
foreach $f (readdir(DIR)) {
	if ($f =~ /^(mod_\S+)\.pl$/) {
		push(@module_files, $1);
		do $f;
		}
	}
closedir(DIR);

# get_config()
# Returns the entire proftpd config structure
sub get_config
{
if (@get_config_cache) {
	return \@get_config_cache;
	}
@get_config_cache = &get_config_file($config{'proftpd_conf'});
return \@get_config_cache;
}

# get_config_file(filename)
sub get_config_file
{
local @rv;
local $fn = $_[0];
if ($fn !~ /^\//) {
	$config{'proftpd_conf'} =~ /^(.*)\//;
	$fn = "$1/$fn";
	}
if (opendir(DIR, $fn)) {
	# Is a directory .. parse all files!
	local @files = readdir(DIR);
	closedir(DIR);
	foreach $f (@files) {
		next if ($f =~ /^\./);
		push(@rv, &get_config_file("$fn/$f"));
		}
	}
else {
	# Just a normal config file
	local $lnum = 0;
	if (open(CONF, $fn)) {
		@rv = &parse_config_file(CONF, $lnum, $fn);
		close(CONF);
		foreach $inc (&find_directive("Include", \@rv)) {
			push(@rv, &get_config_file($inc));
			}
		}
	}
return @rv;
}

# parse_config_file(handle, lines, file)
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
		last;
		}
	elsif ($line =~ /^\s*<IfModule\s+(\!?)(\S+)\.c>/i) {
		# start of an IfModule block. Read it, and if the module
		# exists put the directives in this section.
		local ($not, $mod) = ($1, $2);
		local $oldline = $_[1];
		$_[1]++;
		local @dirs = &parse_config_file($fh, $_[1], $_[2]);
		if (!$not && $httpd_modules{$mod} ||
		    $not && !$httpd_modules{$mod}) {
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
		local @dirs = &parse_config_file($fh, $_[1], $_[2]);
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
	elsif ($line =~ /^\s*<(\S+)\s*(.*)>/) {
		# start of a container directive. The first member is a dummy
		# directive at the same line as the container
		local(%dir, @members);
		%dir = ('line', $_[1],
			'file', $_[2],
			'type', 1,
			'name', $1,
			'value', $2);
		$dir{'value'} =~ s/\s+$//g;
		$dir{'words'} = &wsplit($dir{'value'});
		$_[1]++;
		@members = &parse_config_file($fh, $_[1], $_[2]);
		$dir{'members'} = \@members;
		$dir{'eline'} = $_[1]-1;
		push(@rv, \%dir);
		}
	elsif ($line =~ /^\s*(\S+)\s*(.*)$/) {
		# normal directive
		local(%dir);
		%dir = ('line', $_[1],
			'eline', $_[1],
			'file', $_[2],
			'type', 0,
			'name', $1,
			'value', $2);
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

# find_directive(name, &directives)
# Returns the values of directives matching some name
sub find_directive
{
local(@rv, $i, @vals, $dref);
foreach $ref (@{$_[1]}) {
	if (lc($ref->{'name'}) eq lc($_[0])) {
		push(@vals, $ref->{'words'}->[0]);
		}
	}
return wantarray ? @vals : !@vals ? undef : $vals[$#vals];
}

# find_directive_struct(name, &directives)
# Returns references to directives matching some name
sub find_directive_struct
{
local(@rv, $i, @vals);
foreach $ref (@{$_[1]}) {
	if (lc($ref->{'name'}) eq lc($_[0])) {
		push(@vals, $ref);
		}
	}
return wantarray ? @vals : !@vals ? undef : $vals[$#vals];
}

# find_vdirective(name, &virtualdirectives, &directives)
# Looks for some directive in a <VirtualHost> section, and then in the 
# main section
sub find_vdirective
{
if ($_[1]) {
	$rv = &find_directive($_[0], $_[1]);
	if ($rv) { return $rv; }
	}
return &find_directive($_[0], $_[2]);
}

# make_directives(ref, version, module)
sub make_directives
{
local @rv;
local $ver = $_[1];
if ($ver =~ /^(1)\.(2)(\d+)$/) {
	$ver = sprintf "%d.%d%2.2d", $1, $2, $3;
	}
foreach $d (@{$_[0]}) {
	local(%dir);
	$dir{'name'} = $d->[0];
	$dir{'multiple'} = $d->[1];
	$dir{'type'} = $d->[2];
	$dir{'module'} = $_[2];
	$dir{'version'} = $_[1];
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
local($m, $func, @rv);
local @mods = split(/\s+/, $site{'modules'});
foreach $m (@module_files) {
	if (&indexof($m, @mods) != -1) {
		$func = $m."_directives";
		push(@rv, &$func($site{'version'}));
		}
	}
@rv = grep { $_->{'type'} == $_[0] && $_->{$_[1]} } @rv;
@rv = sort { $pd = $b->{'priority'} - $a->{'priority'};
	     $md = $a->{'module'} cmp $b->{'module'};
	     $pd == 0 ? ($md == 0 ? $a->{'name'} cmp $b->{'name'} : $md) : $pd }
		@rv;
return @rv;
}

# generate_inputs(&editors, &directives)
# Displays a 2-column list of options, for use inside a table
sub generate_inputs
{
local($e, $sw, @args, @rv, $func);
foreach $e (@{$_[0]}) {
	if (!$sw) { print "<tr>\n"; }

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
	if ($rv[0] == 2) {
		# spans 2 columns..
		if ($sw) {
			# need to end this row
			print "<td colspan=2></td> </tr><tr>\n";
			}
		else { $sw = !$sw; }
		print "<td valign=top width=25%><b>$rv[1]</b></td>\n";
		print "<td nowrap valign=top colspan=3 width=75%>$rv[2]</td>\n";
		}
	else {
		# only spans one column
		print "<td valign=top width=25%><b>$rv[1]</b></td>\n";
		print "<td nowrap valign=top width=25%>$rv[2]</td>\n";
		}

	if ($sw) { print "</tr>\n"; }
	$sw = !$sw;
	}
}

# parse_inputs(&editors, &directives, &config)
# Reads user choices from a form and update the directives and config files.
sub parse_inputs
{
# First call editor functions to get new values. Each function returns
# an array of references to arrays containing the new values for the directive.
local ($i, @chname, @chval);
&before_changing();
foreach $e (@{$_[0]}) {
	local @dirs = split(/\s+/, $e->{'name'});
	local $func = "save_".join('_', @dirs);
	local @rv = &$func($e);
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
&after_changing();
}

# opt_input(value, name, default, size, [units])
sub opt_input
{
return sprintf "<input type=radio name=$_[1]_def value=1 %s> $_[2]\n".
	       "<input type=radio name=$_[1]_def value=0 %s>\n".
	       "<input name=$_[1] size=$_[3] value='%s'> %s\n",
	defined($_[0]) ? "" : "checked",
	defined($_[0]) ? "checked" : "",
	$_[0], $_[4];
}

# parse_opt(name, regexp, error)
sub parse_opt
{
local($i, $re);
if ($in{"$_[0]_def"}) { return ( [ ] ); }
for($i=1; $i<@_; $i+=2) {
	$re = $_[$i];
	if ($in{$_[0]} !~ /$re/) { &error($_[$i+1]); }
	}
return ( [ $in{$_[0]} =~ /^\S+$/ ? $in{$_[0]} : '"'.$in{$_[0]}.'"' ] );
}

# choice_input(value, name, default, [choice]+)
# Each choice is a display,value pair
sub choice_input
{
local($i, $rv);
for($i=3; $i<@_; $i++) {
	$_[$i] =~ /^([^,]*),(.*)$/;
	$rv .= sprintf "<input type=radio name=$_[1] value=\"$2\" %s> $1\n",
		lc($2) eq lc($_[0]) ||
		lc($2) eq 'on' && lc($_[0]) eq 'yes' ||
		lc($2) eq 'off' && lc($_[0]) eq 'no' ||
		!defined($_[0]) && lc($2) eq lc($_[2]) ? "checked" : "";
	}
return $rv;
}

# choice_input_vert(value, name, default, [choice]+)
# Each choice is a display,value pair
sub choice_input_vert
{
local($i, $rv);
for($i=3; $i<@_; $i++) {
	$_[$i] =~ /^([^,]*),(.*)$/;
	$rv .= sprintf "<input type=radio name=$_[1] value=\"$2\" %s> $1<br>\n",
		lc($2) eq lc($_[0]) || !defined($_[0]) &&
				       lc($2) eq lc($_[2]) ? "checked" : "";
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
local($i, $rv);
$rv = "<select name=\"$_[1]\">\n";
for($i=3; $i<@_; $i++) {
	$_[$i] =~ /^([^,]*),(.*)$/;
	$rv .= sprintf "<option value=\"$2\" %s>$1</option>\n",
		lc($2) eq lc($_[0]) || !defined($_[0]) && lc($2) eq lc($_[2]) ? "selected" : "";
	}
$rv .= "</select>\n";
return $rv;
}

# parse_choice(name, default)
sub parse_select
{
return &parse_choice(@_);
}

# config_icons(contexts, program)
# Displays up to 17 icons, one for each type of configuration directive, for
# some context (global, virtual, directory or htaccess)
sub config_icons
{
local($m, $func, $e, %etype, $i, $c);
local @mods = split(/\s+/, $site{'modules'});
local @ctx = split(/\s+/, $_[0]);
foreach $m (sort { $a cmp $b } (@module_files)) {
	if (&indexof($m, @mods) != -1) {
		$func = $m."_directives";
		foreach $e (&$func($site{'version'})) {
			foreach $c (@ctx) {
				$etype{$e->{'type'}}++ if ($e->{$c});
				}
			}
		}
        }
local (@titles, @links, @icons);
for($i=0; $text{"type_$i"}; $i++) {
	if ($etype{$i}) {
		push(@links, $_[1]."type=$i");
		push(@titles, $text{"type_$i"});
		push(@icons, "images/type_icon_$i.gif");
		}
	}
for($i=2; $i<@_; $i++) {
	push(@links, $_[$i]->{'link'});
	push(@titles, $_[$i]->{'name'});
	push(@icons, $_[$i]->{'icon'});
	}
&icons_table(\@links, \@titles, \@icons, 5);
print "<p>\n";
}

sub lock_proftpd_files
{
local $conf = &get_config();
foreach $f (&unique(map { $_->{'file'} } @$conf)) {
	&lock_file($f);
	}
}

sub unlock_proftpd_files
{
local $conf = &get_config();
foreach $f (&unique(map { $_->{'file'} } @$conf)) {
	&unlock_file($f);
	}
}

# save_directive(name, &values, &directives, &config)
# Updates the config file(s) and the directives structure with new values
# for the given directives.
# If a directive's value is merely being changed, then its value only needs
# to be updated in the directives array and in the file.
sub save_directive
{
local($i, @old, $lref, $change, $len, $v);
@old = &find_directive_struct($_[0], $_[2]);
for($i=0; $i<@old || $i<@{$_[1]}; $i++) {
	$v = ${$_[1]}[$i];
	if ($i >= @old) {
		# a new directive is being added. If other directives of this
		# type exist, add it after them. Otherwise, put it at the end of
		# the first file in the section
		if ($change) {
			# Have changed some old directive.. add this new one
			# after it, and update change
			local(%v, $j);
			%v = (	"line", $change->{'line'}+1,
				"eline", $change->{'line'}+1,
				"file", $change->{'file'},
				"type", 0,
				"name", $_[0],
				"value", $v);
			$j = &indexof($change, @{$_[2]})+1;
			&renumber($_[3], $v{'line'}, $v{'file'}, 1);
			splice(@{$_[2]}, $j, 0, \%v);
			$lref = &read_file_lines($v{'file'});
			splice(@$lref, $v{'line'}, 0, "$_[0] $v");
			$change = \%v;
			}
		else {
			# Adding a new directive to the end of the list
			# in this section
			local($f, %v, $j, $l);
			$f = $_[2]->[0]->{'file'};
			for($j=0; $_[2]->[$j]->{'file'} eq $f; $j++) { }
			$l = $_[2]->[$j-1]->{'eline'}+1;
			%v = (	"line", $l,
				"eline", $l,
				"file", $f,
				"type", 0,
				"name", $_[0],
				"value", $v);
			&renumber($_[3], $l, $f, 1);
			splice(@{$_[2]}, $j, 0, \%v);
			$lref = &read_file_lines($f);
			splice(@$lref, $l, 0, "$_[0] $v");
			}
		}
	elsif ($i >= @{$_[1]}) {
		# a directive was deleted
		$lref = &read_file_lines($old[$i]->{'file'});
		$idx = &indexof($old[$i], @{$_[2]});
		splice(@{$_[2]}, $idx, 1);
		$len = $old[$i]->{'eline'} - $old[$i]->{'line'} + 1;
		splice(@$lref, $old[$i]->{'line'}, $len);
		&renumber($_[3], $old[$i]->{'line'}, $old[$i]->{'file'}, -$len);
		}
	else {
		# just changing the value
		$lref = &read_file_lines($old[$i]->{'file'});
		$len = $old[$i]->{'eline'} - $old[$i]->{'line'} + 1;
		&renumber($_[3], $old[$i]->{'eline'}+1,
			  $old[$i]->{'file'},1-$len);
		$old[$i]->{'value'} = $v;
		$old[$i]->{'eline'} = $old[$i]->{'line'};
		splice(@$lref, $old[$i]->{'line'}, $len, "$_[0] $v");
		$change = $old[$i];
		}
	}
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

sub def
{
return $_[0] ? $_[0] : $_[1];
}

# get_virtual_config(index)
sub get_virtual_config
{
local($conf, $c, $v);
$conf = &get_config();
if (!$_[0]) { $c = $conf; $v = undef; }
else {
	$c = $conf->[$_[0]]->{'members'};
	$v = $conf->[$_[0]];
	}
return wantarray ? ($c, $v) : $c;
}

# get_ftpaccess_config(file)
sub get_ftpaccess_config
{
local($lnum, @conf);
open(FTPACCESS, $_[0]);
@conf = &parse_config_file(FTPACCESS, $lnum, $_[0]);
close(FTPACCESS);
return \@conf;
}

# get_or_create_global(&config)
# Returns an array ref of members of the <Global> section, creating if necessary
sub get_or_create_global
{
local ($conf) = @_;
local $global = &find_directive_struct("Global", $conf);
if ($global) {
	# Already exists .. just return member list
	return $global->{'members'};
	}
else {
	# Need to add it!
	local $lref = &read_file_lines($config{'proftpd_conf'});
	local $olen = @$lref;
	push(@$lref, "<Global>", "</Global>");
	&flush_file_lines();
	$global = { 'name' => 'Global',
		    'members' => [ { 'line' => $olen,
				     'eline' => $olen,
				     'file' => $config{'proftpd_conf'},
				     'type' => 0,
				     'name' => 'dummy' } ],
		    'line' => $olen,
		    'eline' => $olen+1,
		    'file' => $config{'proftpd_conf'},
		    'type' => 1,
		    'value' => undef,
		    'words' => [ ] };
	push(@{$_[0]}, $global);
	return $global->{'members'};
	}
}

# test_config()
# If possible, test the current configuration and return an error message,
# or undef.
sub test_config
{
if ($site{'version'} >= 1.2) {
	# Test the configuration with -t flag
	local $cmd = "$config{'proftpd_path'} -t -c $config{'proftpd_conf'}";
	local $out = `$cmd 2>&1 </dev/null`;
	return $out if ($?);
	}
return undef;
}

# before_changing()
# If testing all changes, backup the config files so they can be reverted
# if necessary.
sub before_changing
{
if ($config{'test_always'}) {
	local $conf = &get_config();
	local @files = &unique(map { $_->{'file'} } @$conf);
	local $/ = undef;
	foreach $f (@files) {
		if (open(BEFORE, $f)) {
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
if ($config{'test_always'}) {
	local $err = &test_config();
	if ($err) {
		# Something failed .. revert all files
		local $f;
		foreach $f (keys %before_changing) {
			&open_tempfile(AFTER, ">$f");
			&print_tempfile(AFTER, $before_changing{$f});
			&close_tempfile(AFTER);
			}
		&error(&text('eafter', "<pre>$err</pre>"));
		}
	}
}

# restart_button()
# Returns HTML for a link to put in the top-right corner of every page
sub restart_button
{
local $r = &is_proftpd_running();
return undef if ($r < 0);
local $args = "redir=".&urlize(&this_url());
if ($r) {
	$rv .= "<a href=\"apply.cgi?$args&pid=$1\">$text{'proftpd_apply'}</a><br>\n";
	$rv .= "<a href=\"stop.cgi?$args&pid=$1\">$text{'proftpd_stop'}</a>\n";
	}
else {
	$rv = "<a href=\"start.cgi?$args\">$text{'proftpd_start'}</a><br>\n";
	}
return $rv;
}

# is_proftpd_running()
# Returns the PID if ProFTPd is running, 0 if down, -1 if running under inetd
sub is_proftpd_running
{
local $conf = &get_config();
local $st = &find_directive("ServerType", $conf);
return -1 if (lc($st) eq "inetd");
local $pid = &get_proftpd_pid();
return $pid;
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

# running_under_inetd()
# Returns the inetd/xinetd object and program if ProFTPd is running under one
sub running_under_inetd
{
# Never under inetd if not set so in config
local $conf = &get_config();
local $st = &find_directive("ServerType", $conf);
return ( ) if (lc($st) eq "inetd");

local ($inet, $inet_mod);
if (&foreign_check('inetd')) {
        # Check if proftpd is in inetd
        &foreign_require('inetd', 'inetd-lib.pl');
	local $i;
        foreach $i (&foreign_call('inetd', 'list_inets')) {
                if ($i->[1] && $i->[3] eq 'ftp') {
                        $inet = $i;
                        last;
                        }
                }
        $inet_mod = 'inetd';
        }
elsif (&foreign_check('xinetd')) {
        # Check if proftpd is in xinetd
        &foreign_require('xinetd', 'xinetd-lib.pl');
	local $xi;
        foreach $xi (&foreign_call("xinetd", "get_xinetd_config")) {
                if ($xi->{'quick'}->{'disable'}->[0] ne 'yes' &&
                    $xi->{'value'} eq 'ftp') {
                        $inet = $xi;
                        last;
                        }
                }
        $inet_mod = 'xinetd';
        }
else {
        # Not supported on this OS .. assume so
        $inet = 1;
	}
return ($inet, $inet_mod);
}

# get_proftpd_pid()
sub get_proftpd_pid
{
if ($config{'pid_file'}) {
	return &check_pid_file($config{'pid_file'});
	}
else {
	local ($pid) = &find_byname("proftpd");
	return $pid;
	}
}

sub get_proftpd_version
{
local $out = `$config{'proftpd_path'} -v 2>&1`;
${$_[0]} = $out if ($_[0]);
if ($out =~ /ProFTPD\s+Version\s+(\d+)\.([0-9\.]+)/i ||
    $out =~ /ProFTPD\s+(\d+)\.([0-9\.]+)/i) {
	local ($v1, $v2) = ($1, $2);
	$v2 =~ s/\.//g;
	return "$v1.$v2";
	}
return undef;
}

# apply_configuration()
# Activate the ProFTPd configuration, either by sending a HUP signal or
# by stopping and starting
sub apply_configuration
{
# Check if running from inetd
local $conf = &get_config();
local $st = &find_directive("ServerType", $conf);
if ($st eq 'inetd') {
	return $text{'stop_einetd'};
	}
if (&get_proftpd_version() > 1.22) {
	# Stop and re-start
	local $err = &stop_proftpd();
	return $err if ($err);
	sleep(1);	# Wait for clean shutdown
	return &start_proftpd();
	}
else {
	# Can just HUP
	local $pid = &get_proftpd_pid();
	$pid || return $text{'apply_egone'};
	&kill_logged('HUP', $pid);
	return undef;
	}
}

# stop_proftpd()
# Halts the running ProFTPd process, and returns undef on success or any error
# message on failure.
sub stop_proftpd
{
# Check if running from inetd
local $conf = &get_config();
local $st = &find_directive("ServerType", $conf);
if ($st eq 'inetd') {
	return $text{'stop_einetd'};
	}
if ($config{'stop_cmd'}) {
	local $out = &backquote_logged("$config{'stop_cmd'} 2>&1 </dev/null");
	if ($?) {
		return "<pre>$out</pre>";
		}
	}
else {
	local $pid = &get_proftpd_pid();
	$pid && &kill_logged('TERM', $pid) ||
		return $text{'stop_erun'};
	}
return undef;
}

# start_proftpd()
# Attempt to start the FTP server, and return undef on success or an error
# messsage on failure.
sub start_proftpd
{
local $conf = &get_config();
local $st = &find_directive("ServerType", $conf);
if ($st eq 'inetd') {
	return $text{'start_einetd'};
	}
local $out;
if ($config{'start_cmd'}) {
	$out = &backquote_logged("$config{'start_cmd'} 2>&1 </dev/null");
	}
else {
	$out = &backquote_logged("$config{'proftpd_path'} 2>&1 </dev/null");
	}
return $? ? "<pre>$out</pre>" : undef;
}

# get_httpd_defines()
# Returns a list of defines that need to be passed to ProFTPd
sub get_httpd_defines
{
if (@get_httpd_defines_cache) {
	return @get_httpd_defines_cache;
	}
local @rv;
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

1;

