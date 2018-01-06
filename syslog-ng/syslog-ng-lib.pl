# Functions for parsing the syslog-ng config file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

@log_flags = ( "final", "fallback", "catchall" );

# get_syslog_ng_version()
# Returns the version number for syslog-ng, or undef
sub get_syslog_ng_version
{
local $out = &backquote_command("$config{'syslogng_cmd'} -V 2>&1 </dev/null",1);
return $out =~ /syslog-ng\s+([0-9\.]+)/ ? $1 : undef;
}

sub supports_sun_streams
{
return $gconfig{'os_type'} eq 'solaris';
}

# get_config()
# Parses the syslog-ng config file into an array ref of objects
sub get_config
{
if (!scalar(@get_config_cache)) {
	# First read file into tokens
	@get_config_cache = &read_config_file($config{'syslogng_conf'});
	}
return \@get_config_cache;
}

# read_config_file(file)
# Parses a config file into structures
sub read_config_file
{
local ($file) = @_;
local (@rv, @tok, @ltok, @lnum);
local $lref = &read_file_lines($file, 1);
local $cmode;
local @allincs;
for(my $lnum=0; $lnum<@$lref; $lnum++) {
	# strip comments
	my $line = $lref->[$lnum];
	$line =~ s/\r|\n//g;
	$line =~ s/#.*$//g;		# Remove hash comment
	$line =~ s/\/\/.*$//g if ($line !~ /".*\/\/.*"/);
	$line =~ s/\/\*.*\*\///g;	# Remove multi-line comment
	if ($line =~ /^\@include\s+"(.*)"/) {
		# Found an include .. replace with contents of the file(s)
		local $incs = $1;
		if ($incs !~ /^\//) {
			$file =~ /^(.*)\//;
			$incs = $1."/".$incs;
			}
		foreach my $inc (glob($incs)) {
			push(@allincs, &read_config_file($inc));
			}
		$lnum++;
		next;
		}
	$line =~ s/^\s*@.*$//g;		# Remove lines like @version
	while(1) {
		if (!$cmode && $line =~ /\/\*/) {
			# start of a C-style comment
			$cmode = 1;
			$line =~ s/\/\*.*$//g;
			}
		elsif ($cmode) {
			if ($line =~ /\*\//) {
				# end of comment
				$cmode = 0;
				$line =~ s/^.*\*\///g;
				}
			else { $line = ""; last; }
			}
		else { last; }
		}

	# split line into tokens
	undef(@ltok);
	while(1) {
		if ($line =~ /^\s*\"([^"]*)"(.*)$/) {
			# " quoted string
			push(@ltok, $1); $line = $2;
			}
		elsif ($line =~ /^\s*\'([^']*)'(.*)$/) {
			# ' quoted string
			push(@ltok, $1); $line = $2;
			}
		elsif ($line =~ /^\s*([{};\(\),\.])(.*)$/) {
			# regular word
			push(@ltok, $1); $line = $2;
			}
		elsif ($line =~ /^\s*([0-9\[\]\-]+\.[0-9\[\]\-]+\.[0-9\[\]\-]+\.[0-9\[\]\-]+)(.*)$/) {
			# IP address regexp
			push(@ltok, $1); $line = $2;
			}
		elsif ($line =~ /^\s*(\d+\.\d+\.\d+\.\d+)(.*)$/) {
			# IP address
			push(@ltok, $1); $line = $2;
			}
		elsif ($line =~ /^\s*([^{};\(\) \t,\.]+)(.*)$/) {
			# meta-character
			push(@ltok, $1); $line = $2;
			}
		else { last; }
		}
	foreach my $t (@ltok) {
		push(@tok, $t);
		push(@lnum, $lnum);
		}
	}

# parse tokens into data structures
local $i = 0;
local $j = 0;
while($i < @tok) {
	local $str = &parse_struct(\@tok, \@lnum, \$i, $j++, $file);
	if ($str) {
		push(@rv, $str);
		}
	}
