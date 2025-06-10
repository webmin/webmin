# format-lib.pl
# Common functions for partitioning and formatting disks under solaris

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("mount", "mount-lib.pl");
&foreign_require("proc", "proc-lib.pl");

%access = &get_module_acl();
$| = 1;

# list_disks()
# Returns a list of structures, one per disk
sub list_disks
{
local(@rv);
local $temp = &transname();
open(TEMP, ">$temp");
print TEMP "disk\n";
close(TEMP);
open(FORMAT, "format -f $temp |");
while(1) {
	local $rv = &wait_for(FORMAT, 'Specify', '\s+\d+\. (\S+) <(.*) cyl (\d+) alt (\d+) hd (\d+) sec (\d+)>\s*(\S*)', '\s+\d+\. (\S+) <drive type unknown>', 'space for more');
	if ($rv <= 0) { last; }
	elsif ($rv == 1) {
		local $disk = { 'device' => "/dev/dsk/$matches[1]",
			    	'type' => $matches[2] eq 'DEFAULT' ?
					  undef : $matches[2],
			    	'cyl' => $matches[3],
			    	'alt' => $matches[4],
			    	'hd' => $matches[5],
			    	'sec' => $matches[6],
			    	'volume' => $matches[7] };
		if ($matches[1] =~ /c(\d+)t(\d+)d(\d+)$/) {
			$disk->{'desc'} = &text('select_device',
						"$1", "$2", "$3");
			}
		elsif ($matches[1] =~ /c(\d+)d(\d+)$/) {
			$disk->{'desc'} = &text('select_idedevice',
					    	chr($1*2 + $2 + 65));
			}
		push(@rv, $disk);
		}
	}
close(FORMAT);
unlink($temp);
return @rv;
}

# disk_info(disk)
# Returns an array containing a disks vendor, product and revision
sub disk_info
{
local(@rv);
&open_format();
&choose_disk($_[0]);
&fast_wait_for($fh, 'format>');
&wprint("inquiry\n");
&wait_for($fh, 'Vendor:\s+(.*)\r\nProduct:\s+(.*)\r\nRevision:\s+(.*)\r\n');
@rv = ($matches[1],$matches[2],$matches[3]);
&wait_for($fh, 'format>');
return @rv;
}

# list_partitions(device)
# Returns a list of structures, one per partition
sub list_partitions
{
local(@rv, $secs, $i);
local @tag = &list_tags();
open(VTOC, "prtvtoc $_[0]s0 |");
while(<VTOC>) {
	if (/(\d+)\s+sectors\/cylinder/) {
		$secs = $1;
		}
	if (/^\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
		local $n = $1;
		local $part = { 'tag' => $tag[$2],
				'flag' => $3 eq "00" ? "wm" :
					  $3 eq "01" ? "wu" :
					  $3 eq "10" ? "rm" : "ru",
				'start' => int($4 / $secs),
				'end' => int($6 / $secs),
				'device' => $_[0]."s$n" };
		$rv[$n] = $part;
		}
	}
close(VTOC);
for($i=0; $i<8 || $i<@rv; $i++) {
	$rv[$i] = { 'tag' => 'unassigned',
		    'flag' => 'wm',
		    'device' => $_[0]."s$i" } if (!$rv[$i]);
	if ($_[0] =~ /c(\d+)t(\d+)d(\d+)$/) {
		$rv[$i]->{'desc'} = &text('select_part',
					  "$1", "$2", "$3", $i);
		}
	elsif ($_[0] =~ /c(\d+)d(\d+)$/) {
		$rv[$i]->{'desc'} = &text('select_idepart',
				    	  chr($1*2 + $2 + 65), $i);
		}
	}
return @rv;

#&open_format();
#&choose_disk($_[0]);
#if (!&wait_for($fh, 'unformatted', 'formatted')) { return (); }
#&wait_for($fh, 'format>');
#&wprint("partition\n");
#&wait_for($fh, 'partition>');
#&wprint("print\n");
#&wait_for($fh, 'Blocks\r\n');
#while(&wait_for($fh, 'partition>', '\s+\d+\s+(\S+)\s+(\S+)\s+(\d+)(\s+-\s+(\d+))?.*\r\n')) {
#	local $part = { 'tag' => $matches[1],
#			'flag' => $matches[2],
#			'start' => $matches[3],
#			'end' => $matches[5] ? $matches[5] : $matches[3] };
#	if ($matches[1] =~ /c(\d+)t(\d+)d(\d+)s(\d+)$/) {
#		$part->{'desc'} = &text('select_part', "$1", "$2", "$3", "$4");
#		}
#	push(@rv, $part);
#	}
#&wprint("quit\n");
#&wait_for($fh, 'format>');
#return @rv[0..7];
}

