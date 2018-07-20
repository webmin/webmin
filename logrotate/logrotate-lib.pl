# logrotate-lib.pl
# Common functions for parsing the logrotate configuration file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

if (open(VERSION, "$module_config_directory/version")) {
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
local $file = $_[0] || $config{'logrotate_conf'};
if (!$_[0] && $get_config_cache{$file}) {
	return wantarray ? ( $get_config_cache{$file},
			     $get_config_lnum_cache{$file},
			     $get_config_files_cache{$file} )
			 : $get_config_cache{$file};
	}
local @files = ( $file );
local @rv;
local $addto = \@rv;
local $section = undef;
local $lnum = 0;
local $fh = "FILE".$file_count++;
open($fh, $file);
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
		local $incfile = $1;
		if (-d $incfile) {
			# Multiple files!
			local $f;
			opendir(DIR, $incfile);
			local @dirs = sort { $a cmp $b } readdir(DIR);
			closedir(DIR);
			foreach $f (@dirs) {
				next if ($f =~ /^\./ ||
					 $f =~ /\.rpm(save|orig|new)$/ ||
					 $f =~ /\~$/ ||
					 $f =~ /,v$/ ||
					 $f =~ /\.swp$/ ||
					 $f =~ /\.lock$/);
				local ($inc, $ilnum, $ifiles) =
					&get_config("$incfile/$f");
				push(@files, @$ifiles);
				map { $_->{'index'} += @$addto } @$inc;
				push(@$addto, @$inc);
				}
			}
		else {
			# A single file
			local ($inc, $ilnum, $ifiles) = &get_config($incfile);
			push(@files, @$ifiles);
			map { $_->{'index'} += @$addto } @$inc;
			push(@$addto, @$inc);
			}
		}
	elsif (/^\s*(\S+)\s*(.*)$/) {
		# Single directive
		local $dir =  { 'name' => $1,
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
if (!$_[0]) {
	$get_config_cache{$file} = \@rv;
	$get_config_lnum_cache{$file} = $lnum;
	$get_config_files_cache{$file} = \@files;
	}
return wantarray ? (\@rv, $lnum, \@files) : \@rv;
}

sub split_words
{
local @rv;
local $str = $_[0];
while($str =~ /^\s*"(.*)"(.*)$/ || $str =~ /^\s*(\S+)(.*)$/) {
	push(@rv, $1);
	$str = $2;
	}
return @rv;
}

sub join_words
{
return join(" ", map { /\s/ ? "\"$_\"" : $_ } @_);
}

# find(name, &config)
sub find
{
local @rv = grep { lc($_->{'name'}) eq lc($_[0]) } @{$_[1]};
return wantarray ? @rv : $rv[0];
}

# find_value(name, &config)
sub find_value
{
local @rv = map { defined($_->{'script'}) ? $_->{'script'} : $_->{'value'} }
		grep { lc($_->{'name'}) eq lc($_[0]) } @{$_[1]};
return wantarray ? @rv : $rv[0];
}

# get_logrotate_version(&out)
sub get_logrotate_version
{
local $out = &backquote_command("$config{'logrotate'} -v 2>&1", 1);
${$_[0]} = $out if ($_[0]);
return $out =~ /logrotate\s+([0-9\.]+)\s/ ||
       $out =~ /logrotate\-([0-9\.]+)\s/ ? $1 : undef;
}

# get_period(&conf)
sub get_period
{
foreach $p ("daily", "weekly", "monthly") {
	local $ex = &find($p, $_[0]);
	return $p if ($ex);
	}
return undef;
}

# save_directive(&parent, &old|name, &new, [indent])
sub save_directive
{
local $conf = $_[0]->{'members'};
local $old = !defined($_[1]) ? undef : ref($_[1]) ? $_[1] : &find($_[1], $conf);
local $lref = &read_file_lines($old ? $old->{'file'} : $_[0]->{'file'});
local $new = !defined($_[2]) ? undef : ref($_[2]) ? $_[2] :
			{ 'name' => $old ? $old->{'name'} : $_[1],
		     	  'value' => $_[2] };
local @lines = &directive_lines($new, $_[3]) if ($new);
local $gparent = &get_config_parent();
if ($old && $new) {
	# Update
	local $oldlines = $old->{'eline'} - $old->{'line'} + 1;
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
	local $oldlines = $old->{'eline'} - $old->{'line'} + 1;
	splice(@$lref, $old->{'line'}, $old->{'eline'} - $old->{'line'} + 1);
	splice(@$conf, $old->{'index'}, 1);
	&renumber($gparent, $old->{'file'}, $old->{'line'}, -$oldlines);
	}
elsif (!$old && $new && $_[0]->{'global'} && !$new->{'members'}) {
	# Add at the start of the file
	if (defined($_[0]->{'line'})) {
		splice(@$lref, 0, 0, @lines);
		$new->{'line'} = 0;
		$new->{'eline'} = $new->{'line'} + scalar(@lines) - 1;
		$new->{'file'} = $_[0]->{'file'};
		&renumber($gparent, $new->{'file'}, $new->{'line'}-1, scalar(@lines));
		}
	$new->{'index'} = 0;
	splice(@$conf, 0, 0, $new);
	}
elsif (!$old && $new) {
	# Add (to end of section)
	if (defined($_[0]->{'line'})) {
		if (!$new->{'file'} || $_[0]->{'file'} eq $new->{'file'}) {
			# Adding to parent file
			splice(@$lref, $_[0]->{'eline'}, 0, @lines);
			$new->{'line'} = $_[0]->{'eline'};
			$new->{'eline'} = $new->{'line'} + scalar(@lines) - 1;
			$new->{'file'} = $_[0]->{'file'};
			&renumber($gparent, $new->{'file'}, $new->{'line'}-1, scalar(@lines));
			}
		else {
			# Adding to another file
			local $lref2 = &read_file_lines($new->{'file'});
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
sub renumber
{
return if (!$_[3]);
if ($_[0]->{'file'} eq $_[1] && $_[0] ne $_[4]) {
	$_[0]->{'line'} += $_[3] if ($_[0]->{'line'} > $_[2]);
	$_[0]->{'eline'} += $_[3] if ($_[0]->{'eline'} > $_[2]);
	}
if ($_[0]->{'members'}) {
	local $c;
	foreach $c (@{$_[0]->{'members'}}) {
		&renumber($c, $_[1], $_[2], $_[3], $_[4]);
		}
	}
}

# directive_lines(&dir, indent)
sub directive_lines
{
local @rv;
if ($_[0]->{'members'}) {
	push(@rv, $_[1].&join_words(@{$_[0]->{'name'}})." {");
	foreach $m (@{$_[0]->{'members'}}) {
		push(@rv, &directive_lines($m, $_[1]."\t"));
		}
	push(@rv, $_[1]."}");
	}
elsif ($_[0]->{'script'}) {
	push(@rv, $_[1].$_[0]->{'name'});
	foreach $s (split(/\n/, $_[0]->{'script'})) {
		push(@rv, $_[1].$s);
		}
	push(@rv, $_[1]."endscript");
	}
else {
	push(@rv, $_[1].$_[0]->{'name'}.
		  ($_[0]->{'value'} eq "" ? "" : " ".$_[0]->{'value'}));
	}
return @rv;
}

# delete_if_empty(file)
sub delete_if_empty
{
local $conf = &get_config();
local %files = map { $_, 1 } &unique(map { $_->{'file'} } @$conf);
&unlink_file($_[0]) if (!$files{$_[0]});
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
local $conf = &get_config();
local $temp = &transname();
open(TEMP, ">$temp");
local $c;
foreach $c (@$conf) {
	if (!$c->{'members'}) {
		print TEMP map { "$_\n" } &directive_lines($c);
		}
	}
print TEMP map { "$_\n" } &directive_lines($_[0]);
close(TEMP);
local $out = &backquote_logged("$config{'logrotate'} -f $temp 2>&1");
return ($?, $out);
}

# get_add_file([filename])
# Returns the file to which new logrotate sections should be added
sub get_add_file
{
local ($filename) = @_;
$filename =~ s/\*/ALL/g;
if ($config{'add_file'} && -d $config{'add_file'} && $filename) {
	# Adding to a new file in a directory
	return "$config{'add_file'}/$filename.conf";
	}
elsif ($config{'add_file'} && !-d $config{'add_file'}) {
	# Make sure file is valid
	local ($conf, $lnum, $files) = &get_config();
	if (&indexof($config{'add_file'}, @$files) >= 0) {
		return $config{'add_file'};
		}
	}
return $config{'logrotate_conf'};
}

1;

