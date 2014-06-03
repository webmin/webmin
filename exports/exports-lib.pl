# export-lib.pl
# Common functions for the linux exports file

use strict;
use warnings;
BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
our %access = &get_module_acl();
our ($module_root_directory, %text, %config, %gconfig);
our @list_exports_cache;
&foreign_require("mount", "mount-lib.pl");

# list_exports()
# Returns a list of all exports
sub list_exports
{
my (@rv, $pos, $h, $o, $line);
return @list_exports_cache if (@list_exports_cache);
open(EXP, $config{'exports_file'});
my $lnum = 0;
while(my $line = <EXP>) {
	my $slnum = $lnum;
	$line =~ s/\s+$//g;
	while($line =~ /\\$/) {
		# continuation character!
		$line =~ s/\\$//;
		$line .= <EXP>;
		$line =~ s/\s+$//g;
		$lnum++;
		}
	if ($line =~ /^(#*)\s*(\/\S*)\s+(.*)$/) {
		my $active = !$1;
		my $dir = $2;
		my $rest = $3;
                if ($dir =~ /^$config{'exports_file'}/) {
			$lnum++;
			next;
               		}
		$pos = 0;
		while($rest =~ /^([^\s+\(\)]*)\(([^\)]*)\)\s*(.*)$/ ||
		      $rest =~ /^([^\s+\(\)]+)\s*()(.*)$/) {
			my %exp;
			$exp{'active'} = $active;
			$exp{'dir'} = $dir;
			$exp{'host'} = $1;
			my $ostr = $2;
			$rest = $3;
			while($ostr =~ /^([a-z_]+)=([0-9,\-]+)\s*,\s*(.*)$/ ||
			      $ostr =~ /^([a-z_]+)=([0-9,\-]+)(.*)$/ ||
			      $ostr =~ /^([a-z_]+)=([^,\s]+),(.*)$/ ||
			      $ostr =~ /^([a-z_]+)=([^,\s]+)(.*)$/ ||
			      $ostr =~ /^([a-z_]+)()\s*,\s*(.*)$/ ||
			      $ostr =~ /^([a-z_]+)()(.*)$/) {
				if ($2 ne "") { $exp{'options'}->{$1} = $2; }
				else { $exp{'options'}->{$1} = ""; }
				$ostr = $3;
				}
			$exp{'line'} = $slnum;
			$exp{'eline'} = $lnum;
			$exp{'pos'} = $pos++;
			$exp{'index'} = scalar(@rv);
			push(@rv, \%exp);
			}
		}
	$lnum++;
	}
close(EXP);
@list_exports_cache = @rv;
return @list_exports_cache;
}

# delete_export(&export)
# Delete an existing export
sub delete_export
{
my ($export) = @_;
my @exps = &list_exports();
my @same = grep { $_ ne $export && $_->{'line'} eq $_[0]->{'line'} } @exps;
my $lref = &read_file_lines($config{'exports_file'});
if (@same) {
	# other exports on the same line.. cannot totally delete
	splice(@$lref, $export->{'line'}, $export->{'eline'}-$export->{'line'}+1,
	       &make_exports_line(@same));
	map { $_->{'line'} = $_->{'eline'} = $export->{'line'} } @same;
	}
else {
	# remove export line
	splice(@$lref, $export->{'line'}, $export->{'eline'}-$export->{'line'}+1);
	# unmount the directory if it is mounted with --bind
	my $dir = $_[0]->{'dir'};
	my @mounted = &mount::list_mounted();
	for(my $i=0; $i<@mounted; $i++) {
	    my $p = $mounted[$i];
	    if (($p->[0] eq $dir) and ($p->[2] eq "bind")) {
		&mount::unmount_dir($p->[1], $p->[0], $p->[2]);
	    }
	}
	# remove it from the fstab file
	my @mounts = &mount::list_mounts();
	for(my $i=0; $i<@mounts; $i++) {
	    my $p = $mounts[$i];
	    if (($p->[0] eq $dir) and ($p->[2] eq "bind")) {
		&mount::delete_mount($i);
	    }
	}
    }
@list_exports_cache = grep { $_ ne $export } @list_exports_cache;
&flush_file_lines();
}

# create_export_via_pfs(&export)
sub create_export_via_pfs
{
my ($export) = @_;

use File::Basename;
use File::Path;
my $export_pfs = 1;
my $pfs = $export->{'pfs'};
$pfs  =~ s/\/$//;

# Check if the pfs is already exported
my $lref = &read_file_lines($config{'exports_file'}, 1);
foreach my $line (@$lref) {
	if ($line =~ /^$pfs[\s|\t]/) {
		if ($line !~ /fsid=0/) {
			&error(&text('save_pfs', $pfs));
			}
		$export_pfs = 0;
		}
	}
    
# Mount the directory in the pfs
my $add_line = 1;
my $to_be_mounted = 1;
my $dir = $export->{'dir'};
my $expt_dir = $dir;
$expt_dir =~ s/\/$//;
$expt_dir = $pfs."/".basename($expt_dir);
    
# Add it in the fstab file if it is not already in
my @mounts = &mount::list_mounts();
for(my $i=0; $i<@mounts; $i++) {
	my $p = $mounts[$i];
	if ($p->[0] eq $expt_dir && $p->[1] eq $dir && $p->[2] eq "bind") {
		$add_line = 0;
		}
	}
if ($add_line) {
	&mount::create_mount($expt_dir, $dir, "bind", "");
	}

# Mount it if it is not already mounted
my @mounted = &mount::list_mounted();
for(my $i=0; $i<@mounted; $i++) {
	my $p = $mounted[$i];
	if ($p->[0] eq $expt_dir && $p->[1] eq $dir && $p->[2] eq "bind") {
		$to_be_mounted = 0;
		}
	}
if ($to_be_mounted) {
	eval { mkpath($expt_dir) };
	if ($@) {
		&error(&text('save_create_dir', $expt_dir));
		}
	my $err = &mount::mount_dir($expt_dir, $dir, "bind", "");
	&error($err) if ($err);
	}
    
# Export the directory $expt_dir
$export->{'dir'} = $expt_dir;
&create_export($export);

if ($export_pfs) {
	# Export the pfs with the "fsid=0" option
	$export->{'dir'} = $pfs;
	$export->{'options'}->{'fsid'} = "0";
	&create_export($export);
	}
}

