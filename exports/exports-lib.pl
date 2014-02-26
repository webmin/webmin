# export-lib.pl
# Common functions for the linux exports file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
&foreign_require("mount", "mount-lib.pl");

# list_exports()
# Returns a list of all exports
sub list_exports
{
local (@rv, $pos, $lnum, $h, $o, $line);
return @list_exports_cache if (@list_exports_cache);
open(EXP, $config{'exports_file'});
$lnum = 0;
while($line = <EXP>) {
	local $slnum = $lnum;
	$line =~ s/\s+$//g;
	while($line =~ /\\$/) {
		# continuation character!
		$line =~ s/\\$//;
		$line .= <EXP>;
		$line =~ s/\s+$//g;
		$lnum++;
		}
	if ($line =~ /^(#*)\s*(\/\S*)\s+(.*)$/) {
		local $active = !$1;
		local $dir = $2;
		local $rest = $3;
                if ($dir =~ /^$config{'exports_file'}/) {
			$lnum++;
			next;
               		}
		$pos = 0;
		while($rest =~ /^([^\s+\(\)]*)\(([^\)]*)\)\s*(.*)$/ ||
		      $rest =~ /^([^\s+\(\)]+)\s*()(.*)$/) {
			local %exp;
			$exp{'active'} = $active;
			$exp{'dir'} = $dir;
			$exp{'host'} = $1;
			local $ostr = $2;
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
local @exps = &list_exports();
local @same = grep { $_ ne $_[0] && $_->{'line'} eq $_[0]->{'line'} } @exps;
local $lref = &read_file_lines($config{'exports_file'});
if (@same) {
	# other exports on the same line.. cannot totally delete
	splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'}-$_[0]->{'line'}+1,
	       &make_exports_line(@same));
	map { $_->{'line'} = $_->{'eline'} = $_[0]->{'line'} } @same;
	}
else {
	# remove export line
	splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'}-$_[0]->{'line'}+1);
	# unmount the directory if it is mounted with --bind
	local $dir = $_[0]->{'dir'};
	local @mounted = &mount::list_mounted();
	for(my $i=0; $i<@mounted; $i++) {
	    my $p = $mounted[$i];
	    if (($p->[0] eq $dir) and ($p->[2] eq "bind")) {
		&mount::unmount_dir($p->[1], $p->[0], $p->[2]);
	    }
	}
	# remove it from the fstab file
	local @mounts = &mount::list_mounts();
	for(my $i=0; $i<@mounts; $i++) {
	    my $p = $mounts[$i];
	    if (($p->[0] eq $dir) and ($p->[2] eq "bind")) {
		&mount::delete_mount($i);
	    }
	}
    }
@list_exports_cache = grep { $_ ne $_[0] } @list_exports_cache;
&flush_file_lines();
}

# create_export_via_pfs(&export)
sub create_export_via_pfs
{
    use File::Basename;
    use File::Path;
    local $export_pfs = 1;
    local $pfs = $_[0]->{'pfs'};
    $pfs  =~ s/\/$//;
    # Check if the pfs is already exported
    open(EXP, "< $config{'exports_file'}");
    while (my $line = <EXP>) {
	if ($line =~ /^$pfs[\s|\t]/) {
	    if ($line !~ /fsid=0/) {
		&error($text{'save_pfs'}, $pfs);
	    }
	    $export_pfs = 0;
	}
    }
    close(EXP);
    
    # Mount the directory in the pfs
    local $add_line = 1;
    local $to_be_mounted = 1;
    local $dir = $_[0]->{'dir'};
    local $expt_dir = $dir;
    $expt_dir =~ s/\/$//;
    $expt_dir = $pfs."/".basename($expt_dir);
    
    # Add it in the fstab file if it is not already in
    local @mounts = &mount::list_mounts();
    for(my $i=0; $i<@mounts; $i++) {
	my $p = $mounts[$i];
	if (($p->[0] eq $expt_dir) and ($p->[1] eq $dir) and ($p->[2] eq "bind")) {
	    $add_line = 0;
	}
    }
    if ($add_line) {
	&mount::create_mount($expt_dir, $dir, "bind", "");
    }

    # Mount it if it is not already mounted
    local @mounted = &mount::list_mounted();
    for(my $i=0; $i<@mounted; $i++) {
	my $p = $mounted[$i];
	if (($p->[0] eq $expt_dir) and ($p->[1] eq $dir) and ($p->[2] eq "bind")) {
	    $to_be_mounted = 0;
	}
    }
    if ($to_be_mounted) {
	eval { mkpath($expt_dir) };
	if ($@) {
	    &error($text{'save_create_dir'}, $expt_dir );
	}
	my $err = &mount::mount_dir($expt_dir, $dir, "bind", "");
	&error($err) if ($err);
	&webmin_log("mount", undef, undef, { 'dev' => $expt_dir,
					     'type' => "bind",
					     'dir' => $dir });
    }
    
    # Export the directory $expt_dir
    $_[0]->{'dir'} = $expt_dir;
    create_export($_[0]);

    if ($export_pfs) {
	# Export the pfs with the "fsid=0" option
	$_[0]->{'dir'} = $pfs;
	$_[0]->{'options'}->{'fsid'} = "0";
	create_export($_[0]);
    }
}

# create_export(&export)
sub create_export
{
&open_tempfile(EXP, ">>$config{'exports_file'}");
&print_tempfile(EXP, &make_exports_line($_[0]),"\n");
&close_tempfile(EXP);
}

# modify_export(&export, &old)
sub modify_export
{
local @exps = &list_exports();
local @same = grep { $_->{'line'} eq $_[1]->{'line'} } @exps;
local $lref = &read_file_lines($config{'exports_file'});
if ($_[0]->{'dir'} eq $_[1]->{'dir'} &&
    $_[0]->{'active'} == $_[1]->{'active'} || @same == 1) {
	# directory or active not changed, or on a line of it's own
	splice(@same, &indexof($_[1],@same), 1, $_[0]);
	splice(@$lref, $_[1]->{'line'}, $_[1]->{'eline'}-$_[1]->{'line'}+1,
	       &make_exports_line(@same));
	}
else {
	# move to a line of it's own
	splice(@same, &indexof($_[1],@same), 1);
	splice(@$lref, $_[1]->{'line'}, $_[1]->{'eline'}-$_[1]->{'line'}+1,
	       &make_exports_line(@same));
	push(@$lref, &make_exports_line($_[0]));
	}
&flush_file_lines();
}

# make_exports_line([&export]+)
sub make_exports_line
{
local ($e, @htxt);
foreach $e (@_) {
	local %opts = %{$e->{'options'}};
	if (%opts || !$e->{'host'}) {
		push(@htxt, $e->{'host'}."(".
			    join(",", map { $opts{$_} eq "" ? $_
							    : "$_=$opts{$_}" }
			    (keys %opts)).")");
		}
	else { push(@htxt, $e->{'host'}); }
	}
return ($_[0]->{'active'} ? "" : "#").$_[0]->{'dir'}."\t".join(" ", @htxt);
}

# file_chooser_button2(input, type, name, disabled)
# A file_chooser_button which can be disabled
sub file_chooser_button2
{
    local $disabled = ($_[3] == 1) ? "disabled" : "";
    return "<input type=button name=$_[2] onClick='ifield = document.forms[0].$_[0]; chooser = window.open(\"$gconfig{'webprefix'}/chooser.cgi?type=$_[1]&chroot=/&file=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbar=no,width=400,height=300\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\" $disabled>\n";
}

# nfs_max_version(host)
# Return the max NFS version allowed on a server
sub nfs_max_version
{
local($_, $max, $out);
$max = 0;
$out = &backquote_command("rpcinfo -p $_[0] 2>&1");
if ($?) {
	# NFS server is down, take a guess based on kernel
	my $out = &backquote_command("uname -r");
	if ($out =~ /^(\d+)\./ && $1 >= 3 ||
	    $out =~ /^(\d+)\.(\d+)\./ && $1 == 2 && $2 >= 6) {
		return 4;
		}
	return 3;
	}
foreach (split(/\n/, $out)) {
	if ((/ +(\d) +.*nfs/) && ($1 > $max)) {
		$max = $1;
		}
	}
return $max;
}

# describe_host(host)
# Given a host, regexp or netgroup return a human-readable version
sub describe_host
{
local $h = &html_escape($_[0]);
if ($h eq "=public") { return $text{'exports_webnfs'}; }
elsif ($h =~ /^gss\//) { return &text('exports_gss', "<i>$h</i>"); }
elsif ($h =~ /^\@(.*)/) { return &text('exports_ngroup', "<i>$1</i>"); }
elsif ($h =~ /^(\S+)\/(\S+)$/) {
	return &text('exports_net', "<i>$1/$2</i>"); }
elsif ($h eq "" || $h eq "*") { return $text{'exports_all'}; }
elsif ($h =~ /\*/) { return &text('exports_hosts', "<i>$h</i>"); }
else { return &text('exports_host', "<i>$h</i>"); }
}

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
	local $out = &backquote_logged("$config{'apply_cmd'} 2>&1 </dev/null");
	if (!$? && $out !~ /invalid|error|failed/i) {
		# Looks like it worked!
		return undef;
		}
	}

&system_logged("$config{'portmap_command'} >/dev/null 2>&1 </dev/null")
        if ($config{'portmap_command'});
local $temp = &transname();
local $rv = &system_logged("($config{'restart_command'}) </dev/null >$temp 2>&1");
local $out = `cat $temp`;
unlink($temp);
if ($rv) {
        # something went wrong.. return an error
        return "<pre>$out</pre>";
        }
return undef;
}

1;

