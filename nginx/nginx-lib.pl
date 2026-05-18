# Common functions for Nginx config file

use strict;
use warnings;
no warnings 'recursion';
use Socket;

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
our %access = &get_module_acl();
our ($get_config_cache, $get_config_parent_cache, %list_directives_cache,
     @list_modules_cache, @open_config_files);
our (%config, %text, %in, $module_root_directory);
&set_nginx_config_defaults();

my @lock_all_config_files_cache;

# set_nginx_config_defaults()
# Fill in sensible defaults if module config has not been initialized yet
sub set_nginx_config_defaults
{
my $conf = &detect_nginx_config_file();
if ($conf && (!$config{'nginx_config'} || !-r $config{'nginx_config'})) {
	$config{'nginx_config'} = $conf;
	}

my $cmd = &detect_nginx_command();
if ($cmd && (!$config{'nginx_cmd'} || !&has_command($config{'nginx_cmd'}))) {
	$config{'nginx_cmd'} = $cmd;
	}

if (!$config{'start_cmd'} || !$config{'stop_cmd'} || !$config{'apply_cmd'}) {
	if (&has_command("systemctl")) {
		$config{'start_cmd'} ||= "systemctl start nginx";
		$config{'stop_cmd'} ||= "systemctl stop nginx";
		$config{'apply_cmd'} ||= "systemctl reload nginx";
		}
	elsif (&has_command("service")) {
		$config{'start_cmd'} ||= "service nginx start";
		$config{'stop_cmd'} ||= "service nginx stop";
		$config{'apply_cmd'} ||= "service nginx reload";
		}
	elsif ($config{'nginx_cmd'}) {
		$config{'start_cmd'} ||= $config{'nginx_cmd'};
		$config{'stop_cmd'} ||= $config{'nginx_cmd'}." -s stop";
		$config{'apply_cmd'} ||= $config{'nginx_cmd'}." -s reload";
		}
	}
}

# detect_nginx_config_file()
# Returns the first readable standard Nginx config file
sub detect_nginx_config_file
{
foreach my $file ($config{'nginx_config'},
		  "/etc/nginx/nginx.conf",
		  "/usr/local/nginx/conf/nginx.conf",
		  "/opt/nginx/conf/nginx.conf") {
	return $file if ($file && -r $file);
	}
return undef;
}

# detect_nginx_command()
# Returns the first executable Nginx command in a standard path or PATH
sub detect_nginx_command
{
return $config{'nginx_cmd'}
	if ($config{'nginx_cmd'} && &has_command($config{'nginx_cmd'}));
foreach my $cmd ("nginx", "/usr/sbin/nginx", "/usr/local/nginx/sbin/nginx",
		 "/opt/nginx/sbin/nginx") {
	my $found = &has_command($cmd);
	return $found if ($found);
	}
return undef;
}

# get_config()
# Parses the Nginx config file into an array ref
sub get_config
{
if (!$get_config_cache) {
	$get_config_cache = &read_config_file($config{'nginx_config'});
	}
return $get_config_cache;
}

# get_config_parent()
# Returns an object that represents the whole config file
sub get_config_parent
{
if (!$get_config_parent_cache) {
	$get_config_parent_cache = { 'members' => &get_config(),
				     'type' => 1,
				     'file' => $config{'nginx_config'},
				     'indent' => -1,
				     'line' => 0,
				     'eline' => 0 };
	foreach my $c (@{$get_config_parent_cache->{'members'}}) {
		if ($c->{'file'} eq $get_config_parent_cache->{'file'} &&
		    $c->{'eline'} > $get_config_parent_cache->{'eline'}) {
			$get_config_parent_cache->{'eline'} = $c->{'eline'}+1;
			}
		}
	}
return $get_config_parent_cache;
}

# flush_config_cache()
# Delete all in-memory config caches
sub flush_config_cache
{
undef($get_config_parent_cache);
undef($get_config_cache);
}

# remove_hash_comment(line)
# Returns the line with comments removed
sub remove_hash_comment
{
my ($l) = @_;
if ($l =~ /".*#.*"/) {
	# Comment inside quotes, so only remove any comment outside quotes
	$l =~ s/#[^"]*$//;
	}
else {
	# Remove all comments
	$l =~ s/#.*$//;
	}
return $l;
}

# read_config_file(file, [preserve-includes])
# Returns an array ref of nginx config objects
sub read_config_file
{
my ($file, $noinc) = @_;
my $link = &resolve_links($file);
$link || &error("Dangling link $file");
$file = $link;
my @rv = ( );
my $addto = \@rv;
my @stack = ( );
my $lnum = 0;
my $fh = "CFILE".int(rand(1000000));
&open_readfile($fh, $file) || return [];
my @lines = <$fh>;
close($fh);
while(@lines) {
	my $l = shift(@lines);
	$l = &remove_hash_comment($l);
	my ($indent_str) = $l =~ /^(\s*)/;
	my $slnum = $lnum;

	# If line doesn't end with { } or ; , it must be continued on the
	# next line
	while($l =~ /\S/ && $l !~ /[\{\}\;]\s*$/ && @lines) {
		my $nl = shift(@lines);
		if ($nl =~ /\S/) {
			$nl = &remove_hash_comment($nl);
			$l .= " ".$nl;
			}
		$lnum++;
		}

	if ($l =~ /^\s*if\s*\((.*)\)\s*\{\s*$/) {
		# Start of an if statement
		my $ns = { 'name' => 'if',
			   'type' => 2,
			   'indent' => scalar(@stack),
			   'indent_str' => $indent_str,
			   'file' => $file,
			   'line' => $slnum,
			   'eline' => $lnum,
			   'members' => [ ] };
		my $value = $1;
		&set_split_words($ns, " ".$value);
		push(@stack, $addto);
		push(@$addto, $ns);
		$addto = $ns->{'members'};
		}
	elsif ($l =~ /^\s*(\S+)(\s*.*)\{\s*$/) {
		# Start of a section
		my $ns = { 'name' => $1,
			   'type' => 1,
			   'indent' => scalar(@stack),
			   'indent_str' => $indent_str,
			   'file' => $file,
			   'line' => $slnum,
			   'eline' => $lnum,
			   'members' => [ ] };
		my $value = $2;
		&set_split_words($ns, $value);
		push(@stack, $addto);
		push(@$addto, $ns);
		$addto = $ns->{'members'};
		}
	elsif ($l =~ /^\s*}/ && @stack) {
		# End of a section
		$addto = pop(@stack);
		$addto->[@$addto-1]->{'eline'} = $lnum;
		}
	elsif ($l =~ /^\s*(\S+)((\s+("([^"]*)"|'([^']*)'|[^ ;]+))*)\s*;/) {
		# Found a directive
		my ($name, $value) = ($1, $2);
		my @words = &split_words($value);
		if ($name eq "include" && !$noinc) {
			# Include a file or glob
			if ($words[0] !~ /^\//) {
				my $filedir = $file;
				$filedir =~ s/\/[^\/]+$//;
				$words[0] = $filedir."/".$value;
				}
			foreach my $ifile (glob($words[0])) {
				my $inc = &read_config_file($ifile);
				push(@$addto, @$inc);
				}
			}
		else {
			# Some directive in the current section
			my ($sep_str) = $l =~ /^\s*\S+(\s+)/;
			my $dir = { 'name' => $name,
				    'value' => $words[0],
				    'words' => \@words,
				    'type' => 0,
				    'indent' => scalar(@stack),
				    'indent_str' => $indent_str,
				    'sep_str' => $sep_str,
				    'file' => $file,
				    'line' => $slnum,
				    'eline' => $lnum };
			push(@$addto, $dir);
                        if (@stack) {
                                my $lastaddto = $stack[$#stack];
                                $lastaddto->[@$lastaddto - 1]->{'eline'} = $lnum;
                                }
			}
		}
	elsif ($l =~ /\S/) {
		$l =~ s/\r|\n//g;
		print STDERR "Invalid Nginx config line $l at $lnum in $file\n";
		}
	$lnum++;
	}
return \@rv;
}

# extra_dirs_to_directives(directives)
# Parses tab-separated extra directives from module config into Nginx objects
sub extra_dirs_to_directives
{
my ($extra_dirs) = @_;
return ( ) if (!$extra_dirs || $extra_dirs eq "none");

my $temp = &transname();
my $fh = "EXTRA";
&open_tempfile($fh, ">$temp", 0, 1);
&print_tempfile($fh, join("\n", split(/\t+/, $extra_dirs))."\n");
&close_tempfile($fh);
my $econf = &read_config_file($temp, 1);
&clear_directive_lines(@$econf);
&unlink_file($temp);
return @$econf;
}

# clear_directive_lines(&directive, ...)
# Removes file and line metadata from parsed directives
sub clear_directive_lines
{
foreach my $e (@_) {
	delete($e->{'file'});
	delete($e->{'line'});
	delete($e->{'eline'});
	if ($e->{'type'}) {
		&clear_directive_lines(@{$e->{'members'}});
		}
	}
}

# split_words(string)
# Convert a string of bare or quoted words into a list
sub split_words
{
my ($value) = @_;
my @words;
while($value =~ s/^\s+"([^"]+)"// ||
      $value =~ s/^\s+'([^']+)'// ||
      $value =~ s/^\s+(\S+)//) {
	push(@words, $1);
	}
