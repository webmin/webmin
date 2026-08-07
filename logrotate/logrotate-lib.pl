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

# get_config_parent()
# Returns the parsed global config while keeping the writable local file as
# its save target.  Callers must materialize that file before global writes.
sub get_config_parent
{
if (!$get_config_parent_cache) {
	local ($conf, $lines) = &get_config();
	# Even when members came from the vendor config, never make /usr the
	# destination for newly-added global directives.
	$get_config_parent_cache = { 'members' => $conf,
		 		     'file' => $config{'logrotate_conf'},
		 		     'line' => 0,
		 		     'eline' => $lines,
				     'global' => 1 };
	}
return $get_config_parent_cache;
}

# get_main_config_file()
# Returns the local main config, or the vendor default if no local one exists
sub get_main_config_file
{
return $config{'logrotate_conf'} if (-e $config{'logrotate_conf'});
return $config{'vendor_logrotate_conf'}
	if ($config{'vendor_logrotate_conf'});
return $config{'logrotate_conf'};
}

# is_vendor_main_config(file)
# Returns 1 if a file is the vendor-provided main config
sub is_vendor_main_config
{
my ($file) = @_;
return $config{'vendor_logrotate_conf'} &&
	&same_file($file, $config{'vendor_logrotate_conf'});
}

# relative_config_path(file, directory)
# Returns a file's path relative to a config directory
sub relative_config_path
{
my ($file, $dir) = @_;
return undef if (!$file || !$dir);
$dir =~ s/\/+$//;
$dir .= '/';
return $file =~ /^\Q$dir\E(.+)$/ ? $1 : undef;
}

# is_vendor_config_file(file)
# Returns 1 if a drop-in comes from the vendor directory
sub is_vendor_config_file
{
my ($file) = @_;
return defined(&relative_config_path(
	$file, $config{'vendor_add_file'}));
}

# get_local_override_file(vendor-file)
# Returns the local path that overrides a vendor drop-in
sub get_local_override_file
{
my ($file) = @_;
my $rel = &relative_config_path($file, $config{'vendor_add_file'});
return undef if (!defined($rel) || !$config{'add_file'});
return $config{'add_file'}.'/'.$rel;
}

# get_vendor_config_file(local-file)
# Returns the vendor file shadowed by a local drop-in, if any
sub get_vendor_config_file
{
my ($file) = @_;
my $rel = &relative_config_path($file, $config{'add_file'});
return undef if (!defined($rel) || !$config{'vendor_add_file'});
my $vendor = $config{'vendor_add_file'}.'/'.$rel;
return -f $vendor ? $vendor : undef;
}

# flush_logrotate_config_cache()
# Clears parsed config state after creating a local override
sub flush_logrotate_config_cache
{
%get_config_cache = ( );
%get_config_lnum_cache = ( );
%get_config_files_cache = ( );
$get_config_parent_cache = undef;
}

# copy_vendor_config(source, destination)
# Copies a vendor config to the writable local tree
sub copy_vendor_config
{
my ($source, $dest) = @_;

# An existing regular destination is already a usable override.  Refuse a
# destination symlink or other file type so it cannot redirect this write.
if (-e $dest || -l $dest) {
	if (-f $dest && !-l $dest) {
		&flush_logrotate_config_cache();
		return $dest;
		}
	&error(&text('save_eoverride', "<tt>".
		&html_escape($dest)."</tt>"));
	}

# Create missing subdirectories before copying the complete vendor file.
# Following a source symlink produces an editable snapshot, not another link.
my $dir = $dest;
$dir =~ s/\/[^\/]+$//;
&make_dir_recursive($dir, 0755) if (!-d $dir);
my ($ok, $err) = &copy_source_dest($source, $dest, 1);

# Do not leave a partial override behind after a copy or chmod failure, since
# even an incomplete local file would hide the valid vendor configuration.
if (!$ok || !&set_ownership_permissions(undef, undef, 0644, $dest)) {
	$err ||= $!;
	&unlink_file($dest) if (-e $dest || -l $dest);
	&error(&text('save_ecopy', "<tt>".&html_escape($dest)."</tt>",
		&html_escape($err)));
	}

# Force the next read to select and parse the newly-created local file.
&flush_logrotate_config_cache();
return $dest;
}

# ensure_local_main_config()
# Creates a writable local main config when only the vendor default exists
sub ensure_local_main_config
{
my $main = &get_main_config_file();
return $config{'logrotate_conf'}
	if (!&is_vendor_main_config($main));
return &copy_vendor_config($main, $config{'logrotate_conf'});
}

# ensure_local_config_override(vendor-file)
# Creates a writable local copy that shadows a vendor drop-in
sub ensure_local_config_override
{
my ($file) = @_;
my $local = &get_local_override_file($file);
return $file if (!$local);
return &copy_vendor_config($file, $local);
}

