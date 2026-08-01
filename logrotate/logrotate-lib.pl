# logrotate-lib.pl
# Common functions for parsing the logrotate configuration file.

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

if (open(VERSION, "<$module_config_directory/version")) {
	chop($logrotate_version = <VERSION>);
	close(VERSION);
	}

# Use sample config if it exists but real config doesn't yet
if (!-r $config{'logrotate_conf'} && -r $config{'sample_conf'}) {
	&copy_source_dest($config{'sample_conf'}, $config{'logrotate_conf'});
	}

sub get_config_parent
{
if (!$get_config_parent_cache) {
	local ($conf, $lines) = &get_config();
	$get_config_parent_cache = { 'members' => $conf,
		 		     'file' => $config{'logrotate_conf'},
		 		     'line' => 0,
		 		     'eline' => $lines,
				     'global' => 1 };
	}
return $get_config_parent_cache;
}

# get_config([file])
# Returns a list of logrotate config file entries
sub get_config
{
my ($argfile) = @_;
my $file = $argfile || $config{'logrotate_conf'};
if (!$argfile && $get_config_cache{$file}) {
	return wantarray ? ( $get_config_cache{$file},
			     $get_config_lnum_cache{$file},
			     $get_config_files_cache{$file} )
			 : $get_config_cache{$file};
	}
my @files = ( $file );
my @rv;
my $addto = \@rv;
my $section;
my $lnum = 0;
my $fh = "FILE".$file_count++;
open($fh, "<".$file);
while(<$fh>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^\s*(.*)\{\s*$/) {
		# Start of a section
		push(@name, &split_words($1));
		$section = { 'name' => [ @name ],
			     'members' => [ ],
			     'index' => scalar(@$addto),
			     'line' => defined($namestart) ? $namestart : $lnum,
			     'eline' => $lnum,
			     'file' => $file };
		push(@$addto, $section);
		$addto = $section->{'members'};
		@name = ( );
		$namestart = undef;
		}
	elsif ((/^\s*\// || /^\s*"\//) && !$section) {
		# A path before a section
		$namestart = $lnum if (!@name);
		push(@name, &split_words($_));
		}
	elsif (/^\s*}\s*$/) {
		# End of a section
		$addto = \@rv;
		$section->{'eline'} = $lnum;
		$section = undef;
		}
	elsif (/^\s*include\s+(.*)$/i) {
		# Including other directives files
		my $incfile = $1;
		if (-d $incfile) {
			# Multiple files!
			my $f;
			opendir(DIR, $incfile);
			my @dirs = sort { $a cmp $b } readdir(DIR);
			closedir(DIR);
			foreach $f (@dirs) {
				next if ($f =~ /^\./ ||
					 $f =~ /\.rpm(save|orig|new)$/ ||
					 $f =~ /\~$/ ||
					 $f =~ /,v$/ ||
					 $f =~ /\.swp$/ ||
					 $f =~ /\.lock$/);
				my ($inc, $ilnum, $ifiles) =
					&get_config("$incfile/$f");
				push(@files, @$ifiles);
				map { $_->{'index'} += @$addto } @$inc;
				push(@$addto, @$inc);
				}
			}
		else {
			# A single file
			my ($inc, $ilnum, $ifiles) = &get_config($incfile);
			push(@files, @$ifiles);
			map { $_->{'index'} += @$addto } @$inc;
			push(@$addto, @$inc);
			}
		}
	elsif (/^\s*(\S+)\s*(.*)$/) {
		# Single directive
		my $dir =  { 'name' => $1,
			     'value' => $2,
			     'index' => scalar(@$addto),
			     'line' => $lnum,
			     'eline' => $lnum,
			     'file' => $file };
		push(@$addto, $dir);
		if ($1 eq 'postrotate' || $1 eq 'prerotate') {
			# Followed by a multi-line script!
			while(<$fh>) {
				$lnum++;
				s/\r|\n//g;
				last if (/^\s*(endscript|endrotate)\s*$/);
				s/^\s+//;
				$dir->{'script'} .= $_."\n";
				}
			$dir->{'eline'} = $lnum;
			}
		}
	$lnum++;
	}
close($fh);
if (!$argfile) {
	$get_config_cache{$file} = \@rv;
	$get_config_lnum_cache{$file} = $lnum;
	$get_config_files_cache{$file} = \@files;
	}
return wantarray ? (\@rv, $lnum, \@files) : \@rv;
}