# modify_partition(disk, partition, tag, flag, start, end)
# Changes an existing partition
sub modify_partition
{
local(@rv);
&open_format();
&choose_disk($_[0]);
&wait_for($fh, 'format>');
&wprint("partition\n");
local $fd = &wait_for($fh, 'partition>', 'run fdisk');
if ($fd == 1) {
	# Run fdisk first
	&wprint("fdisk\n");
	&wprint("y\n");
	&wait_for($fh, 'partition>');
	}
&wprint("$_[1]\n");
&wait_for($fh, 'Enter.*:'); &wprint("$_[2]\n");
&wait_for($fh, 'Enter.*:'); &wprint("$_[3]\n");
&wait_for($fh, 'Enter.*:'); &wprint("$_[4]\n");
&wait_for($fh, 'Enter.*:');
if ($_[4] || $_[5]) { &wprint(($_[5]-$_[4]+1)."c\n"); }
else {
	# deleting this partition..
	&wprint("0\n");
	}
&wait_for($fh, 'partition>');
&wprint("label\n");
if (&wait_for($fh, 'continue', 'Cannot')) {
	&error($text{'emounted'});
	}
&wprint("y\n");
if (&wait_for($fh, 'partition>', 'no backup labels')) {
	&error($text{'elast'});
	}
&wprint("quit\n");
&wait_for($fh, 'format>');
}

# list_tags()
# Returns a list of all known tags
sub list_tags
{
return ("unassigned", "boot", "root", "swap",
	"usr", "backup", "stand", "var", "home", "alternates", "cache");

}

# device_status(device)
# Returns the mount point, type and status of some device. Uses the mount module
# to query the list of known and mounted filesystems
sub device_status
{
@mounted = &foreign_call("mount", "list_mounted") if (!@mounted);
@mounts = &foreign_call("mount", "list_mounts") if (!@mounts);
local ($mounted) = grep { $_->[1] eq $_[0] } @mounted;
local ($mount) = grep { $_->[1] eq $_[0] } @mounts;
if ($mounted) { return ($mounted->[0], $mounted->[2], 1,
			&indexof($mount, @mounts),
			&indexof($mounted, @mounted)); }
elsif ($mount) { return ($mount->[0], $mount->[2], 0,
			 &indexof($mount, @mounts)); }
else {
	&metamap_init();
	if ($metastat{$_[0]}) { return ("meta", "meta", 1); }
	if ($metadb{$_[0]}) { return ("meta", "metadb", 1); }
	return ();
	}
}


# fstype_name(type)
# Returns a human-readable filesystem name
sub fstype_name
{
return $text{"fstype_$_[0]"} ? $text{"fstype_$_[0]"}
			     : $text{'fstype_unknown'};
}

# filesystem_type(device)
# Calls fstyp to get the filesystem on some device
sub filesystem_type
{
local($out);
chop($out = `fstyp $_[0] 2>&1`);
if ($out =~ /^\S+$/) { return $out; }
return undef;
}

# fsck_error(code)
# Translate an error code from fsck
sub fsck_error
{
return $text{"fsck_$_[0]"} ? $text{"fsck_$_[0]"} : $text{'fsck_unknown'};
}


#############################################################################
# Internal functions
#############################################################################
# open_format()
# Internal function to run the 'format' command
sub open_format
{
return if ($format_already_open);
($fh, $fpid) = &foreign_call("proc", "pty_process_exec", "format");
while(1) {
	local $rv = &wait_for($fh, 'Specify.*:', 'no disks found', 'space for more');
	if ($rv == 0) { last; }
	elsif ($rv == 1) { &error($text{'eformat'}); }
	else { &wprint(" "); }
	}
&wprint("0\n");
&wait_for($fh, 'format>');
$format_already_open++;
}