return @words;
}

# set_split_words(&directive, string)
# Set the words and value fields based on a string
sub set_split_words
{
my ($ns, $value) = @_;
my @s = &split_words($value);
$ns->{'words'} = \@s;
$ns->{'value'} = @s ? $s[0] : undef;
}

# get_add_to_file(name)
# Returns the file to add new servers to, if any
sub get_add_to_file
{
my ($name) = @_;
if (!$config{'add_to'}) {
	return undef;
	}
elsif (-d $config{'add_to'}) {
	$name =~ s/[^a-zA-Z0-9\.\_\-]//g;
	if ($name) {
		return $config{'add_to'}."/".$name.".conf";
		}
	}
else {
	return $config{'add_to'};
	}
return undef;
}

# find(name, [&config|&parent])
# Returns the object or objects with some name in the given config
sub find
{
my ($name, $conf) = @_;
$conf ||= &get_config();
if (ref($conf) eq 'HASH') {
	$conf = $conf->{'members'};
	}
my @rv;
foreach my $c (@$conf) {
	if (lc($c->{'name'}) eq $name) {
		push(@rv, $c);
		}
	}
return wantarray ? @rv : $rv[0];
}

# find_value(name, [config])
# Returns the value of the object or objects with some name in the given config
sub find_value
{
my ($name, $conf) = @_;
my @rv = map { my @w = @{$_->{'words'}};
	       (@w ? $w[0] : undef) || $_->{'value'} } &find($name, $conf);
return wantarray ? @rv : $rv[0];
}

# find_recursive(name, [&config|&parent])
# Returns all objects under some parent with the given name
sub find_recursive
{
my ($name, $conf) = @_;
$conf ||= &get_config();
if (ref($conf) eq 'HASH') {
        $conf = $conf->{'members'};
        }
my @rv;
foreach my $c (@$conf) {
        if (lc($c->{'name'}) eq $name) {
                push(@rv, $c);
                }
	if ($c->{'type'}) {
		push(@rv, &find_recursive($name, $c));
		}
        }
return wantarray ? @rv : $rv[0];
}

# save_directive(&parent, name|&oldobjects, &newvalues|&newobjects, [&before])
# Updates the values of some named directive
sub save_directive
{
my ($parent, $name_or_oldstructs, $values, $before) = @_;
$values = [ $values ] if (!ref($values));
my $oldstructs = ref($name_or_oldstructs) ? $name_or_oldstructs :
			[ &find($name_or_oldstructs, $parent) ];
my $name = !ref($name_or_oldstructs) ? $name_or_oldstructs :
	   @$name_or_oldstructs ? $name_or_oldstructs->[0]->{'name'} : undef;
my $newstructs = [ map { &value_to_struct($name, $_) } @$values ];
for(my $i=0; $i<@$newstructs || $i<@$oldstructs; $i++) {
	my $o = $i<@$oldstructs ? $oldstructs->[$i] : undef;
	my $n = $i<@$newstructs ? $newstructs->[$i] : undef;
	my $file = $o ? $o->{'file'} :
		   $n && $n->{'file'} ? $n->{'file'} : $parent->{'file'};
	my $lref = &read_file_lines($file);
	push(@open_config_files, $file);
	if ($i<@$newstructs && $i<@$oldstructs) {
		# Updating some directive
		my $olen = $o->{'eline'} - $o->{'line'} + 1;
		my $oldline = $lref->[$o->{'line'}];
		my $indent = &directive_indent($o, $parent, $lref);
		$n->{'indent_str'} = $indent
			if (!defined($n->{'indent_str'}));
		$n->{'indent'} = $o->{'indent'}
			if (defined($o->{'indent'}));
		$n->{'sep_str'} = &directive_value_separator($n, $oldline)
			if (!defined($n->{'sep_str'}));
		my @lines = &make_directive_lines($n, $indent, $parent, $lref);
		$o->{'name'} = $n->{'name'};
		$o->{'value'} = $n->{'words'}->[0];
		$o->{'words'} = $n->{'words'};
		$o->{'indent'} = $n->{'indent'} if (defined($n->{'indent'}));
		$o->{'indent_str'} = $n->{'indent_str'};
		$o->{'sep_str'} = $n->{'sep_str'};
		splice(@$lref, $o->{'line'}, $olen, @lines);
		if ($olen != scalar(@lines)) {
			# Renumber directives
			&renumber($file, $o->{'line'}, $olen - scalar(@lines));
			$o->{'eline'} = $o->{'line'} + scalar(@lines) - 1;
			}
		}
	elsif ($i<@$newstructs) {
		# Adding a directive
		my @lines;
		$n->{'value'} = $n->{'words'}->[0];
		if ($n->{'file'}) {
			# New file, add at start
			my $indent = defined($n->{'indent_str'}) ?
				     $n->{'indent_str'} : "";
			$n->{'indent_str'} = $indent
				if (!defined($n->{'indent_str'}));
			$n->{'indent'} = 0 if (!defined($n->{'indent'}));
			@lines = &make_directive_lines($n, $indent, $parent, $lref);
			$n->{'line'} = 0;
			$n->{'eline'} = scalar(@lines) - 1;
			&recursive_set_file($n, $n->{'file'}, $n->{'line'});
			unshift(@{$parent->{'members'}}, $n);
			}
		elsif ($before) {
			# Insert into parent before some other directive
			my $indent = &directive_indent($before, $parent, $lref);
			$n->{'indent_str'} = $indent
				if (!defined($n->{'indent_str'}));
			$n->{'indent'} = $parent->{'indent'} + 1
				if (!defined($n->{'indent'}) &&
				    defined($parent->{'indent'}));
			@lines = &make_directive_lines($n, $indent, $parent, $lref);
			$n->{'line'} = $before->{'line'};
			$n->{'eline'} = $n->{'line'} + scalar(@lines) - 1;
			&recursive_set_file($n, $file, $n->{'line'});
			&renumber($file, $n->{'line'}-1, scalar(@lines));
			my $idx = &indexof($before, @{$parent->{'members'}});
			if ($idx >= 0) {
				splice(@{$parent->{'members'}}, $idx, 0, $n);
				}
			else {
				push(@{$parent->{'members'}}, $n);
				}
			}
		else {
			# Insert into parent at end
			my $indent = &new_directive_indent($parent, $lref);
			$n->{'indent_str'} = $indent
				if (!defined($n->{'indent_str'}));
			$n->{'indent'} = $parent->{'indent'} + 1
				if (!defined($n->{'indent'}) &&
				    defined($parent->{'indent'}));
			@lines = &make_directive_lines($n, $indent, $parent, $lref);
			$n->{'line'} = $parent->{'eline'};
			$n->{'eline'} = $n->{'line'} + scalar(@lines) - 1;
			&recursive_set_file($n, $file, $n->{'line'});
			&renumber($file, $parent->{'eline'}-1, scalar(@lines));
			push(@{$parent->{'members'}}, $n);
			}
		splice(@$lref, $n->{'line'}, 0, @lines);
		}
	elsif ($i<@$oldstructs) {
		# Removing a directive
		my $olen = $o->{'eline'} - $o->{'line'} + 1;
		splice(@$lref, $o->{'line'}, $olen);
		my $idx = &indexof($o, @{$parent->{'members'}});
		if ($idx >= 0) {
			splice(@{$parent->{'members'}}, $idx, 1);
			}
		&renumber($file, $o->{'line'}, -$olen);
		}
	}
}

# renumber(filename, line, offset, [&parent])
# Adjusts the line number of any directive after the one given by the offset
sub renumber
{
my ($file, $line, $offset, $object) = @_;
$object ||= &get_config_parent();
if ($object->{'file'} eq $file) {
	$object->{'line'} += $offset if ($object->{'line'} > $line);
	$object->{'eline'} += $offset if ($object->{'eline'} > $line);
	}
if ($object->{'type'}) {
	foreach my $m (@{$object->{'members'}}) {
		&renumber($file, $line, $offset, $m);
		}
	}
}

# recursive_set_file(&parent, filename, start-line)
# Sets the file on some object and all children
sub recursive_set_file
{
my ($parent, $file, $line) = @_;
$parent->{'file'} ||= $file;
$parent->{'line'} ||= $line;
$parent->{'eline'} ||= $parent->{'line'};
if ($parent->{'type'}) {
	my $n = 1;
	foreach my $dir (@{$parent->{'members'}}) {
		&recursive_set_file($dir, $file, $parent->{'line'} + $n);
		$n += ($dir->{'eline'} - $dir->{'line'} + 1);
		}
	$parent->{'eline'} = $parent->{'line'} + $n;
	}
}

# flush_config_file_lines([&parent])
# Flush all lines in the current config
sub flush_config_file_lines
{
my ($parent) = @_;
foreach my $f (&unique(@open_config_files)) {
	&flush_file_lines($f);
	}
@open_config_files = ( );
}