push(@rv, @allincs);
return @rv;
}

# parse_struct(&tokens, &lines, &line_num, index, file)
# Reads from the given list of tokens, until one complete structure has been
# parsed. If this contains sub-structures, they are parsed too.
sub parse_struct
{
local (%str, $i, $j, $t, @vals, $str);
$i = ${$_[2]};
return undef if ($_[0]->[$i] eq ")");	# end of a parent expression
&error("Bad directive ",$_[0]->[$i]," at ",$_[1]->[$i])
	if ($_[0]->[$i] !~ /^[a-z0-9_\-]+$/i);
$str{'name'} = lc($_[0]->[$i]);
$str{'line'} = $_[1]->[$i];
$str{'index'} = $_[3];
$str{'file'} = $_[4];
$i++;

if ($_[0]->[$i] eq "(") {
	# A directive like: use_dns (no);
	# or file("/dev/console" owner(root));
	# Read the first value, and then sub-directives
	$i++;	# skip (
	local @vals;
	if ($_[0]->[$i] ne ")" && $_[0]->[$i+1] ne "(") {
		push(@vals, $_[0]->[$i++]);
		}

	# Parse extra , or .. separated values after (
	local $cont = 0;
	while(1) {
		if ($_[0]->[$i] eq ",") {
			push(@vals, $_[0]->[$i++]);
			$cont = 1;
			}
		elsif ($_[0]->[$i] eq "." && $_[0]->[$i+1] eq ".") {
			push(@vals, "..");
			if ($_[0]->[$i+2] eq ".") {
				$i++;	# Three dots!
				}
			$i += 2;
			$cont = 1;
			}
		elsif ($cont) {
			push(@vals, $_[0]->[$i++]);
			$cont = 0;
			}
		else {
			last;
			}
		}
	$str{'value'} = $vals[0];
	$str{'values'} = \@vals;
	local (@mems, $j);
	$j = 0;
	while($_[0]->[$i] ne ")") {
		if (!defined($_[0]->[$i])) { ${$_[2]} = $i; return undef; }
		local $str = &parse_struct($_[0], $_[1], \$i, $j++, $_[4]);
		push(@mems, $str);
		$i--;	# sub-directives don't have a ; at the end
		}
	$str{'type'} = 0;
	$str{'members'} = \@mems;
	$i++;		# skip the )
	$i++;		# skip the ;
	}
else {
	# A directive with children, like:  foo bar { smeg(spod); };
	# These may also form a boolean expression, like :
	#   level(info) or level(debug);
	# Or even :
	#   (level(info) or level(debug)) and facility(local7);
	while($_[0]->[$i] ne "{") {
		# Parse stuff before {
		push(@vals, $_[0]->[$i++]);
		}
	$str{'values'} = \@vals;
	$str{'value'} = $vals[0];
	$i++;	# skip the {

	# Parse the sub-structures
	local(@mems, $j);
	$str{'type'} = 1;
	$j = 0;
	while($_[0]->[$i] ne "}") {
		if (!defined($_[0]->[$i])) { ${$_[2]} = $i; return undef; }
	        if ($_[0]->[$i] eq "(" || $_[0]->[$i] eq ")") {
			# Start of a sub-expression
			push(@mems, $_[0]->[$i++]);
			}
		elsif ($_[0]->[$i] eq "and" || $_[0]->[$i] eq "or" ||
		       $_[0]->[$i] eq "not") {
			# A separator between directives
			push(@mems, $_[0]->[$i++]);
			}
		elsif ($_[0]->[$i] eq ";") {
			# Left-over ; , in an expression like level(foo));
			$i++;
			}
	        else {
			# An actual directive
			local $str = &parse_struct($_[0], $_[1], \$i, $j++, $_[4]);
			push(@mems, $str);
			if ($_[0]->[$i-1] ne ";") {
				# This wasn't the last directive
				$i--;
				$str{'partial'} = 1;
				}
			}
		}
	$str{'members'} = \@mems;
	$i += 2;	# skip trailing } and ;
	}
$str{'eline'} = $_[1]->[$i-1];	# ending line is the line number the trailing
				# ; is on
${$_[2]} = $i;
return \%str;
}