# split_words(string)
# Split a string like 'foo "bar" baz' into words
sub split_words
{
my ($str) = @_;
my @rv;
while($str =~ /^\s*"(.*)"(.*)$/ || $str =~ /^\s*(\S+)(.*)$/) {
	push(@rv, $1);
	$str = $2;
	}
return @rv;
}

# join_words(word, ...)
# Joins an array of words into a string, with quotes if needed
sub join_words
{
return join(" ", map { /\s/ ? "\"$_\"" : $_ } @_);
}

# find(name, &config)
# Returns an object or objects from the config with some name
sub find
{
my ($name, $conf) = @_;
my @rv = grep { lc($_->{'name'}) eq lc($name) } @$conf;
return wantarray ? @rv : $rv[0];
}

# find_value(name, &config)
# Returns a value or values from the config with some name
sub find_value
{
my ($name, $conf) = @_;
my @rv = map { defined($_->{'script'}) ? $_->{'script'} : $_->{'value'} }
	     grep { lc($_->{'name'}) eq lc($name) } @$conf;
return wantarray ? @rv : $rv[0];
}

# get_logrotate_version([&out])
# Returns the version number, and saves the full -v output to the out param
sub get_logrotate_version
{
my ($rv) = @_;
my $out = &backquote_command("$config{'logrotate'} -v 2>&1", 1);
$$rv = $out if ($rv);
return $out =~ /logrotate\s+([0-9\.]+)\s/ ||
       $out =~ /logrotate\-([0-9\.]+)\s/ ? $1 : undef;
}

# get_period(&conf)
# Returns the rotation time period set in the config
sub get_period
{
my ($conf) = @_;
foreach my $p ("daily", "weekly", "monthly") {
	my $ex = &find($p, $conf);
	return $p if ($ex);
	}
return undef;
}

# save_directive(&parent, &old|name, &new, [indent])
# Update a single entry in the config, identified by either name or
# the direcctive being replaced
sub save_directive
{
my ($parent, $oldv, $newv, $indent) = @_;
my $conf = $parent->{'members'};
my $old = !defined($oldv) ? undef : ref($oldv) ? $oldv : &find($oldv, $conf);
my $lref = &read_file_lines($old ? $old->{'file'} : $parent->{'file'});
my $new = !defined($newv) ? undef : ref($newv) ? $newv :
			{ 'name' => $old ? $old->{'name'} : $oldv,
		     	  'value' => $newv };
my @lines = &directive_lines($new, $indent) if ($new);
my $gparent = &get_config_parent();
if ($old && $new) {
	# Update
	my $oldlines = $old->{'eline'} - $old->{'line'} + 1;
	splice(@$lref, $old->{'line'}, $oldlines, @lines);
	$new->{'line'} = $old->{'line'};
	$new->{'index'} = $old->{'index'};
	$new->{'file'} = $old->{'file'};
	$new->{'eline'} = $new->{'line'} + scalar(@lines) - 1;
	%$old = %{$new};
	&renumber($gparent, $old->{'file'}, $old->{'eline'},
		  scalar(@lines) - $oldlines, $old);
	}
elsif ($old && !$new) {
	# Delete
	my $oldlines = $old->{'eline'} - $old->{'line'} + 1;
	splice(@$lref, $old->{'line'}, $old->{'eline'} - $old->{'line'} + 1);
	splice(@$conf, $old->{'index'}, 1);
	&renumber($gparent, $old->{'file'}, $old->{'line'}, -$oldlines);
	}
elsif (!$old && $new && $parent->{'global'} && !$new->{'members'}) {
	# Add at the start of the file
	if (defined($parent->{'line'})) {
		splice(@$lref, 0, 0, @lines);
		$new->{'line'} = 0;
		$new->{'eline'} = $new->{'line'} + scalar(@lines) - 1;
		$new->{'file'} = $parent->{'file'};
		&renumber($gparent, $new->{'file'}, $new->{'line'}-1, scalar(@lines));
		}
	$new->{'index'} = 0;
	splice(@$conf, 0, 0, $new);
	}
elsif (!$old && $new) {
	# Add (to end of section)
	if (defined($parent->{'line'})) {
		if (!$new->{'file'} || $parent->{'file'} eq $new->{'file'}) {
			# Adding to parent file
			splice(@$lref, $parent->{'eline'}, 0, @lines);
			$new->{'line'} = $parent->{'eline'};
			$new->{'eline'} = $new->{'line'} + scalar(@lines) - 1;
			$new->{'file'} = $parent->{'file'};
			&renumber($gparent, $new->{'file'}, $new->{'line'}-1, scalar(@lines));
			}
		else {
			# Adding to another file
			my $lref2 = &read_file_lines($new->{'file'});
			$new->{'line'} = scalar(@$lref2);
			$new->{'eline'} = $new->{'line'} + scalar(@lines) - 1;
			push(@$lref2, @lines);
			}
		}
	$new->{'index'} = scalar(@$conf);
	push(@$conf, $new);
	}
}