# lock_all_config_files([&parent])
# Locks all files used in the current config
sub lock_all_config_files
{
my ($parent) = @_;
@lock_all_config_files_cache = &get_all_config_files($parent);
foreach my $f (@lock_all_config_files_cache) {
	&lock_file($f);
	}
}

# unlock_all_config_files([&parent])
# Un-locks all files used in the current config
sub unlock_all_config_files
{
my ($parent) = @_;
foreach my $f (reverse(@lock_all_config_files_cache)) {
	&unlock_file($f);
	}
@lock_all_config_files_cache = ();
}

# get_all_config_files([&parent])
# Returns all files in the given config object
sub get_all_config_files
{
my ($parent) = @_;
$parent ||= &get_config_parent();
my @rv = ( $parent->{'file'} );
if ($parent->{'type'}) {
	foreach my $c (@{$parent->{'members'}}) {
		push(@rv, &get_all_config_files($c));
		}
	}
return &unique(@rv);
}

# directive_indent(&directive, &parent, &file-lines)
# Returns the exact whitespace prefix to use when writing a directive
sub directive_indent
{
my ($dir, $parent, $lref) = @_;
return $dir->{'indent_str'} if (defined($dir->{'indent_str'}));
if ($lref && defined($dir->{'line'}) && defined($lref->[$dir->{'line'}]) &&
    $lref->[$dir->{'line'}] =~ /^(\s*)/) {
	return $1;
	}
return &new_directive_indent($parent, $lref) if ($parent);
return &indent_string($dir->{'indent'}, $lref)
	if (defined($dir->{'indent'}));
return "";
}

# new_directive_indent(&parent, &file-lines)
# Returns an exact whitespace prefix for a new child directive
sub new_directive_indent
{
my ($parent, $lref) = @_;
return "" if (!$parent);
return "" if (defined($parent->{'indent'}) && $parent->{'indent'} < 0);
foreach my $m (@{$parent->{'members'} || []}) {
	next if ($parent->{'file'} && $m->{'file'} &&
		 $parent->{'file'} ne $m->{'file'});
	return $m->{'indent_str'} if (defined($m->{'indent_str'}));
	}
my $pindent = defined($parent->{'indent_str'}) ? $parent->{'indent_str'} :
	      defined($parent->{'indent'}) ? &indent_string($parent->{'indent'}, $lref) : "";
return $pindent.&child_indent_step($parent, $lref);
}

# child_indent_step(&parent, &file-lines)
# Returns one indentation level used below a parent block
sub child_indent_step
{
my ($parent, $lref) = @_;
my $pindent = defined($parent->{'indent_str'}) ? $parent->{'indent_str'} :
	      defined($parent->{'indent'}) ? &indent_string($parent->{'indent'}, $lref) : "";
foreach my $m (@{$parent->{'members'} || []}) {
	next if ($parent->{'file'} && $m->{'file'} &&
		 $parent->{'file'} ne $m->{'file'});
	my $mindent = $m->{'indent_str'};
	if (defined($mindent) && index($mindent, $pindent) == 0 &&
	    length($mindent) > length($pindent)) {
		return substr($mindent, length($pindent));
		}
	}
return &config_indent_step($lref);
}

# config_indent_step(&file-lines)
# Returns a one-level indent already used in the current file
sub config_indent_step
{
my ($lref) = @_;
my %indents;
if ($lref) {
	foreach my $l (@$lref) {
		next if (!defined($l) || $l !~ /^(\s+)\S/);
		$indents{$1}++;
		}
	}
return (sort { length($a) <=> length($b) ||
	       $indents{$b} <=> $indents{$a} } keys %indents)[0]
	if (%indents);
return &default_indent_step();
}

# default_indent_step()
# Returns one generated indentation level for new blocks
sub default_indent_step
{
return "     ";
}

# make_directive_lines(&directive, indent, [&parent], [&file-lines])
# Returns text for some directive
sub make_directive_lines
{
my ($dir, $indent, $parent, $lref) = @_;
my $indent_str = &indent_string($indent, $lref);
$dir->{'indent_str'} = $indent_str if (!defined($dir->{'indent_str'}));
my @rv;
my @w = @{$dir->{'words'}};
if ($dir->{'type'}) {
	# Multi-line
	if ($dir->{'name'} eq 'if') {
		push(@rv, $indent_str.$dir->{'name'}.' ('.&join_words(@w).') {');
		}
	else {
		push(@rv, $indent_str.$dir->{'name'}.
			  (@w ? " ".&join_words(@w) : "")." {");
		}
	my $step = &child_indent_step($dir, $lref);
	foreach my $m (@{$dir->{'members'}}) {
		my $mindent = &directive_indent($m, $dir, $lref);
		$mindent = $indent_str.$step if (!defined($mindent));
		push(@rv, &make_directive_lines($m, $mindent, $dir, $lref));
		}
	push(@rv, $indent_str."}");
	}
else {
	# Single line
	my $sep = @w ? ($dir->{'sep_str'} || " ") : "";
	push(@rv, $indent_str.$dir->{'name'}.$sep.&join_words(@w).";");
	}
return wantarray ? @rv : $rv[0];
}

# indent_string(indent, [&file-lines])
# Converts an indent depth or exact whitespace to exact whitespace
sub indent_string
{
my ($indent, $lref) = @_;
return "" if (!defined($indent));
return &config_indent_step($lref) x $indent if ($indent =~ /^\d+$/);
return $indent;
}

# directive_value_separator(&directive, old-line)
# Returns whitespace between directive name and value
sub directive_value_separator
{
my ($dir, $oldline) = @_;
return undef if (!@{$dir->{'words'} || []});
return $1 if (defined($oldline) &&
	      $oldline =~ /^\s*\Q$dir->{'name'}\E(\s+)/);
return $dir->{'sep_str'} || " ";
}

# join_words(word, etc..)
# Returns a string made by joining directive words
sub join_words
{
my @rv;
foreach my $w (@_) {
	if ($w eq "") {
		push(@rv, '""');
		}
	elsif ($w =~ /\s|;|\$/ && $w !~ /"/ && $w !~ /^\$/) {
		push(@rv, "\"$w\"");
		}
	elsif ($w =~ /\s|;|\$/ && $w !~ /^\$/) {
		push(@rv, "'$w'");
		}
	else {
		push(@rv, $w);
		}
	}
return join(" ", @rv);
}

# value_to_struct(name, value)
# Converts a string, array ref or hash ref to a config struct
sub value_to_struct
{
my ($name, $value) = @_;
if (ref($value) eq 'HASH') {
	# Already in correct format
	$value->{'name'} ||= $name;
	return $value;
	}
elsif (ref($value) eq 'ARRAY') {
	# Array of words
	return { 'name' => $name,
		 'words' => $value,
		 'value' => $value->[0] };
	}
else {
	# Single value
	return { 'name' => $name,
		 'words' => [ $value ],
		 'value' => $value };
	}
}

# get_nginx_version()
# Returns the version number of the installed Nginx binary
sub get_nginx_version
{
my $out = &backquote_command("$config{'nginx_cmd'} -v 2>&1 </dev/null");
return $out =~ /version:\s*nginx\/([0-9\.]+)/i ? $1 : undef;
}

# list_nginx_directives()
# Returns a hash ref of hash refs, with name, module, default and context keys
sub list_nginx_directives
{
if (!%list_directives_cache) {
	my $lref = &read_file_lines(
			"$module_root_directory/nginx-directives", 1);
	foreach my $l (@$lref) {
		my ($module, $name, $default, $context) = split(/\t/, $l);
		$list_directives_cache{$name} =
			{ 'module' => $module,
			  'name' => $name,
			  'default' => $default eq '-' ? undef : $default,
			  'context' => $context eq '-' ? undef :
					[ split(/,/, $context) ],
			};
		}
	}
return \%list_directives_cache;
}

# get_default(name)
# Returns the default value for some directive
sub get_default
{
my ($name) = @_;
my $dirs = &list_nginx_directives();
my $dir = $dirs->{$name};
return $dir ? $dir->{'default'} : undef;
}

sub get_default_server_param
{
my $ver = &get_nginx_version();
return &compare_version_numbers($ver, "0.8.21") >= 0 ?
	"default_server" : "default";
}

# list_nginx_modules()
# Returns a list of enabled modules. Includes those compiled in by default
# unless disabled, plus extra compiled in at build time.
sub list_nginx_modules
{
if (!@list_modules_cache) {
	@list_modules_cache = ( 'http_core', 'http_access', 'http_access',
				'http_auth_basic', 'http_autoindex',
				'http_browser', 'http_charset',
				'http_empty_gif', 'http_fastcgi', 'http_geo',
				'http_gzip', 'http_limit_req',
				'http_limit_zone', 'http_map',
				'http_memcached', 'http_proxy',
				'http_referer', 'http_rewrite',
				'http_scgi', 'http_split_clients',
				'http_ssi', 'http_userid', 'http_index',
				'http_uwsgi', 'http_log', 'core' );
	my $out = &backquote_command("$config{'nginx_cmd'} -V 2>&1 </dev/null");
	while($out =~ s/--with-(\S+)_module\s+//) {
		push(@list_modules_cache, $1);
		}
	while($out =~ s/--without-(\S+)_module\s+//) {
		@list_modules_cache = grep { $_ ne $1 } @list_modules_cache;
		}
	}
return @list_modules_cache;
}