# create_export(&export)
# Add one new export to the config file
sub create_export
{
my ($export) = @_;
my $fh = "EXP";
&open_tempfile($fh, ">>$config{'exports_file'}");
&print_tempfile($fh, &make_exports_line($export),"\n");
&close_tempfile($fh);
}

# modify_export(&export, &old)
# Update one export in the config file
sub modify_export
{
my ($export, $old) = @_;
my @exps = &list_exports();
my @same = grep { $_->{'line'} eq $old->{'line'} } @exps;
my $lref = &read_file_lines($config{'exports_file'});
if ($export->{'dir'} eq $old->{'dir'} &&
    $export->{'active'} == $old->{'active'} || @same == 1) {
	# directory or active not changed, or on a line of it's own
	splice(@same, &indexof($old, @same), 1, $export);
	splice(@$lref, $old->{'line'}, $old->{'eline'} - $old->{'line'} + 1,
	       &make_exports_line(@same));
	}
else {
	# move to a line of it's own
	splice(@same, &indexof($old, @same), 1);
	splice(@$lref, $old->{'line'}, $old->{'eline'} - $old->{'line'} + 1,
	       &make_exports_line(@same));
	push(@$lref, &make_exports_line($export));
	}
&flush_file_lines();
}

# make_exports_line([&export]+)
# Returns the text lines for one or more exports
sub make_exports_line
{
my @htxt;
foreach my $e (@_) {
	my %opts = $e->{'options'} ? %{$e->{'options'}} : ( );
	if (%opts || !$e->{'host'}) {
		push(@htxt, $e->{'host'}."(".
			    join(",", map { $opts{$_} eq "" ? $_
							    : "$_=$opts{$_}" }
			    (keys %opts)).")");
		}
	else {
		push(@htxt, $e->{'host'});
		}
	}
return ($_[0]->{'active'} ? "" : "#").$_[0]->{'dir'}."\t".join(" ", @htxt);
}

# nfs_max_version(host)
# Return the max NFS version allowed on a server
sub nfs_max_version
{
my ($host) = @_;
my $max = 0;
my $out = &backquote_command("rpcinfo -p ".quotemeta($host)." 2>&1");
if ($?) {
	# NFS server is down, take a guess based on kernel
	my $out = &backquote_command("uname -r");
	if ($out =~ /^(\d+)\./ && $1 >= 3 ||
	    $out =~ /^(\d+)\.(\d+)\./ && $1 == 2 && $2 > 6) {
		return 4;
		}
	return 3;
	}
foreach my $line (split(/\n/, $out)) {
	if ($line =~ / +(\d) +.*nfs/ && $1 > $max) {
		$max = $1;
		}
	}
return $max;
}

# describe_host(host)
# Given a host, regexp or netgroup return a human-readable version
sub describe_host
{
my ($h) = @_;
if ($h eq "=public") {
	return $text{'exports_webnfs'};
	}
elsif ($h =~ /^gss\//) {
	return &text('exports_gss', "<i>".&html_escape($h)."</i>");
	}
elsif ($h =~ /^\@(.*)/) {
	return &text('exports_ngroup', "<i>".&html_escape("$1")."</i>");
	}
elsif ($h =~ /^(\S+)\/(\S+)$/) {
	return &text('exports_net', "<i>".&html_escape("$1/$2")."</i>");
	}
elsif ($h eq "" || $h eq "*") {
	return $text{'exports_all'};
	}
elsif ($h =~ /\*/) {
	return &text('exports_hosts', "<i>".&html_escape($h)."</i>");
	}
else {
	return &text('exports_host', "<i>".&html_escape($h)."</i>");
	}
}

# has_nfs_commands()
# Returns 1 if all NFS server commands are installed
sub has_nfs_commands
{
return !&has_command("rpc.nfsd") && !&has_command("nfsd") &&
       !&has_command("rpc.knfsd") ? 0 : 1;
}

# restart_mountd()
# Apply the /etc/exports configuration
sub restart_mountd
{
# Try exportfs -r first
if ($config{'apply_cmd'} && &find_byname("nfsd") && &find_byname("mountd")) {
	my $out = &backquote_logged("$config{'apply_cmd'} 2>&1 </dev/null");
	if (!$? && $out !~ /invalid|error|failed/i) {
		# Looks like it worked!
		return undef;
		}
	}

&system_logged("$config{'portmap_command'} >/dev/null 2>&1 </dev/null")
        if ($config{'portmap_command'});
my $temp = &transname();
my $rv = &system_logged("($config{'restart_command'}) </dev/null >$temp 2>&1");
my $out = &read_file_contents($temp);
unlink($temp);
if ($rv) {
        # something went wrong.. return an error
        return "<pre>".&html_escape($out)."</pre>";
        }
return undef;
}

1;