# list_config_dir_files(directory, [relative-subdirectory])
# Returns relative and absolute paths for regular files below a directory
sub list_config_dir_files
{
my ($dir, $subdir) = @_;
my $path = $subdir ? $dir.'/'.$subdir : $dir;
opendir(my $dh, $path) || return ( );
my @names = sort { $a cmp $b } readdir($dh);
closedir($dh);
my @rv;
foreach my $name (@names) {
	next if ($name eq '.' || $name eq '..');
	my $rel = $subdir ? $subdir.'/'.$name : $name;
	my $file = $dir.'/'.$rel;

	# Match find without -L: ignore symlinks, recurse into real directories,
	# and return only regular files with paths relative to the scanned root.
	next if (-l $file);
	if (-d $file) {
		push(@rv, &list_config_dir_files($dir, $rel));
		}
	elsif (-f $file) {
		push(@rv, [ $rel, $file ]);
		}
	}
return @rv;
}

# get_add_file_configs([&already-loaded-files])
# Returns the effective vendor and local configs loaded by logrotate-all
sub get_add_file_configs
{
my ($files) = @_;
return ( ) if (!$config{'scan_add_file'});

# Collect the same relative names produced by the wrapper's recursive find.
# Processing the local tree last records its regular files directly.
my %effective;
foreach my $dir ($config{'vendor_add_file'}, $config{'add_file'}) {
	next if (!$dir || !-d $dir);
	foreach my $entry (&list_config_dir_files($dir)) {
		$effective{$entry->[0]} = $entry->[1];
		}
	}

# Match the wrapper's stable lexical order and omit files already reached by
# an explicit include in the main configuration.  The existence check also
# honors a local non-regular counterpart exactly as the wrapper does.
my @rv;
foreach my $name (sort { $a cmp $b } keys %effective) {
	my $local = $config{'add_file'} ?
		$config{'add_file'}.'/'.$name : undef;
	my $f = $local && -e $local ? $local : $effective{$name};
	next if ($files &&
		 grep { &same_file($_, $f) } @$files);
	push(@rv, $f);
	}
return @rv;
}

# get_scheduled_logrotate_command()
# Returns the distro wrapper, or a command for the effective config files
sub get_scheduled_logrotate_command
{
# The distro wrapper discovers the effective drop-in set on every run, so it
# remains correct when packages or administrators add files later.
if ($config{'logrotate_all'} && -x $config{'logrotate_all'}) {
	return &quote_path($config{'logrotate_all'});
	}

# Preserve the historical command exactly on systems that do not opt into
# external or vendor configuration discovery.
if (!$config{'vendor_logrotate_conf'} && !$config{'vendor_add_file'} &&
    !$config{'scan_add_file'}) {
	return &has_command($config{'logrotate'})." ".
		$config{'logrotate_conf'};
	}

# If the configured wrapper is unavailable, build a usable command from the
# effective main config and the drop-ins visible at schedule creation time.
my $main = &get_main_config_file();
my (undef, undef, $files) = &get_config($main);
my @configs = ($main, &get_add_file_configs($files));
my $program = &has_command($config{'logrotate'}) || $config{'logrotate'};
return &quote_path($program).' '.
	join(' ', map { &quote_path($_) } @configs);
}

# get_config([file])
# Returns a list of logrotate config file entries
sub get_config
{
my ($argfile) = @_;
my $file = $argfile || &get_main_config_file();
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
		push(@name, &split_quoted_string($1));
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
		push(@name, &split_quoted_string($_));
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
	foreach my $f (&get_add_file_configs(\@files)) {
		my ($inc, undef, $ifiles) = &get_config($f);
		map { $_->{'index'} += @rv } @$inc;
		push(@rv, @$inc);
		push(@files, @$ifiles);
		}
	$get_config_cache{$file} = \@rv;
	$get_config_lnum_cache{$file} = $lnum;
	$get_config_files_cache{$file} = \@files;
	}
return wantarray ? (\@rv, $lnum, \@files) : \@rv;
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
my $new = !defined($newv) ? undef : ref($newv) ? $newv :
			{ 'name' => $old ? $old->{'name'} : $oldv,
		     	  'value' => $newv };

# Refuse direct vendor writes even if a caller forgets to materialize the
# local copy first. New log sections may still be written to their explicit
# local file while the global defaults continue to come from the vendor file.
my $vendor_file;
if ($old) {
	my $shadowed_vendor = &get_vendor_config_file($old->{'file'});
	if (&is_vendor_main_config($old->{'file'}) ||
	    &is_vendor_config_file($old->{'file'})) {
		$vendor_file = $old->{'file'};
		}
	elsif ($shadowed_vendor &&
	       &same_file($old->{'file'}, $shadowed_vendor)) {
		$vendor_file = $shadowed_vendor;
		}
	}
elsif (!$old && $new && !$new->{'members'} && $parent->{'global'} &&
	&is_vendor_main_config(&get_main_config_file())) {
	$vendor_file = &get_main_config_file();
	}
&error(&text('save_evendorwrite',
	"<tt>".&html_escape($vendor_file)."</tt>")) if ($vendor_file);

my $lref = &read_file_lines($old ? $old->{'file'} : $parent->{'file'});
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
# Removes a file if it has no more parsed entries, unless it is a local
# override whose continued existence is needed to hide a vendor file
sub delete_if_empty
{
my ($file) = @_;
return if (&get_vendor_config_file($file));
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
print TEMP map { "$_\n" } &directive_lines($dir);
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