# supported_directive(name, [&parent])
# Returns 1 if the module for some directive is supported on this system
sub supported_directive
{
my ($name, $parent) = @_;
my $dirs = &list_nginx_directives();
my $dir = $dirs->{$name};
return 0 if (!$dir);
return 0 if ($dir->{'context'} && $parent &&
	     &indexof($parent->{'name'}, @{$dir->{'context'}}) < 0);
my @mods = &list_nginx_modules();
#return 0 if (&indexof($dir->{'module'}, @mods) < 0);
return 1;
}

# nginx_onoff_input(name, &parent)
# Returns HTML for a table row for an on/off input
sub nginx_onoff_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my $value = &find_value($name, $parent);
$value ||= &get_default($name);
$value ||= "";
return &ui_table_row($text{'opt_'.$name},
	&ui_yesno_radio($name, $value =~ /on|true|yes/i ? 1 : 0));
}

# nginx_onoff_parse(name, &parent, &in)
# Updates the config with input from nginx_onoff_input
sub nginx_onoff_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
&save_directive($parent, $name, [ $in->{$name} ? "on" : "off" ]);
}

# nginx_opt_input(name, &parent, size, prefix, suffix, [multi-value])
# Returns HTML for an optional text field
sub nginx_opt_input
{
my ($name, $parent, $size, $prefix, $suffix, $multi) = @_;
return undef if (!&supported_directive($name, $parent));
my $obj = &find($name, $parent);
my $value = $obj ? ($multi ? &join_words(@{$obj->{'words'}})
			    : $obj->{'value'})
		 : undef;
my $def = &get_default($name);
return &ui_table_row($text{'opt_'.$name},
	&ui_opt_textbox($name, $value, $size,
			$text{'default'}.($def ? " ($def)" : ""), $prefix).
	$suffix, $size > 40 ? 3 : 1);
}

# nginx_opt_parse(name, &parent, &in, [regex], [&validator], [multi-value])
# Updates the config with input from nginx_opt_input
sub nginx_opt_parse
{
my ($name, $parent, $in, $regexp, $vfunc, $multi) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"}) {
	&save_directive($parent, $name, [ ]);
	}
else {
	my $v = $in->{$name};
	my @w = $multi ? &split_quoted_string($v) : ( $v );
	$v eq '' && &error(&text('opt_missing', $text{'opt_'.$name}));
	!$regexp || $v =~ /$regexp/ || &error($text{'opt_e'.$name} || $name);
	my $err = $vfunc && &$vfunc($v, $name);
	$err && &error($err);
	&save_directive($parent, $name, [ { 'name' => $name,
					    'words' => \@w } ]);
	}
}

# nginx_text_input(name, &parent, size, suffix, [multi-value])
# Returns HTML for a non-optional text field
sub nginx_text_input
{
my ($name, $parent, $size, $suffix, $multi) = @_;
return undef if (!&supported_directive($name, $parent));
my $obj = &find($name, $parent);
my $value = $obj ? ($multi ? &join_words(@{$obj->{'words'}})
			    : $obj->{'value'})
		 : undef;
$suffix ||= "";
return &ui_table_row($text{'opt_'.$name},
	&ui_textbox($name, $value, $size).$suffix, $size > 40 ? 3 : 1);
}

# nginx_text_parse(name, &parent, &in, [regex], [&validator], [multi-value])
# Updates the config with input from nginx_text_input
sub nginx_text_parse
{
my ($name, $parent, $in, $regexp, $vfunc, $multi) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
my $v = $in->{$name};
my @w = $multi ? &split_quoted_string($v) : ( $v );
foreach my $wv (@w) {
	$wv eq '' && &error(&text('opt_missing', $text{'opt_'.$name}));
	!$regexp || $wv =~ /$regexp/ || &error($text{'opt_e'.$name});
	my $err = $vfunc && &$vfunc($wv, $name);
	$err && &error($err);
	}
&save_directive($parent, $name, [ { 'name' => $name,
				    'words' => \@w } ]);
}

# nginx_error_log_input(name, &parent)
# Returns HTML specifically for setting the error_log directive
sub nginx_error_log_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my $obj = &find($name, $parent);
my $def = $parent->{'name'} eq 'server' ? $text{'opt_global'}
					: &get_default($name);
$def =~ s/^\$\{prefix\}\///;
return &ui_table_row($text{'opt_'.$name},
	&ui_radio($name."_def", $obj ? 0 : 1,
		  [ [ 1, $text{'default'}.($def ? " ($def)" : "")."<br>" ],
		    [ 0, $text{'logs_file'} ] ])." ".
	&ui_textbox($name, $obj ? $obj->{'words'}->[0] : undef, 40)." ".
	$text{'logs_level'}." ".
	&ui_select($name."_level", $obj ? $obj->{'words'}->[1] : "",
		   [ [ "", "&lt;$text{'default'}&gt;" ],
		     "debug", "info", "notice", "warn", "error", "crit" ]));
}

# nginx_error_log_parse(name, &parent, &in)
# Validate input from nginx_error_log_input
sub nginx_error_log_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"}) {
	&save_directive($parent, $name, [ ]);
        }
else {
	$in->{$name} || &error(&text('opt_missing', $text{'opt_'.$name}));
	$in->{$name} =~ /^\/\S+$/ || &error($text{'opt_e'.$name});
	my @w = ( $in->{$name} );
	push(@w, $in->{$name."_level"}) if ($in->{$name."_level"});
	&save_directive($parent, $name, [ { 'name' => $name,
					    'words' => \@w } ]);
	}
}

# nginx_access_log_input(name, &parent)
# Returns HTML specifically for setting the access_log directive
sub nginx_access_log_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my $obj = &find($name, $parent);
my $mode = !$obj ? 1 : $obj->{'value'} eq 'off' ? 2 : 0;
my $buffer = $mode == 0 && $obj->{'words'}->[2] =~ /buffer=(\S+)/ ? $1 : "";
my $def = $parent->{'name'} eq 'server' ? $text{'opt_global'}
					: &get_default($name);
return &ui_table_row($text{'opt_'.$name},
	&ui_radio($name."_def", $mode,
		[ [ 1, $text{'default'}.($def ? " ($def)" : "")."<br>" ],
		  [ 2, $text{'logs_disabled'}."<br>" ],
		  [ 0, $text{'logs_file'} ] ])." ".
	&ui_textbox($name, $mode == 0 ? $obj->{'words'}->[0] : undef, 40)." ".
	$text{'logs_format'}." ".
	&ui_select($name."_format", $mode == 0 ? $obj->{'words'}->[1] : "",
		   [ [ "", "&lt;$text{'default'}&gt;" ],
		     &list_log_formats($parent) ])." ".
	$text{'logs_buffer'}." ".
	&ui_textbox($name."_buffer", $buffer, 6));
}

# nginx_access_log_parse(name, &parent, &in)
# Validate input from nginx_access_log_input
sub nginx_access_log_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"} == 1) {
	&save_directive($parent, $name, [ ]);
        }
elsif ($in->{$name."_def"} == 2) {
	&save_directive($parent, $name, [ "off" ]);
	}
else {
	$in->{$name} || &error(&text('opt_missing', $text{'opt_'.$name}));
	$in->{$name} =~ /^\/\S+$/ || &error($text{'opt_e'.$name});
	my @w = ( $in->{$name} );
	push(@w, $in->{$name."_format"}) if ($in->{$name."_format"});
	my $buffer = $in->{$name."_buffer"};
	if ($buffer) {
		$buffer =~ /^\d+[bKMGT]?$/i || &error($text{'logs_ebuffer'});
		push(@w, "buffer=$buffer");
		}
	&save_directive($parent, $name, [ { 'name' => $name,
					    'words' => \@w } ]);
	}
}

# nginx_user_input(name, &parent)
# Returns HTML for a user field with an optional group
sub nginx_user_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my $obj = &find($name, $parent);
my $def = &get_default($name);
return &ui_table_row($text{'opt_'.$name},
	&ui_radio($name."_def", $obj ? 0 : 1,
		  [ [ 1, $text{'default'}.($def ? " ($def)" : "")."<br>" ],
		    [ 0, $text{'misc_username'} ] ])." ".
	&ui_user_textbox($name, $obj ? $obj->{'words'}->[0] : "")." ".
	$text{'misc_group'}." ".
	&ui_group_textbox($name."_group", $obj ? $obj->{'words'}->[1] : ""));
}

# nginx_user_parse(name, &parent, &in)
# Validate input from nginx_user_input
sub nginx_user_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"} == 1) {
	&save_directive($parent, $name, [ ]);
        }