# save_directive(&config, &parent, name|&old, &new, no-write)
# Updates, creates or deletes a directive in the syslog-ng config
sub save_directive
{
local ($conf, $parent, $name, $value, $nowrite) = @_;
local $x;
local $new = !$value ? undef : ref($value) ? $value :
		{ 'name' => $name,
		  'values' => [ $value ],
		  'type' => 0 };

# Read the config file and work out the lines used
local ($mems, $memseline);
if ($parent) {
	$mems = $parent->{'members'};
	$memseline = $parent->{'eline'};
	}
else {
	$mems = $conf;
	$memseline = 0;
	foreach my $c (@$conf) {
		$memseline = $c->{'eline'} if ($c->{'eline'} > $memseline);
		}
	}
local $old = !$name ? undef : ref($name) ? $name : scalar(&find($name, $mems));
local ($idx, $oldlen, $newlen, @lines);
if ($old) {
	$idx = &indexof($old, @$mems);
	$idx >= 0 || &error("Failed to find $old in array of ",scalar(@$mems));
	$oldlen = $old->{'eline'} - $old->{'line'} + 1;
	}
local $file = $old ? $old->{'file'} :
	      $parent ? $parent->{'file'} :
			$config{'syslogng_conf'};
local $lref = $nowrite ? undef : &read_file_lines($file);
if ($new) {
	@lines = &directive_lines($new);
	$newlen = scalar(@lines);
	}

if ($old && $new) {
	# Update the directive
	$new->{'line'} = $old->{'line'};
	$new->{'eline'} = $new->{'line'}+$newlen-1;
	if ($new != $old) {
		# Replace in config
		local $idx = &indexof($old, @$mems);
		$mems->[$idx] = $new;
		}
	if (!$nowrite) {
		# Update it in the file
		&renumber($conf, $new->{'line'}, $newlen - $oldlen, $file);
		splice(@$lref, $old->{'line'}, $oldlen, @lines);
		}
	$mems[$idx] = $new;
	}
elsif ($old && !$new) {
	# Remove the directive
	splice(@$mems, $idx, 1);
	if (!$nowrite) {
		# Remove from the file
		&renumber($conf, $old->{'line'}, -$oldlen, $file);
		splice(@$lref, $old->{'line'}, $oldlen);
		}
	}
elsif (!$old && $new) {
	# Add the directive
	$new->{'line'} = $memseline+1;
	$new->{'eline'} = $memseline+$newlen;
	if (!$nowrite) {
		# Insert into the file
		&renumber($conf, $new->{'line'}, $newlen);
		splice(@$lref, $new->{'line'}, 0, @lines);
		}
	push(@$mems, $new);
	}
if (!$nowrite) {
	&flush_file_lines($file);
	}
}

# save_multiple_directives(&conf, &parent, &oldlist, &newlist, no-write)
# A convenience function to update multiple directives at once
sub save_multiple_directives
{
local ($conf, $parent, $oldlist, $newlist, $nowrite) = @_;
for(my $i=0; $i<@$oldlist || $i<@$newlist; $i++) {
	local $what = $oldlist->[$i] || $newlist->[$i];
	&save_directive($conf, $parent, $oldlist->[$i], $newlist->[$i],
		  	$nowrite);
	}
}

