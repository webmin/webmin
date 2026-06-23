# ifupdown-lib.pl
# Shared parser helpers for /etc/network/interfaces style files

# ifupdown_get_interface_defs([file], [&seen-files], [quiet])
# Returns iface stanzas as (name, addrfam, method, options, file, line) tuples
sub ifupdown_get_interface_defs
{
my ($file, $done, $quiet) = @_;
$file ||= "/etc/network/interfaces";
$done ||= { };
return ( ) if ($done->{$file}++);
my @ret;
open(my $fh, "<", $file) || return ( );

# Read the file line by line, expanding Debian source directives as we go.
my $line = <$fh>;
my $lnum = 0;
while (defined($line)) {
	chomp($line);

	# Quiet detection keeps the old detector's trailing-comment tolerance.
	my $cmdline = $line;
	$cmdline =~ s/#.*$// if ($quiet);

	# Skip comments and empty lines outside stanzas.
	if ($cmdline =~ /^\s*#/ || $cmdline =~ /^\s*$/) {
		$line = <$fh>;
		$lnum++;
		next;
		}
	if ($cmdline =~ /^\s*auto/) {
		# Skip auto stanzas until the next top-level directive.
		$line = <$fh>;
		$lnum++;
		while(defined($line) &&
		      $line !~ /^\s*(iface|mapping|auto|source|allow-hotplug)/) {
			$line = <$fh>;
			$lnum++;
			}
		}
	elsif ($cmdline =~ /^\s*mapping/) {
		# Skip mapping stanzas until the next top-level directive.
		$line = <$fh>;
		$lnum++;
		while(defined($line) &&
		      $line !~ /^\s*(iface|mapping|auto|source|allow-hotplug)/) {
			$line = <$fh>;
			$lnum++;
			}
		}
	elsif ($cmdline =~ /^\s*(source|source-directory)\s+(\S+)/) {
		# Expand include directives recursively, with loop protection.
		my ($stype, $src) = ($1, $2);
		$line = <$fh>;
		$lnum++;
		foreach my $sfile (&ifupdown_source_files($stype, $src)) {
			push(@ret, &ifupdown_get_interface_defs($sfile, $done, $quiet));
			}
		}
	elsif ($cmdline =~ /^\s*allow-hotplug/) {
		# Hotplug lines do not define interface methods.
		$line = <$fh>;
		$lnum++;
		}
	elsif (my ($name, $addrfam, $method) =
	       ($cmdline =~ /^\s*iface\s+(\S+)\s+(\S+)\s+(\S+)\s*$/)) {
		# Read all indented or option-like lines in this iface stanza.
		my @iface_options;
		$line = <$fh>;
		$lnum++;
		while (defined($line) &&
		       $line !~ /^\s*(iface|mapping|auto|source|allow-hotplug)/) {
			if ($line =~ /^\s*#/ || $line =~ /^\s*$/) {
				$line = <$fh>;
				$lnum++;
				next;
				}
			if (my ($param, $value) =
			    ($line =~ /^\s*(\S+)\s+(.*)\s*$/)) {
				push(@iface_options, [ $param, $value ]);
				}
			elsif (my ($param) = ($line =~ /^\s*(\S+)\s*$/)) {
				push(@iface_options, [ $param, "" ]);
				}
			elsif (!$quiet) {
				&error("Error in option line: '$line' invalid");
				}
			$line = <$fh>;
			$lnum++;
			}
		push(@ret, [ $name, $addrfam, $method, \@iface_options,
			     $file, $lnum ]);
		}
	elsif ($quiet) {
		# Detection should tolerate unexpected lines and keep scanning.
		$line = <$fh>;
		$lnum++;
		}
	else {
		&error("Error reading file $file: unexpected line '$line'");
		}
	}
close($fh);
return @ret;
}

# ifupdown_source_files(type, path-or-glob)
# Returns files included by source or source-directory directives
sub ifupdown_source_files
{
my ($stype, $src) = @_;
if ($stype eq "source-directory") {
	my @files;
	if (opendir(my $dh, $src)) {
		@files = map { "$src/$_" }
			 grep { /^[A-Za-z0-9_-]+$/ } readdir($dh);
		closedir($dh);
		}
	return @files;
	}
return glob($src);
}

1;