else {
	$in->{$name} || &error(&text('opt_missing', $text{'opt_'.$name}));
	defined(getpwnam($in->{$name})) || &error($text{'misc_euser'});
	my @w = ( $in->{$name} );
	my $group = $in->{$name."_group"};
	if ($group) {
		defined(getgrnam($group)) || &error($text{'misc_egroup'});
		push(@w, $group);
		}
	&save_directive($parent, $name, [ { 'name' => $name,
					    'words' => \@w } ]);
	}
}

# nginx_logformat_input(name, parent)
# Returns HTML for entering multiple log formats
sub nginx_logformat_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my @obj = &find($name, $parent);
my $ftable = &ui_columns_start([ $text{'logs_fname'},
				 $text{'logs_ftext'} ]);
my $i = 0;
foreach my $o (@obj, { 'words' => [ ] }) {
	my @w = @{$o->{'words'}};
	$ftable .= &ui_columns_row([
		&ui_textbox($name."_name_$i", shift(@w), 20),
		&ui_textbox($name."_text_$i", join(" ", @w), 60),
		]);
	$i++;
	}
$ftable .= &ui_columns_end();
return &ui_table_row($text{'opt_'.$name}, $ftable, 3);
}

# nginx_logformat_parse(name, &parent, &in)
# Validate input from nginx_logformat_input
sub nginx_logformat_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
my @obj;
for(my $i=0; defined(my $fname = $in{$name."_name_$i"}); $i++) {
	next if (!$fname);
	my $ftext = $in{$name."_text_$i"};
	$fname =~ /^[a-zA-Z0-9\-\.\_]+$/ ||
		&error(&text('logs_efname', $fname));
	$ftext =~ /\S/ || &error(&text('logs_etext', $fname));
	push(@obj, { 'name' => $name,
		     'words' => [ $fname, $ftext ] });
	}
&save_directive($parent, $name, \@obj);
}

# nginx_multi_input(name, &parent, &options)
# Returns HTML for selecting multiple options
sub nginx_multi_input
{
my ($name, $parent, $opts) = @_;
return undef if (!&supported_directive($name, $parent));
my $def = &get_default($name);
my $obj = &find($name, $parent);
return &ui_table_row($text{'opt_'.$name},
        &ui_radio($name."_def", $obj ? 0 : 1,
		  [ [ 1, $text{'default'}.($def ? " ($def)" : "") ],
		    [ 0, $text{'opt_selected'}."<br>" ] ])." ".
	&ui_select($name, $obj ? $obj->{'words'} : [ ], $opts, scalar(@$opts),
		   1, 1));
}

# nginx_multi_parse(name, &parent)
# Validate input from nginx_multi_input
sub nginx_multi_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"} == 1) {
        &save_directive($parent, $name, [ ]);
        }
else {
	my @w = split(/\0/, $in->{$name});
	@w || &error(&text('opt_missing', $text{'opt_'.$name}));
	&save_directive($parent, $name, [ { 'name' => $name,
					    'words' => \@w } ]);
	}
}

# nginx_param_input(name, &parent, [name-text, value-text])
# Returns HTML for entering multiple name value paramters
sub nginx_param_input
{
my ($name, $parent, $ntext, $vtext) = @_;
$ntext ||= $text{'fcgi_pname'};
$vtext ||= $text{'fcgi_pvalue'};
return undef if (!&supported_directive($name, $parent));
my @obj = &find($name, $parent);
my $ftable = &ui_columns_start([ $ntext, $vtext ]);
my $i = 0;
foreach my $o (@obj, { 'words' => [ ] }) {
	my @w = @{$o->{'words'}};
	$ftable .= &ui_columns_row([
		&ui_textbox($name."_name_$i", shift(@w), 20),
		&ui_textbox($name."_value_$i", join(" ", @w), 60),
		]);
	$i++;
	}
$ftable .= &ui_columns_end();
return &ui_table_row($text{'opt_'.$name}, $ftable, 3);
}

# nginx_params_parse(name, &parent, &in)
# Parses inputs from nginx_param_input
sub nginx_params_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
my @obj;
for(my $i=0; defined(my $pname = $in{$name."_name_$i"}); $i++) {
	next if (!$pname);
	my $pvalue = $in{$name."_value_$i"};
	$pname =~ /^[a-zA-Z0-9\-\.\_]+$/ ||
		&error(&text('fcgi_epname', $pname));
	$pvalue =~ /\S/ || &error(&text('fcgi_epvalue', $pname));
	push(@obj, { 'name' => $name,
		     'words' => [ $pname, $pvalue ] });
	}
&save_directive($parent, $name, \@obj);
}

# nginx_opt_list_input(name, &parent, size, prefix, suffix)
# Returns HTML for an optional text field with multiple values
sub nginx_opt_list_input
{
my ($name, $parent, $size, $prefix, $suffix) = @_;
return undef if (!&supported_directive($name, $parent));
my $obj = &find($name, $parent);
my $value = $obj ? join(" ", @{$obj->{'words'}}) : "";
my $def = &get_default($name);
return &ui_table_row($text{'opt_'.$name},
	&ui_opt_textbox($name, $value, $size,
			$text{'default'}.($def ? " ($def)" : ""), $prefix).
	$suffix, $size > 40 ? 3 : 1);
}

# nginx_opt_list_parse(name, &parent, &in, [regex], [&validator])
# Updates the config with input from nginx_opt_list_input
sub nginx_opt_list_parse
{
my ($name, $parent, $in, $regexp, $vfunc) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"}) {
	&save_directive($parent, $name, [ ]);
	}
else {
	my @v = &split_quoted_string($in->{$name});
	@v || &error(&text('opt_missing', $text{'opt_'.$name}));
	foreach my $v (@v) {
		!$regexp || $v =~ /$regexp/ ||
			&error(&text('opt_e'.$name, $v) || $name);
		my $err = $vfunc && &$vfunc($v, $name);
		$err && &error($err);
		}
	&save_directive($parent, $name, [ { 'name' => $name,
					    'words' => \@v } ]);
	}
}

# nginx_textarea_input(name, &parent, width, height)
# Returns HTML for entering the values of multiple directives of the same type,
# in a text area
sub nginx_textarea_input
{
my ($name, $parent, $width, $height) = @_;
return undef if (!&supported_directive($name, $parent));
my @obj = &find($name, $parent);
return &ui_table_row($text{'opt_'.$name},
		     &ui_textarea($name,
			join("\n", map { $_->{'words'}->[0] } @obj),
			$height, $width), 3);
}

# nginx_textarea_parse(name, &parent, &in, [&regex], [&validator])
# Parses inputs from nginx_param_input
sub nginx_textarea_parse
{
my ($name, $parent, $in, $regexp, $vfunc) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
my @obj;
foreach my $v (split(/\r?\n/, $in->{$name})) {
	!$regexp || $v =~ /$regexp/ ||
		&error(&text('opt_e'.$name, $v) || $name);
	my $err = $vfunc && &$vfunc($v, $name);
	$err && &error($err);
	push(@obj, { 'name' => $name,
		     'words' => [ $v ] });
	}
&save_directive($parent, $name, \@obj);
}

# nginx_access_input(name1, name2, &parent)
# Returns HTML for setting allow and deny directives
sub nginx_access_input
{
my ($allow, $deny, $parent) = @_;
return undef if (!&supported_directive($allow, $parent));
my @obj = sort { $a->{'line'} <=> $b->{'line'} }
	       (&find($allow, $parent), &find($deny, $parent));
my $table = &ui_columns_start([ $text{'access_mode'},
				$text{'access_value'} ], 100, 0,
			      [ "nowrap", "nowrap" ]);
my $i =0;
foreach my $o (@obj, { }, { }) {
	my $v = $o->{'value'};
	$v = "" if (lc($v) eq "all");
	$table .= &ui_columns_row([
		&ui_select($allow."_mode_".$i,
			   $o->{'name'},
			   [ [ "", "&nbsp;" ],
			     [ "allow", $text{'access_allow'} ],
			     [ "deny", $text{'access_deny'} ] ]),
		&ui_opt_textbox($allow."_addr_".$i, $v, 30,
			        $text{'access_all'}, $text{'access_addr'}),
		]);
	$i++;
	}
$table .= &ui_columns_end();
return &ui_table_row($text{'opt_'.$allow}, $table, 3);
}

# nginx_access_parse(name1, name2, &parent, &in)
# Parse inputs from nginx_access_input
sub nginx_access_parse
{
my ($allow, $deny, $parent, $in) = @_;
return undef if (!&supported_directive($allow, $parent));
$in ||= \%in;
my @obj;
my @old = sort { $a->{'line'} <=> $b->{'line'} }
               (&find($allow, $parent), &find($deny, $parent));
for(my $i=0; defined(my $mode = $in->{$allow."_mode_".$i}); $i++) {
	next if (!$mode);
	my $addr;
	if ($in->{$allow."_addr_".$i."_def"}) {
		$addr = "all";
		}
	else {
		$addr = $in->{$allow."_addr_".$i};
		$addr || &error(&text('access_eaddrnone', $i+1));
		&check_ipaddress($addr) ||
		   $addr =~ /^(\S+)\/(\d+)$/ &&
		     &check_ipaddress("$1") && $2 > 0 && $2 <= 32 ||
		&check_ip6address($addr) ||
		   $addr =~ /^(\S+)\/(\d+)$/ && &check_ip6address("$1") ||
			&error(&text('access_eaddr', $addr));
		}
	push(@obj, { 'name' => $mode,
		     'words' => [ $addr ] });
	}
&save_directive($parent, \@old, \@obj);
}