sub wprint
{
syswrite($fh, $_[0], length($_[0]));
}

sub opt_input
{
print $_[2] ? "<tr>" : "";
print "<td align=right><b>$text{$_[0]}</b></td> <td nowrap>\n";
print "<input type=radio name=$_[0]_def value=1 checked> $text{'default'}\n";
print "&nbsp; <input type=radio name=$_[0]_def value=0>\n";
print "<input name=$_[0] size=6> $_[1]</td>";
print $_[2] ? "\n" : "</tr>\n";
}

sub opt_check
{
if ($in{"$_[0]_def"}) { return ""; }
elsif ($in{$_[0]} !~ /^$_[1]$/) {
	&error(&text('opt_error', $in{$_[0]}, $text{$_[0]}));
	}
else { return " $_[2] $in{$_[0]}"; }
}

# metamap_init()
# internal function to build %metastat and %metadb arrays
sub metamap_init
{
if ($done_metamap_init) { return; }
$done_metamap_init = 1;
if (-x $config{metastat_path} && -x $config{metadb_path}) {
	open(METASTAT, "$config{metastat_path} 2>&1 |");
	while(<METASTAT>) {
		if (/(c\d+t\d+d\d+s\d+)/) { $metastat{"/dev/dsk/$1"}++; }
		}
	close(METASTAT);
	open(METADB, "$config{metadb_path} -i 2>&1 |");
	while(<METADB>) {
		if (/(c\d+t\d+d\d+s\d+)/) { $metadb{"/dev/dsk/$1"}++; }
		}
	close(METADB);
	}
}

sub choose_disk
{
&wprint("disk\n");
while(&wait_for($fh, 'Specify.*:', 'space for more')) {
	&wprint(" ");
	}
&wprint("$_[0]\n");
}

# can_edit_disk(device)
sub can_edit_disk
{
$_[0] =~ /(c\d+t\d+d\d+)/;
foreach (split(/\s+/, $access{'disks'})) {
	return 1 if ($_ eq "*" || $_ eq $1);
	}
return 0;
}

# partition_select(name, value, mode, &found)
# Returns HTML for selecting a disk or partition
# mode 0 = disk partitions
#      1 = disks
#      2 = disks and disk partitions
sub partition_select
{
local $rv = "<select name=$_[0]>\n";
local ($found, $d, $p);
local @dlist = &list_disks();
foreach $d (@dlist) {
	if ($_[0] > 2) {
		local $name = $d->{'desc'};
		$name .= " ($d->{'type'})" if ($d->{'type'});
		$rv .= sprintf "<option value=%s %s>%s</option>\n",
			$d->{'device'},
			$_[1] eq $d->{'device'} ? "selected" : "", $name;
		$found++ if ($_[1] eq $d->{'device'});
		}
	if ($_[0] != 1) {
		local @parts = &list_partitions($d->{'device'});
		foreach $p (@parts) {
			local $name = $p->{'desc'};
			next if (!$p->{'end'});
			$name .= " ($p->{'tag'})" if ($p->{'tag'});
			$rv .= sprintf "<option %s value=%s>%s</option>\n",
				$_[1] eq $p->{'device'} ? "selected" : "",
				$p->{'device'}, $name;
			$found++ if ($_[1] eq $p->{'device'});
			}
		}
	}
if (!$found && $_[1] && !$_[3]) {
	$rv .= "<option selected>$_[1]</option>\n";
	}
if ($_[3]) {
	${$_[3]} = $found;
	}
$rv .= "</select>\n";
return $rv;
}

# disk_space(device)
# Returns the amount of total and free space for some filesystem, or an
# empty array if not appropriate.
sub disk_space
{
local $out = `df -k $_[0] 2>&1`;
$out =~ /(\/dev\/\S+)\s+(\d+)\s+\S+\s+(\d+)/ || return ();
return ($2, $3);
}