# renumber(&object, file, startline, count, [&skip])
# Update line numbers in the config that are in some file and after
# some line
sub renumber
{
my ($conf, $file, $start, $count, $skip) = @_;
return if (!$count);
if ($conf->{'file'} eq $file && $conf ne $skip) {
	$conf->{'line'} += $count if ($conf->{'line'} > $start);
	$conf->{'eline'} += $count if ($conf->{'eline'} > $start);
	}
if ($conf->{'members'}) {
	foreach my $c (@{$conf->{'members'}}) {
		&renumber($c, $file, $start, $count, $skip);
		}
	}
}

# directive_lines(&dir, indent)
# Returns an array of lines to add to the config file for some directive
sub directive_lines
{
my ($dir, $indent) = @_;
my @rv;
if ($dir->{'members'}) {
	push(@rv, $indent.&join_words(@{$dir->{'name'}})." {");
	foreach my $m (@{$dir->{'members'}}) {
		push(@rv, &directive_lines($m, $indent."\t"));
		}
	push(@rv, $indent."}");
	}
elsif ($dir->{'script'}) {
	push(@rv, $indent.$dir->{'name'});
	foreach my $s (split(/\n/, $dir->{'script'})) {
		push(@rv, $indent.$s);
		}
	push(@rv, $indent."endscript");
	}
else {
	push(@rv, $indent.$dir->{'name'}.
		  ($dir->{'value'} eq "" ? "" : " ".$dir->{'value'}));
	}
return @rv;
}

# delete_if_empty(file)
# Remove a file if it has no more lines in the config
sub delete_if_empty
{
my ($file) = @_;
my $conf = &get_config();
my %files = map { $_, 1 } &unique(map { $_->{'file'} } @$conf);
&unlink_file($file) if (!$files{$file});
}

%global_default = ( "nocompress" => "",
		    "compress" => undef,
		    "nodelaycompress" => "",
		    "delaycompress" => undef,
		    "ifempty" => "",
		    "notifempty" => undef,
		    "nocopytruncate" => "",
		    "copytruncate" => undef,
		    "nomissingok" => "",
		    "missingok" => undef,
		    "rotate" => 0,
		    "create" => "",
		    "nocreate" => undef,
		    "noolddir" => "",
		    "olddir" => undef,
		    "ext" => undef,
		    "mail" => undef,
		    "nomail" => "",
		    "maillast" => "",
		    "mailfirst" => undef,
		    "errors" => undef,
		    "postrotate" => undef,
		    "prerotate" => undef,
		    "errors" => undef,
		  );

# rotate_log_now(&log)
# Call logrotate on a config fragment file to rotate just one set of logs
# immediately.
sub rotate_log_now
{
my ($dir) = @_;
my $conf = &get_config();
my $temp = &transname();
open(TEMP, ">$temp");
foreach my $c (@$conf) {
	if (!$c->{'members'}) {
		print TEMP map { "$_\n" } &directive_lines($c);
		}
	}
print TEMP map { "$_\n" } &directive_lines($conf);
close(TEMP);
&set_ownership_permissions(undef, undef, 0644, $temp);
my $out = &backquote_logged("$config{'logrotate'} -f $temp 2>&1");
return ($?, $out);
}

# get_add_file([filename])
# Returns the file to which new logrotate sections should be added
sub get_add_file
{
my ($filename) = @_;
$filename =~ s/\*/ALL/g;
if ($config{'add_file'} && -d $config{'add_file'} && $filename) {
	# Adding to a new file in a directory
	return "$config{'add_file'}/$filename.conf";
	}
elsif ($config{'add_file'} && !-d $config{'add_file'}) {
	# Make sure file is valid
	my ($conf, $lnum, $files) = &get_config();
	if (&indexof($config{'add_file'}, @$files) >= 0) {
		return $config{'add_file'};
		}
	}
return $config{'logrotate_conf'};
}

1;