# nginx_realm_input(name, &parent)
# Returns HTML for entering an authentication realm
sub nginx_realm_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my $value = &find_value($name, $parent);
my $def = &get_default($name);
return &ui_table_row($text{'opt_'.$name},
	&ui_radio($name."_def",
		  !$value ? 1 : $value eq "off" ? 2 : 0,
		  [ [ 1, $text{'default'}.($def ? " ($def)" : "") ],
		    [ 2, $text{'access_off'} ],
		    [ 0, $text{'access_realm'}." ".
			 &ui_textbox($name, $value eq "off" ? "" : $value, 40) ]
		  ]), 3);
}

# nginx_realm_parse(name, &parent, &in)
# Updates the config with input from nginx_realm_input
sub nginx_realm_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
if ($in->{$name."_def"} == 1) {
	&save_directive($parent, $name, [ ]);
	}
elsif ($in->{$name."_def"} == 2) {
	&save_directive($parent, $name, [ "off" ]);
	}
else {
	my $v = $in->{$name};
	$v eq '' && &error(&text('opt_missing', $text{'opt_'.$name}));
	&save_directive($parent, $name, [ $v ]);
	}
}

# nginx_passfile_input(name, &parent, server-id, path)
# Returns HTML for a password file field
sub nginx_passfile_input
{
my ($name, $parent, $id, $path) = @_;
my $value = &find_value($name, $parent);
my $edit;
if ($value =~ /^\/\S/) {
	$edit = " <a href='list_users.cgi?file=".&urlize($value).
		"&id=".&urlize($id)."&path=".&urlize($path)."'>".
		$text{'access_edit'}."</a>";
	}
return &nginx_opt_input($name, $parent, 50, $text{'access_pfile'},
			&file_chooser_button($name).$edit);
}

# nginx_passfile_parse(name, &parent, &in)
# Parse input from nginx_passfile_input
sub nginx_passfile_parse
{
my ($name, $parent, $in) = @_;
$in ||= \%in;
$in->{$name."_def"} || &can_directory($in->{$name}) ||
	&error(&text('access_ecannot',
		     "<tt>".&html_escape($in->{$name})."</tt>",
		     "<tt>".&html_escape($access{'root'})."</tt>"));
&nginx_opt_parse($name, $parent, $in, undef,
		 sub { return $_[0] !~ /^\// ? $text{'access_eabsolute'} :
			      -d $_[0] ? $text{'access_edir'} : undef });
}

# nginx_rewrite_input(name, &parent)
# Returns HTML for setting rewrite directives
sub nginx_rewrite_input
{
my ($name, $parent) = @_;
return undef if (!&supported_directive($name, $parent));
my @obj = &find($name, $parent);
my $table = &ui_columns_start([ $text{'rewrite_from'},
				$text{'rewrite_to'},
				$text{'rewrite_flag'} ], 100, 0,
			      [ "nowrap", "nowrap" ]);
my $i =0;
foreach my $o (@obj, { }, { }) {
	$table .= &ui_columns_row([
		&ui_textbox($name."_from_$i", $o->{'words'}->[0], 30),
		&ui_textbox($name."_to_$i", $o->{'words'}->[1], 40),
		&ui_select($name."_flag_$i", $o->{'words'}->[2],
			   [ map { [ $_, $text{'rewrite_'.$_} ] }
				 ('last', 'break', 'redirect', 'permanent') ]),
		]);
	$i++;
	}
$table .= &ui_columns_end();
return &ui_table_row($text{'opt_'.$name}, $table, 3);
}

# nginx_rewrite_parse(name1, name2, &parent, &in)
# Parse inputs from nginx_rewrite_input
sub nginx_rewrite_parse
{
my ($name, $parent, $in) = @_;
return undef if (!&supported_directive($name, $parent));
$in ||= \%in;
my @obj;
for(my $i=0; defined(my $from = $in->{$name."_from_".$i}); $i++) {
	next if (!$from);
	$from =~ /^\S+$/ || &error(&text('rewrite_efrom', $i+1));
	my $to = $in->{$name."_to_".$i};
	$to =~ /^\S+$/ || &error(&text('rewrite_eto', $i+1));
	my $flag = $in->{$name."_flag_".$i};
	push(@obj, { 'name' => $name,
		     'words' => [ $from, $to, $flag ] });
	}
&save_directive($parent, $name, \@obj);
}

# list_log_formats([&server])
# Returns a list of all log format names
sub list_log_formats
{
my ($server) = @_;
my $parent = &get_config_parent();
my @rv = ( "combined" );
my $http = &find("http", $parent);
foreach my $l (&find("log_format", $http)) {
	push(@rv, $l->{'words'}->[0]);
	}
if ($server && $server->{'name'} eq 'server') {
	foreach my $l (&find("log_format", $server)) {
		push(@rv, $l->{'words'}->[0]);
		}
	}
return &unique(@rv);
}

# is_nginx_running()
# Returns the PID if nginx is running
sub is_nginx_running
{
my $parent = &get_config_parent();
my $pidfile = &find_value("pid", $parent);
$pidfile ||= &get_default("pid");
$pidfile ||= $config{'pid_file'};
if ($pidfile =~ /^\//) {
	return &check_pid_file($pidfile);
	}
else {
	my ($pid) = &find_byname("nginx");
	return $pid;
	}
}

# stop_nginx()
# Attempt to stop nginx, return an error on failure or undef on success
sub stop_nginx
{
my $out = &backquote_logged("$config{'stop_cmd'} 2>&1 </dev/null");
return $? ? $out : undef;
}

# start_nginx()
# Attempt to start nginx, return an error on failure or undef on success
sub start_nginx
{
my $out = &backquote_logged("$config{'start_cmd'} 2>&1 </dev/null");
return $? ? $out : undef;
}

# apply_nginx()
# Attempt to apply the nginx config, return an error on failure or undef
# on success
sub apply_nginx
{
my $out = &backquote_logged("$config{'apply_cmd'} 2>&1 </dev/null");
return $? ? $out : undef;
}

# nginx_action_links()
# Returns HTML for service actions to put in the page header
sub nginx_action_links
{
my $args = "redir=".&urlize(&this_url());
my @rv;
if (&is_nginx_running()) {
	if ($access{'stop'}) {
		push(@rv, &ui_link("stop.cgi?$args", $text{'index_stop'}));
		}
	push(@rv, &ui_link("restart.cgi?$args", $text{'index_restart'}));
	}
elsif ($access{'stop'}) {
	push(@rv, &ui_link("start.cgi?$args", $text{'index_start'}));
	}
return join("<br>\n", @rv);
}

# this_url()
# Returns the current module URL
sub this_url
{
my $url = $ENV{'SCRIPT_NAME'};
$url .= "?$ENV{'QUERY_STRING'}"
	if (defined($ENV{'QUERY_STRING'}) && $ENV{'QUERY_STRING'} ne "");
return $url;
}

# test_config()
# Returns an error message if the config is invalid
sub test_config
{
&clean_language() if (defined(&clean_language));
my $out = &backquote_logged("$config{'nginx_cmd'} -t 2>&1 </dev/null");
&reset_environment() if (defined(&clean_language));
return $? || $out !~ /syntax\s+is\s+ok/ ? $out : undef;
}

# can_manage_server_files()
# Returns 1 if this system uses Debian-style available/enabled site dirs
sub can_manage_server_files
{
return $config{'add_to'} && -d $config{'add_to'} &&
       $config{'add_link'} && -d $config{'add_link'};
}

# get_add_to_files()
# Returns config files from the directory used for new server blocks
sub get_add_to_files
{
my @rv;
if ($config{'add_to'} && -d $config{'add_to'}) {
	opendir(ADDTO, $config{'add_to'}) || return @rv;
	foreach my $f (sort { lc($a) cmp lc($b) } readdir(ADDTO)) {
		next if ($f eq "." || $f eq "..");
		my $file = $config{'add_to'}."/".$f;
		my $rfile = &resolve_links($file);
		next if (!$rfile || !-f $rfile || !-r $rfile);
		push(@rv, $rfile);
		}
	closedir(ADDTO);
	}
return &unique(@rv);
}

# find_servers_in_file(file)
# Returns server blocks parsed from one config file
sub find_servers_in_file
{
my ($file) = @_;
my $rfile = &resolve_links($file);
$rfile ||= $file;
return ( ) if (!-r $rfile);
my $conf = &read_config_file($rfile);
return grep { $_->{'file'} eq $rfile } &find_recursive("server", $conf);
}

# can_manage_server_file(file)
# Returns 1 if all server blocks in a file are manageable by this user
sub can_manage_server_file
{
my ($file) = @_;
my $rfile = &resolve_links($file);
$rfile ||= $file;
return 0 if (!$rfile || !-f $rfile || !-r $rfile);
my @servers = &find_servers_in_file($rfile);
return 0 if (!@servers);
foreach my $server (@servers) {
	return 0 if (!&can_edit_server($server));
	}
return 1;
}

