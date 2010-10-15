# grub-lib.pl
# Functions for parsing and editing a grub menu file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

%title_order = ( 'lock', 10,
		 'root', 5,
		 'kernel', 4,
		 'chainloader', -1,
		 'initrd', 2,
		 'boot', 1 );

# get_menu_config()
# Parses the config file into a list of title structures
sub get_menu_config
{
local $lnum = 0;
local (@rv, $title);
open(CONF, $config{'menu_file'});
while(<CONF>) {
	s/#.*$//;
	s/\r|\n//g;
	if (/^\s*(\S+)\s*=\s*(.*)/ || /^\s*(\S+)\s*(.*)/) {
		if ($title && $1 ne 'title') {
			# directive in an existing section
			if (defined($title->{$1})) {
				# Multiple values!
				$title->{$1} .= "\0".$2;
				}
			else {
				$title->{$1} = $2;
				}
			$title->{'eline'} = $lnum;
			}
		else {
			# top-level title or option
			local $d = { 'name' => $1,
				     'value' => $2,
				     'line' => $lnum,
				     'eline' => $lnum,
				     'index' => scalar(@rv) };
			push(@rv, $d);
			$title = $d if ($1 eq 'title');
			}
		}
	$lnum++;
	}
close(CONF);
return \@rv;
}

# save_directive(&config, &old|name, &new)
sub save_directive
{
local $old;
if (!$_[1] || ref($_[1])) {
	$old = $_[1];
	}
else {
	$old = &find($_[1], $_[0]);
	}
local @lines;
if (defined($_[2])) {
	@lines = ( "$_[2]->{'name'} $_[2]->{'value'}" );
	foreach $k (sort { $title_order{$b} <=> $title_order{$a} }
			 keys %{$_[2]}) {
		if ($k !~ /^(name|value|line|eline|index)$/) {
			if ($_[2]->{$k} eq '') {
				push(@lines, $k);
				}
			else {
				foreach my $v (split(/\0/, $_[2]->{$k})) {
					push(@lines, $k." ".$v);
					}
				}
			}
		}
	}
local $lref = &read_file_lines($config{'menu_file'});
if ($old) {
	# Replace one entry in the file
	splice(@$lref, $old->{'line'}, $old->{'eline'} - $old->{'line'} + 1,
	       @lines);
	}
elsif ($_[2]->{'name'} eq 'title') {
	# Append to file
	push(@$lref, "", @lines);
	}
else {
	# Insert before titles
	local $t = &find("title", $_[0]);
	if ($t) {
		splice(@$lref, $t->{'line'}, 0, @lines);
		}
	else {
		push(@$lref, "", @lines);
		}
	}
}

# swap_directives(&dir1, &dir2)
# Swaps two blocks in the config file
sub swap_directives
{
my ($dir1, $dir2) = @_;
local $lref = &read_file_lines($config{'menu_file'});
if ($dir1->{'line'} > $dir2->{'line'}) {
	($dir1, $dir2) = ($dir2, $dir1);
	}
my @lines1 = @$lref[$dir1->{'line'} .. $dir1->{'eline'}];
my @lines2 = @$lref[$dir2->{'line'} .. $dir2->{'eline'}];
my $len1 = $dir1->{'eline'} - $dir1->{'line'} + 1;
my $len2 = $dir2->{'eline'} - $dir2->{'line'} + 1;
splice(@$lref, $dir2->{'line'}, $len2, @lines1);
splice(@$lref, $dir1->{'line'}, $len1, @lines2);
}

# find(name, &config)
sub find
{
local @rv;
foreach $c (@{$_[1]}) {
	push(@rv, $c) if ($c->{'name'} eq $_[0]);
	}
return wantarray ? @rv : $rv[0];
}

# find_value(name, &config)
sub find_value
{
local @rv = &find($_[0], $_[1]);
return !@rv ? undef : wantarray ? map { $_->{'value'} } @rv : $rv[0]->{'value'};
}

# linux_to_bios(device)
# Converts a Linux device file like /dev/hda into a GRUB bios disk like (hd0)
sub linux_to_bios
{
if ($_[0] =~ /^(\/dev\/[hs]d[a-z])(\d+)$/ ||
    $_[0] =~ /^(\/dev\S+\/)part(\d+)$/ ||
    $_[0] =~ /^(\/dev\S+c\d+d\d+)p(\d+)$/) {
	# A partition on a disk .. get the disk's device, and then add the part
	local ($dev, $part) = ($1, $2-1);
	$dev .= "disc" if ($dev =~ /\/$/);
	local $dsk = &linux_to_bios($dev);
	$dsk =~ /^\(([a-z]+\d+)\)$/ || return undef;
	return "($1,$part)";
	}
local @map = &get_device_map();
local @st = stat($_[0]);
if (@map) {
	foreach $m (@map) {
		local @mst = stat($m->[1]);
		if ($m->[1] eq $_[0] ||
		    @mst && @st && $mst[0] == $st[0] && $mst[1] == $st[1]) {
			return $m->[0];
			}
		}
	}

# Have to guess based on the device name :(
return $_[0] =~ /\/dev\/hd([a-d])$/ ? "(hd".(ord($1)-97).")" :
       $_[0] =~ /\/dev\/fd([0-4])$/ ? "(fd$1)" : undef;
}

# bios_to_linux(device)
# Converts a GRUB bios disk like (hd0) to a Linux device file like /dev/hda
sub bios_to_linux
{
if ($_[0] =~ /^\(([a-z]+\d+),(\d+)\)$/) {
	# A partition on a BIOS disk .. get the disk device, and add the part
	local ($dev, $part) = ($1, $2+1);
	local $dsk = &bios_to_linux("($dev)");
	if ($dsk =~ /^(\/dev\/[hs]d[a-z])$/) {
		return $dsk.$part;
		}
	elsif ($dsk =~ /^(\/dev\S+\/)disc$/) {
		return $1."part".$part;
		}
	elsif ($dsk =~ /^(\/dev\S+c\d+d\d+)$/) {
		return $dsk.$part;
		}
	else {
		return undef;
		}
	}
local @map = &get_device_map();
if (@map) {
	foreach $m (@map) {
		if ($m->[0] eq $_[0]) {
			return $m->[1];
			}
		}
	}

# Have to guess from BIOS name :(
return $_[0] =~ /^\(hd(\d+)\)$/ ? "/dev/hd".chr($1+97) :
       $_[0] =~ /^\(fd([0-4])\)$/ ? "/dev/fd$1" : undef;
}

# get_device_map()
# Returns the device.map file contents, or an empty list if there is none
sub get_device_map
{
local ($dm, $temp, @rv);
if (!$config{'device_map'} || !-r $config{'device_map'}) {
	# Run GRUB to build the map now
	$dm = $temp = &transname();
	open(GRUB, "|$config{'grub_path'} --batch --device-map=$temp >/dev/null 2>&1");
	print GRUB "quit\n";
	close(GRUB);
	}
else {
	# Just use the existing file
	$dm = $config{'device_map'};
	}
open(MAP, $dm);
while(<MAP>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^(\S+)\s+(\S+)/) {
		push(@rv, [ $1, $2 ]);
		}
	}
close(MAP);
unlink($temp) if ($temp);
return @rv;
}