# renumber(&conf, line, offset, file)
# Changes the line numbers of all directives AFTER the given line in the file
sub renumber
{
local ($conf, $line, $offset, $file) = @_;
foreach my $c (@$conf) {
	$c->{'line'} += $offset
		if ($c->{'file'} eq $file && $c->{'line'} > $line);
	$c->{'eline'} += $offset
		if ($c->{'file'} eq $file && $c->{'eline'} > $line);
	&renumber($c->{'members'}, $line, $offset, $file) if ($c->{'members'});
	}
}

# directive_lines(&dir)
# Returns an array of lines used by some directive, which may be a single
# value, or have sub-members
sub directive_lines
{
local ($dir) = @_;
local @rv;
if ($dir->{'type'} == 0) {
	# A directive like use_dns(no); or file("/dev/console" owner(root));
	local $line = $dir->{'name'}."(";
	foreach my $v (@{$dir->{'values'}}) {
		$line .= &quoted_value($v)." ";
		}
	$line =~ s/\s+$//;
	foreach my $m (@{$dir->{'members'}}) {
		local ($mline) = &directive_lines($m);
		$mline =~ s/;$//;
		$line .= " ".$mline;
		}
	$line .= ");";
	push(@rv, $line);
	}
elsif ($dir->{'type'} == 1) {
	# A directive with children, like:  foo bar { smeg(spod); };
	local $line = $dir->{'name'};
	foreach my $v (@{$dir->{'values'}}) {
		$line .= " ".&quoted_value($v);
		}
	$line .= " {";
	push(@rv, $line);
	local @w;
	foreach my $m (@{$dir->{'members'}}) {
		if (ref($m)) {
			# An actual directive
			local @mlines = &directive_lines($m);
			push(@w, @mlines);
			}
		else {
			# A separator word
			if (@w) {
				# Previous one doesn't need a ;
				$w[$#w] =~ s/\s*;\s*$//;
				}
			push(@w, $m);
			}
		}
	if ($dir->{'name'} eq 'filter') {
		# All one one line
		local $line = join(" ", @w);
		$line .= ";" if ($line && $line !~ /\s*;\s*$/);
		push(@rv, "  ".$line);
		}
	else {
		# Each directive is on its own line
		push(@rv, map { "  ".$_ } @w);
		}
	push(@rv, "  };");
	}
return @rv;
}

# quoted_value(string)
# Returns some string with quotes around it, if needed
sub quoted_value
{
local ($str) = @_;
return $str =~ /^[a-z\_][a-z0-9\_]*$/i ? $str :
       $str =~ /^\d+\.\d+\.\d+\.\d+$/ ? $str :
       $str =~ /^[0-9\[\]\-]+\.[0-9\[\]\-]+\.[0-9\[\]\-]+\.[0-9\[\]\-]+$/ ? $str :
       $str eq "," || $str eq ".." ? $str :
       $str =~ /^\d+$/ ? $str :
       $str =~ /\"/ ? "'$str'" : "\"$str\"";
}

# find(name, &array)
sub find
{
local($c, @rv);
foreach $c (@{$_[1]}) {
	if ($c->{'name'} eq $_[0]) {
		push(@rv, $c);
		}
	}
return @rv ? wantarray ? @rv : $rv[0]
           : wantarray ? () : undef;
}

# find_value(name, &array)
sub find_value
{
local(@v);
@v = &find($_[0], $_[1]);
if (!@v) { return undef; }
elsif (wantarray) { return map { $_->{'value'} } @v; }
else { return $v[0]->{'value'}; }
}

sub is_syslog_ng_running
{
if ($config{'pid_file'}) {
	return &check_pid_file($config{'pid_file'});
	}
else {
	return &find_byname("syslog-ng");
	}
}

# nice_destination_type(&dest)
# Returns a human-readable destination type
sub nice_destination_type
{
local ($d) = @_;
local $file = &find_value("file", $d->{'members'});
local $usertty = &find_value("usertty", $d->{'members'});
local $program = &find_value("program", $d->{'members'});
local $pipe = &find_value("pipe", $d->{'members'});
local $udp = &find_value("udp", $d->{'members'});
local $tcp = &find_value("tcp", $d->{'members'});
local $dgram = &find_value("unix-dgram", $d->{'members'});
local $stream = &find_value("unix-stream", $d->{'members'});
return $file ? ($text{'destinations_typef'}, 0) :
       $usertty ? ($text{'destinations_typeu'}, 1) :
       $program ? ($text{'destinations_typep'}, 2) :
       $pipe ? ($text{'destinations_typei'}, 3) :
       $udp ? ($text{'destinations_typed'}, 4) :
       $tcp ? ($text{'destinations_typet'}, 5) :
       $dgram ? ($text{'destinations_typeg'}, 6) :
       $stream ? ($text{'destinations_types'}, 7) : (undef, -1);
}

# nice_destination_file(&dest)
# Returns a human-readable destination filename / hostname / etc
sub nice_destination_file
{
local ($d) = @_;
local $file = &find_value("file", $d->{'members'});
local $usertty = &find_value("usertty", $d->{'members'});
local $program = &find_value("program", $d->{'members'});
local $pipe = &find_value("pipe", $d->{'members'});
local $udp = &find_value("udp", $d->{'members'});
local $tcp = &find_value("tcp", $d->{'members'});
local $dgram = &find_value("unix-dgram", $d->{'members'});
local $stream = &find_value("unix-stream", $d->{'members'});
return $file ? "<tt>$file</tt>" :
       $program ? "<tt>$program</tt>" :
       $pipe ? "<tt>$pipe</tt>" :
       $tcp ? &text('destinations_host', "<tt>$tcp</tt>") :
       $udp ? &text('destinations_host', "<tt>$udp</tt>") :
       $dgram ? "<tt>$dgram</tt>" :
       $stream ? "<tt>$stream</tt>" :
       $usertty eq "*" ? $text{'destinations_allusers'} :
       $usertty ? &text('destinations_users', "<tt>$usertty</tt>") :
		  undef;
}

sub nice_source_desc
{
local ($source) = @_;
local @rv;
local $internal = &find("internal", $source->{'members'});
if ($internal) {
        push(@rv, $text{'sources_typei'});
        }
foreach my $t ("unix-stream", "unix-dgram") {
        local $unix = &find($t, $source->{'members'});
        local $msg = $t eq "unix-stream" ? 'sources_types' : 'sources_typed';
        if ($unix) {
                push(@rv, $text{$msg}." <tt>$unix->{'value'}</tt>");
                }
        }
foreach my $t ('tcp', 'udp') {
        local $net = &find($t, $source->{'members'});
        local $msg = $t eq "tcp" ? 'sources_typet' : 'sources_typeu';
        if ($net) {
                push(@rv, $text{$msg});
                }
        }
local $file = &find("file", $source->{'members'});
if ($file) {
        push(@rv, $text{'sources_typef'}." <tt>$file->{'value'}</tt>");
        }
local $pipe = &find("pipe", $source->{'members'});
if ($pipe) {
        push(@rv, $text{'sources_typep'}." <tt>$pipe->{'value'}</tt>");
	}
local $sun_streams = &find("sun-streams", $source->{'members'});
if ($sun_streams) {
        push(@rv, $text{'sources_typen'}." <tt>$sun_streams->{'value'}</tt>");
	}
local $network = &find("network", $source->{'members'});
if ($network) {
	local $ip = &find("ip", $network->{'members'});
        push(@rv, $text{'sources_typenw'}." <tt>$ip->{'value'}</tt>");
	}
return join(", ", @rv);
}

# check_dependencies(type, name)
# Returns a list of log objects that use some named source, destination or
# filter.
sub check_dependencies
{
local ($type, $name) = @_;
local $conf = &get_config();
local @logs = &find("log", $conf);
local @rv;
foreach my $l (@logs) {
        local @deps = &find($type, $l->{'members'});
        foreach my $d (@deps) {
                if ($d->{'value'} eq $name) {
			push(@rv, $l);
			last;
                        }
		}
	}
return @rv;
}

# rename_dependencies(type, old, new)
# Updates any log objects that use the old named type to use the new
sub rename_dependencies
{
local ($type, $oldname, $newname) = @_;
return if ($oldname eq $newname);
local $conf = &get_config();
local @logs = &find("log", $conf);
local @rv;
foreach my $l (@logs) {
        local @deps = &find($type, $l->{'members'});
	local $changed = 0;
        foreach my $d (@deps) {
                if ($d->{'value'} eq $oldname) {
			$d->{'values'} = [ $newname ];
			$changed = 1;
			}
		}
	if ($changed) {
		&save_directive($conf, undef, $l, $l, 0);
		}
	}
}

# all_log_files(file)
# Given a filename, returns all rotated versions, ordered by oldest first
sub all_log_files
{
$_[0] =~ /^(.*)\/([^\/]+)$/;
local $dir = $1;
local $base = $2;
local ($f, @rv);
opendir(DIR, &translate_filename($dir));
foreach $f (readdir(DIR)) {
	local $trans = &translate_filename("$dir/$f");
	if ($f =~ /^\Q$base\E/ && -f $trans) {
		push(@rv, "$dir/$f");
		$mtime{"$dir/$f"} = [ stat($trans) ];
		}
	}
closedir(DIR);
return sort { $mtime{$a}->[9] <=> $mtime{$b}->[9] } @rv;
}

# catter_command(file)
# Given a file that may be compressed, returns the command to output it in
# plain text, or undef if impossible
sub catter_command
{
local ($l) = @_;
local $q = quotemeta($l);
if ($l =~ /\.gz$/i) {
	return &has_command("gunzip") ? "gunzip -c $q" : undef;
	}
elsif ($l =~ /\.Z$/i) {
	return &has_command("uncompress") ? "uncompress -c $q" : undef;
	}
elsif ($l =~ /\.bz2$/i) {
	return &has_command("bunzip2") ? "bunzip2 -c $q" : undef;
	}
else {
	return "cat $q";
	}
}

# nice_filter_desc(&filter)
# Returns a human-readable description for a filter
sub nice_filter_desc
{
local ($filter) = @_;
local @rv;
foreach my $m (@{$filter->{'members'}}) {
	  if (ref($m)) {
		  # A condition like level, facility or match
		  local @v = @{$m->{'values'}};
		  if ($m->{'name'} eq 'level') {
			  if ($v[1] eq "..") {
				  push(@rv, &text('filters_priorities',
						  $v[0], $v[2]));
				  }
			  elsif (@v > 1) {
				  @v = grep { $_ ne "," } @v;
				  push(@rv, &text('filters_priorities2',
						  scalar(@v)));
				  }
			  else {
				  push(@rv, &text('filters_priority', $v[0]));
				  }
			  }
		  elsif ($m->{'name'} eq 'facility') {
			  if (@v > 1) {
				  @v = grep { $_ ne "," } @v;
				  push(@rv, &text('filters_facilities',
						  scalar(@v)));
				  }
			  else {
				  push(@rv, &text('filters_facility', $v[0]));
				  }
			  }
		  elsif ($m->{'name'} eq 'match') {
			  push(@rv, &text('filters_match', $v[0]));
			  }
		  elsif ($m->{'name'} eq 'program') {
			  push(@rv, &text('filters_program', $v[0]));
			  }
		  elsif ($m->{'name'} eq 'host') {
			  push(@rv, &text('filters_host', $v[0]));
			  }
		  elsif ($m->{'name'} eq 'netmask') {
			  push(@rv, &text('filters_netmask', $v[0]));
			  }
		  else {
			  # Unknown type??
			  push(@rv, $m->{'name'}."(".join(",", @v).")");
			  }
		  }
	  else {
		  # An and/or keyword
		  push(@rv, $m);
		  }
	  }
if (@rv > 7) {
	  @rv = ( @rv[0..7], "..." );
	  }
return join(" ", @rv);
}

# list_priorities()
# Returns a list of all priorities
sub list_priorities
{
return ( 'debug', 'info', 'notice', 'warning',
         'err', 'crit', 'alert', 'emerg' );
}

sub list_facilities
{
return ('auth', 'authpriv', 'cron', 'daemon', 'kern', 'lpr', 'mail', 'mark', 'news', 'syslog', 'user', 'uucp', 'local0', 'local1', 'local2', 'local3', 'local4', 'local5', 'local6', 'local7');
}

# apply_configuration()
# Activate the current config with a HUP signal
sub apply_configuration
{
local $pid = &check_pid_file($config{'pid_file'});
if ($pid) {
	&kill_logged('HUP', $pid);
	return undef;
	}
else {
	return $text{'apply_egone'};
	}
}

# signal_syslog()
# Tell the syslog server to re-open it's log files
sub signal_syslog
{
&apply_configuration();
}

# start_syslog_ng()
# Attempts to start the syslog server process, and returns undef on success
# or an error message on failure
sub start_syslog_ng
{
local $cmd = $config{'start_cmd'} ||
	     "$config{'syslogng_cmd'} -f ".quotemeta($config{'syslogng_conf'}).
	     " -p ".quotemeta($config{'pid_file'});
local $out = &backquote_logged("$cmd 2>&1 </dev/null");
return $? ? "<pre>$out</pre>" : undef;
}

# stop_syslog_ng()
# Attempts to stop the syslog server process, and returns undef on success
# or an error message on failure
sub stop_syslog_ng
{
if ($config{'stop_cmd'}) {
	local $out = &backquote_logged("$config{'stop_cmd'} 2>&1 </dev/null");
	return $? ? "<pre>$out</pre>" : undef;
	}
else {
	local $pid = &check_pid_file($config{'pid_file'});
	if ($pid) {
		&kill_logged('TERM', $pid);
		return undef;
		}
	else {
		return $text{'apply_egone'};
		}
	}
}

# get_other_module_logs([module])
# Returns a list of logs supplied by other modules
sub get_other_module_logs
{
local ($mod) = @_;
local @rv;
local %done;
foreach my $minfo (&get_all_module_infos()) {
	next if ($mod && $minfo->{'dir'} ne $mod);
	next if (!$minfo->{'syslog'});
	next if (!&foreign_installed($minfo->{'dir'}));
	local $mdir = &module_root_directory($minfo->{'dir'});
	next if (!-r "$mdir/syslog_logs.pl");
	&foreign_require($minfo->{'dir'}, "syslog_logs.pl");
	local $j = 0;
	foreach my $l (&foreign_call($minfo->{'dir'}, "syslog_getlogs")) {
		local $fc = $l->{'file'} || $l->{'cmd'};
		next if ($done{$fc}++);
		$l->{'minfo'} = $minfo;
		$l->{'mod'} = $minfo->{'dir'};
		$l->{'mindex'} = $j++;
		push(@rv, $l);
		}
	}
@rv = sort { $a->{'minfo'}->{'desc'} cmp $b->{'minfo'}->{'desc'} } @rv;
local $i = 0;
foreach my $l (@rv) {
	$l->{'index'} = $i++;
	}
return @rv;
}

# lock_all_files([&config])
# Takes a lock on all config files
sub lock_all_files
{
my ($conf) = @_;
$conf ||= &get_config();
@all_locked_files = &unique(map { $_->{'file'} } @$conf);
foreach my $f (@all_locked_files) {
	&lock_file($f);
	}
}

# unlock_all_files()
# Releases all config locks
sub unlock_all_files
{
foreach my $f (@all_locked_files) {
	&unlock_file($f);
	}
@all_locked_files = ( );
}

1;