# delete_servers_from_file(file, &servers...)
# Deletes server blocks from one config file and removes the file if empty
sub delete_servers_from_file
{
my ($file, @servers) = @_;
return 0 if (!@servers);
my $lref = &read_file_lines($file);
foreach my $server (sort { $b->{'line'} <=> $a->{'line'} } @servers) {
	my $len = $server->{'eline'} - $server->{'line'} + 1;
	splice(@$lref, $server->{'line'}, $len);
	}
my $empty = 1;
foreach my $line (@$lref) {
	if ($line =~ /\S/) {
		$empty = 0;
		last;
		}
	}
&flush_file_lines($file);
if ($empty) {
	foreach my $link (&server_file_links($file)) {
		&unlink_logged($link);
		}
	&unlink_logged($file);
	}
return scalar(@servers);
}

# get_server_list_rows(&http)
# Returns row hashes for the server blocks list, preserving sites-available order
sub get_server_list_rows
{
my ($http) = @_;
my @allservers = &find("server", $http);
my @servers = grep { &can_edit_server($_) } @allservers;
my $default_first = sub {
	return ( grep { &is_default_server_block($_->{'server'}) } @_ ),
	       ( grep { !&is_default_server_block($_->{'server'}) } @_ );
	};
if (&can_manage_server_files()) {
	my @rows;
	my %active_by_file;
	foreach my $s (@servers) {
		my $file = &resolve_links($s->{'file'});
		$file ||= $s->{'file'};
		push(@{$active_by_file{$file}}, $s);
		}
	my %done_server;
	foreach my $file (&get_add_to_files()) {
		my @fileservers = @{$active_by_file{$file} || [ ]};
		my $active = @fileservers ? 1 : 0;
		if (!@fileservers) {
			@fileservers = grep { &can_edit_server($_) }
				      &find_servers_in_file($file);
			}
		foreach my $s (@fileservers) {
			push(@rows, { 'server' => $s,
				      'active' => $active,
				      'file' => $file });
			$done_server{$s}++;
			}
		}
	foreach my $s (@servers) {
		next if ($done_server{$s});
		push(@rows, { 'server' => $s,
			      'active' => 1,
			      'file' => $s->{'file'} });
		}
	return &$default_first(@rows);
	}
return &$default_first(
	map { { 'server' => $_, 'active' => 1, 'file' => $_->{'file'} } }
	@servers);
}

# server_file_link(file)
# Returns the enabled symlink path for a server file
sub server_file_link
{
my ($file) = @_;
return undef if (!&can_manage_server_files());
my $short = $file;
$short =~ s/^.*\///;
return $config{'add_link'}."/".$short;
}

# server_file_links(file)
# Returns enabled symlinks for a server file
sub server_file_links
{
my ($file) = @_;
my @rv;
return @rv if (!&can_manage_server_files());
my $rfile = &resolve_links($file);
$rfile ||= $file;
opendir(LINKDIR, $config{'add_link'}) || return @rv;
foreach my $f (readdir(LINKDIR)) {
	next if ($f eq "." || $f eq "..");
	my $link = $config{'add_link'}."/".$f;
	next if (!-l $link);
	my $rlink = &resolve_links($link);
	if ($rlink && $rlink eq $rfile) {
		push(@rv, $link);
		}
	}
closedir(LINKDIR);
return @rv;
}

# server_file_enabled(file)
# Returns 1 if a server file has an enabled symlink
sub server_file_enabled
{
my ($file) = @_;
return scalar(&server_file_links($file)) ? 1 : 0;
}

# enable_server_file(file)
# Enables a server file and rolls back if nginx -t fails
sub enable_server_file
{
my ($file) = @_;
my $rfile = &resolve_links($file);
$rfile ||= $file;
my $link = &server_file_link($rfile);
$link || return $text{'enable_elinkdir'};
return undef if (&server_file_enabled($rfile));
if (-e $link || -l $link) {
	return &text('enable_elinkexists', "<tt>".&html_escape($link)."</tt>");
	}
&symlink_logged($rfile, $link) ||
	return &text('enable_elink', "<tt>".&html_escape($link)."</tt>",
		     "<tt>".&html_escape($!)."</tt>");
my $err = &test_config();
if ($err) {
	&unlink_logged($link);
	return &text('enable_etest', "<tt>".&html_escape($err)."</tt>");
	}
return undef;
}

# disable_server_file(file)
# Disables a server file and rolls back if nginx -t fails
sub disable_server_file
{
my ($file) = @_;
my @links = &server_file_links($file);
return undef if (!@links);
my @restore = map { [ $_, readlink($_) ] } @links;
my @removed;
foreach my $link (@links) {
	if (!&unlink_logged($link)) {
		foreach my $r (@removed) {
			&symlink_logged($r->[1], $r->[0])
				if (defined($r->[1]) && !-e $r->[0] && !-l $r->[0]);
			}
		return &text('enable_eunlink',
			     "<tt>".&html_escape($link)."</tt>",
			     "<tt>".&html_escape($!)."</tt>");
		}
	my ($restore) = grep { $_->[0] eq $link } @restore;
	push(@removed, $restore) if ($restore);
	}
my $err = &test_config();
if ($err) {
	foreach my $r (@restore) {
		&symlink_logged($r->[1], $r->[0])
			if (defined($r->[1]) && !-e $r->[0] && !-l $r->[0]);
		}
	return &text('enable_etest', "<tt>".&html_escape($err)."</tt>");
	}
return undef;
}

# proxy_pass_value(&proxy_pass)
# Returns the target URL from a proxy_pass directive
sub proxy_pass_value
{
my ($pp) = @_;
my @w = @{$pp->{'words'}};
return (@w ? $w[0] : undef) || $pp->{'value'};
}

# server_proxy_target(&server|&location)
# Returns the first proxy_pass target under a server or location block
sub server_proxy_target
{
my ($conf) = @_;
my ($pp) = &find_recursive("proxy_pass", $conf);
return undef if (!$pp);
return &proxy_pass_value($pp);
}

# server_proxy_pairs(&server)
# Returns location path and proxy_pass target pairs for a server block
sub server_proxy_pairs
{
my ($server) = @_;
my @rv;
foreach my $loc (&find("location", $server)) {
	my $path = &location_path($loc) || "/";
	foreach my $pp (&find_recursive("proxy_pass", $loc)) {
		my $target = &proxy_pass_value($pp);
		push(@rv, [ $path, $target ])
			if (defined($target) && $target ne "");
		}
	}
foreach my $pp (&find("proxy_pass", $server)) {
	my $target = &proxy_pass_value($pp);
	push(@rv, [ "/", $target ])
		if (defined($target) && $target ne "");
	}
return @rv;
}

# server_root_summary(&server)
# Returns the root directory for a server block, or a missing-root message
sub server_root_summary
{
my ($server) = @_;
my $root = &server_root_value($server);
return defined($root) && $root ne "" ? &html_escape($root) :
	"<i>$text{'index_noroot'}</i>";
}

# server_root_value(&server)
# Returns the configured root directory for a server block
sub server_root_value
{
my ($server) = @_;
my $root = &find_value("root", $server);
return $root if ($root);

my @locs = &find("location", $server);
my ($rootloc) = grep { &location_path($_) eq '/' } @locs;
if ($rootloc) {
	$root = &find_value("root", $rootloc);
	return $root if ($root);
	}
return undef;
}

# server_proxy_summary(&server)
# Returns the most relevant proxy target for a server block
sub server_proxy_summary
{
my ($server) = @_;
my @pairs = &server_proxy_pairs($server);
return "<i>$text{'index_noproxy'}</i>" if (!@pairs);
return join("<br>", map {
	&html_escape($_->[0])." &#x21fe; ".&html_escape($_->[1])
	} @pairs);
}

# server_root_proxy_summary(&server)
# Returns the root directory or most relevant proxy target for a server block
sub server_root_proxy_summary
{
my ($server) = @_;
my $root = &server_root_value($server);
return &html_escape($root) if (defined($root) && $root ne "");
my $pp = &server_proxy_target($server);
return &text('server_pp', "<tt>".&html_escape($pp)."</tt>")
	if ($pp);
return &server_root_summary($server);
}

# server_root_proxy_state(&server)
# Returns booleans for whether a server has root and proxy_pass directives
sub server_root_proxy_state
{
my ($server) = @_;
my $has_root = &find_recursive("root", $server) ? 1 : 0;
my $has_proxy = &server_proxy_target($server) ? 1 : 0;
return ($has_root, $has_proxy);
}

# server_url(&server)
# Returns the browser URL for a server block
sub server_url
{
my ($server) = @_;
my $name = &find_value("server_name", $server);
return undef if (&is_default_server_block($server));
return undef if (!$name || $name !~ /^[A-Za-z0-9.-]+$/);

my ($best_scheme, $best_port);
foreach my $l (&find("listen", $server)) {
	my @w = @{$l->{'words'}};
	my $addr = shift(@w);
	next if (!$addr);
	my (undef, $port) = &split_ip_port($addr);
	my $ssl = grep { $_ eq "ssl" } @w;
	my $scheme = $ssl || $port == 443 ? "https" : "http";
	if (!$best_scheme || $scheme eq "https") {
		($best_scheme, $best_port) = ($scheme, $port);
		}
	}
$best_scheme ||= "http";
$best_port ||= $best_scheme eq "https" ? 443 : 80;
$best_port = undef if ($best_scheme eq "http" && $best_port == 80 ||
		       $best_scheme eq "https" && $best_port == 443);
return $best_scheme."://".$name.($best_port ? ":".$best_port : "")."/";
}

# find_server(id)
# Convenience function to find an HTTP server object with some ID
sub find_server
{
my ($id) = @_;
my $conf = &get_config();
my $http = &find("http", $conf);
return undef if (!$http);
my @servers = &find("server", $http);
my ($idname, $idrootdir) = split(/;/, $id);
foreach my $s (@servers) {
	my $name = &find_value("server_name", $s);
	next if ($idname ne $name);
	my $rootdir = &find_value("root", $s);
	if (!$rootdir) {
		my @locs = &find("location", $s);
		my ($rootloc) = grep { $_->{'value'} eq '/' } @locs;
		$rootdir = $rootloc ? &find_value("root", $rootloc) : "";
		}
	next if ($idrootdir ne $rootdir);
	return $s;
	}
return undef;
}

# server_id(&server)
# Given a server, return a unique ID for it as used by the module
sub server_id
{
my ($s) = @_;
my $name = &find_value("server_name", $s);
my $rootdir = &find_value("root", $s);
if (!$rootdir) {
	my @locs = &find("location", $s);
	my ($rootloc) = grep { $_->{'value'} eq '/' } @locs;
	if ($rootloc) {
		$rootdir = &find_value("root", $rootloc);
		}
	$rootdir ||= "";
	}
return $name.";".$rootdir;
}

# find_location(&server, path)
# Finds the location with some path in a given server object
sub find_location
{
my ($server, $path) = @_;
foreach my $l (&find("location", $server)) {
	return $l if (&location_path($l) eq $path);
	}
return undef;
}

# location_path(&location)
# Returns the URL path or pattern from a location block
sub location_path
{
my ($location) = @_;
my @w = @{$location->{'words'}};
return @w ? $w[$#w] : "";
}

# split_ip_port(string)
# Given an ip:port pair as used in a listen directive, split them up
sub split_ip_port
{
my ($l) = @_;
if ($l =~ /^\d+$/) {
	return (undef, $l);
	}
elsif ($l =~ /^\[(\S+)\]:(\d+)$/) {
	return ($1, $2);
	}
elsif ($l =~ /^\[(\S+)\]$/) {
	return ($1, 80);
	}
elsif ($l =~ /^(\S+):(\d+)$/) {
	return ($1, $2);
	}
else {
	return ($l, 80);
	}
}

# server_desc(&server)
# Returns a description of a server block
sub server_desc
{
my ($server) = @_;
my $name = &find_value("server_name", $server);
return $name ? &text('server_desc', "<tt>".&html_escape($name)."</tt>")
	     : $text{'server_descnone'};
}

# is_default_server_block(&server)
# Returns 1 if a server block is the package default/catch-all server
sub is_default_server_block
{
my ($server) = @_;
my $name = &find_value("server_name", $server);
return 1 if (!$name || $name eq "_" || $name eq "-");
return 0;
}

# location_desc(&server, &location)
# Returns a description of a location in a server block
sub location_desc
{
my ($server, $location) = @_;
my $name = &find_value("server_name", $server);
my $path = &location_path($location);
return $name ? &text('location_desc', "<tt>".&html_escape($name)."</tt>",
		     "<tt>".&html_escape($path)."</tt>")
	     : &text('location_descnone',
		     "<tt>".&html_escape($path)."</tt>");
}

# match_desc(string)
# Converts a location match type like ~ into a human-readable mode
sub match_desc
{
my ($m) = @_;
return $m eq "=" ? $text{'match_exact'} :
       $m eq "~" ? $text{'match_case'} :
       $m eq "~*" ? $text{'match_nocase'} :
       $m eq "^~" ? $text{'match_noregexp'} :
       $m eq "\@" ? $text{'match_named'} :
       $m eq "" ? $text{'match_default'} :
		  "Unknown match type $m";
}

sub list_match_types
{
return ("", "=", "~", "~*", "^~", "\@");
}

# create_server_link(&server)
# Creates a link from a directory like sites-enabled to sites-available for
# a new server block
sub create_server_link
{
my ($server) = @_;
if ($config{'add_link'}) {
	my $link = $server->{'file'};
	$link =~ s/^.*\///;
	$link = $config{'add_link'}."/".$link;
	&symlink_logged($server->{'file'}, $link);
	}
}

# delete_server_link(&server)
# Deletes the link from a directory like sites-enabled to sites-available for
# a server block being removed
sub delete_server_link
{
my ($server) = @_;
if ($config{'add_link'}) {
	my $file = $server->{'file'};
        my $short = $file;
        $short =~ s/^.*\///;
        opendir(LINKDIR, $config{'add_link'});
        foreach my $f (readdir(LINKDIR)) {
                if ($f ne "." && $f ne ".." &&
                    (&resolve_links($config{'add_link'}."/".$f) eq $file ||
                     $short eq $f)) {
                        &unlink_logged($config{'add_link'}."/".$f);
                        }
                }
        closedir(LINKDIR);
        }
}

# delete_server_file_if_empty(&server)
# If the file for a server is empty, delete it
sub delete_server_file_if_empty
{
my ($server) = @_;
my $lref = &read_file_lines($server->{'file'}, 1);
my $count = 0;
foreach my $l (@$lref) {
	$count++ if ($l =~ /\S/);
	}
if (!$count) {
	&unlink_logged($server->{'file'});
	}
}

# valid_cert_file(filename)
# Returns an error message if a cert file is invalid, or undef if OK
sub valid_cert_file
{
my ($file) = @_;
-r $file && !-d $file || return $text{'ssl_ecertfile'};
my $data = &read_file_contents($file);
my @lines = grep { /\S/ } split(/\r?\n/, $data);
my $begin = "-----BEGIN CERTIFICATE-----";
my $end = "-----END CERTIFICATE-----";
$data =~ /$begin/ ||
	return &text('ssl_ecertbegin', "-----BEGIN CERTIFICATE-----");
$data =~ /$end/ ||
	return &text('ssl_ecertend', "-----END CERTIFICATE-----");
for(my $i=0; $i<@lines; $i++) {
        $lines[$i] =~ /^-----(BEGIN|END)/ ||
            $lines[$i] =~ /^[A-Za-z0-9\+\/=]+$/ ||
		return &text('ssl_ecertline', $i+1);
        }
@lines > 4 || return &text('ssl_ecertlines', scalar(@lines));
return undef;
}

# valid_key_file(filename)
# Returns an error message if a key file is invalid, or undef if OK
sub valid_key_file
{
my ($file) = @_;
-r $file && !-d $file || return $text{'ssl_ekeyfile'};
my $data = &read_file_contents($file);
my @lines = grep { /\S/ } split(/\r?\n/, $data);
my $begin = "-----BEGIN (RSA )?PRIVATE KEY-----";
my $end = "-----END (RSA )?PRIVATE KEY-----";
$data =~ /$begin/ ||
	return &text('ssl_ekeybegin', "-----BEGIN PRIVATE KEY-----");
$data =~ /$end/ ||
	return &text('ssl_ekeyend', "-----END PRIVATE KEY-----");
for(my $i=0; $i<@lines; $i++) {
        $lines[$i] =~ /^-----(BEGIN|END)/ ||
	    $lines[$i] =~ /^[A-Za-z0-9\+\/=]+$/ ||
		return &text('ssl_ekeyline', $i+1);
        }
@lines > 4 || return &text('ssl_ekeylines', scalar(@lines));
return undef;
}

# can_edit_server(&server)
# Returns 1 if some server can be managed
sub can_edit_server
{
my ($server) = @_;
return 1 if (!$access{'vhosts'});
my $name = &find_value("server_name", $server);
return 0 if (!$name);
return &indexoflc($name, split(/\s+/, $access{'vhosts'})) >= 0;
}

# can_directory(dir)
# Check if some directory is under one of the allowed roots
sub can_directory
{
my ($dir) = @_;
foreach my $root (split(/\s+/, $access{'root'})) {
	return 1 if (&is_under_directory($root, $dir));
	}
return 0;
}

# switch_write_user(mode)
# If mode is 1, switch to another user for writing password files.
# If 0, switch back to root.
sub switch_write_user
{
my ($mode) = @_;
return if ($access{'user'} eq 'root');
if ($mode) {
	my @uinfo = getpwnam($access{'user'});
	@uinfo || &error("Write user $access{'user'} does not exist!");
	$) = $uinfo[3]." ".join(" ", $uinfo[2], &other_groups($uinfo[0]));
	$> = $uinfo[2];
	}
else {
	$) = 0;
	$> = 0;
	}
}

1;
