# Functions for viewing and managing zones
# XXX proper pool selection field

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("net", "net-lib.pl");
&foreign_require("mount", "mount-lib.pl");

%thing_key_map = ( "net" => "address",
		   "fs" => "dir",
		   "inherit-pkg-dir" => "dir",
		   "capped-cpu" => "ncpus",
		   "capped-memory" => "physical",
		   "rctl" => "name",
		   "attr" => "name",
		   "device" => "match" );

# list_zones([global-too])
# Returns a list of all zones and their statuses (except global)
sub list_zones
{
local @rv;
open(OUT, "zoneadm list -p -i -c |");
while(<OUT>) {
	s/\r|\n//g;
	s/\s+$//;
        local @fields = split(/:/, $_);
        next if ($fields[1] eq "global" && !$_[0]);
        push(@rv, { 'id' => $fields[0],
                    'name' => $fields[1],
                    'status' => $fields[2],
                    'zonepath' => $fields[3] });
	}
close(OUT);
return @rv;
}

# get_current_zone()
# Returns the current zone name
sub get_current_zone
{
local $zn = `zonename`;
chop($zn);
return $zn;
}

# get_zone(name)
# Returns a structure containing details of one zone
sub get_zone
{
local ($zone) = @_;
local $zinfo = { 'name' => $zone };
local ($status) = grep { $_->{'name'} eq $zone } &list_zones();
return undef if (!$status);
$zinfo->{'status'} = $status->{'status'};
$zinfo->{'id'} = $status->{'id'};

# Add zone-level variables. Failure is possible in some cases (like brand)
# if not supported on this Solaris version.
local ($p, $r);
foreach $p ("zonepath", "autoboot", "pool", "brand") {
	eval {
		$main::error_must_die = 1;
		local @lines = &get_zonecfg_output($zone, "info $p");
		if ($lines[0] =~ /^$p:\s*(.*)/) {
			$zinfo->{$p} = $1;
			}
		};
	}

# Add lists of things
foreach $r ("fs", "inherit-pkg-dir", "net", "device", "rctl", "attr",
	    "capped-cpu", "capped-memory") {
	local @lines;
	eval {
		$main::error_must_die = 1;
		@lines = &get_zonecfg_output($zone, "info $r");
		};
	local ($l, $thing);
	foreach $l (@lines) {
		if ($l =~ /^$r:/) {
			# Start of a new thing
			$thing = { 'keytype' => $r,
				   'keyfield' => $thing_key_map{$r},
				   'keyzone' => $zone };
			push(@{$zinfo->{$r}}, $thing);
			}
                elsif ($l =~ /^\s+\[([^:]+):\s*"(.*)"\]/ ||
                       $l =~ /^\s+\[([^:]+):\s*(.*)\]/ ||
                       $l =~ /^\s+([^:]+):\s*\[(.*)\]/ ||
                       $l =~ /^\s+([^:]+):\s*"(.*)"/ ||
                       $l =~ /^\s+([^:]+):\s*(.*)/) {
			# An attribute of a thing
			if (defined($thing->{$1})) {
				# Multiple values!
				$thing->{$1} .= "\0".$2;
				}
			else {
				# Just one
				$thing->{$1} = $2;
				}
			if ($1 eq $thing->{'keyfield'}) {
				$thing->{'key'} = $2;
				}
			}
		}
	if ($r eq "rctl") {
		# Save old values for later calls to modify_zone_object
		$thing->{'keyoldvalue'} = $thing->{'value'};
		}
	}
return $zinfo;
}

# set_zone_variable(&zinfo, name, value)
# Updates zone variable like autoboot in the zone
sub set_zone_variable
{
local ($zone, $name, $value) = @_;
&get_zonecfg_output($zone->{'name'}, "set $name=\"$value\"\ncommit\nexit", 1);
}

# modify_zone_object(&zinfo, &object)
# Modifies some object like a network address or filesystem in a zone
sub modify_zone_object
{
local ($zinfo, $thing) = @_;
local (@keys, @removes, $k, $v);
if ($thing->{'keytype'} eq "rctl") {
	# Need to delete old values
	foreach $v (split(/\0/, $thing->{'keyoldvalue'})) {
		push(@removes, "remove value $v\n");
		}
	}
foreach $k (keys %$thing) {
	if ($k !~ /^key/) {
		foreach $v (split(/\0/, $thing->{$k})) {
			if ($v =~ /^\(.*\)$/) {
				push(@keys, "add $k $v\n");
				}
			else {
				push(@keys, "set $k=\"$v\"\n");
				}
			}
		}
	}
&get_zonecfg_output($zinfo->{'name'},
	"select $thing->{'keytype'} $thing->{'keyfield'}=$thing->{'key'}\n".
	join("", @removes).join("", @keys)."end\n", 1);
}

# create_zone_object(&zinfo, &object)
# Adds some object like a network interface to a zone
sub create_zone_object
{
local ($zinfo, $thing) = @_;
local (@keys, $k, $v);
foreach $k (keys %{$_[1]}) {
	if ($k !~ /^key/) {
		foreach $v (split(/\0/, $_[1]->{$k})) {
			if ($v =~ /^\(.*\)$/) {
				push(@keys, "add $k $v\n");
				}
			else {
				push(@keys, "set $k=\"$v\"\n");
				}
			}
		if ($_[1]->{$k} eq "") {
			push(@keys, "set $k=\"\"\n");
			}
		}
	}
&get_zonecfg_output($zinfo->{'name'},
	"add $thing->{'keytype'}\n".
	join("", @keys)."end\n", 1);
$thing->{'keyzone'} = $zinfo->{'name'};
push(@{$zinfo->{$thing->{'keytype'}}}, $thing);
}

# delete_zone_object(&zinfo, &object)
# Deletes some zone configuration object, like a network interface
sub delete_zone_object
{
local ($zinfo, $thing) = @_;
if ( !$thing->{'keyfield'}) {
	&get_zonecfg_output($zinfo->{'name'}, "remove -F $thing->{'keytype'}", 1);
	}
  else {
	&get_zonecfg_output($zinfo->{'name'}, "remove $thing->{'keytype'} $thing->{'keyfield'}=$thing->{'key'}", 1);
	}
}

# create_zone(name, path)
# Creates a new zone, and returns a zone info object for it
sub create_zone
{
local ($name, $path) = @_;
&get_zonecfg_output($name, "create\nset zonepath=\"$path\"\nset autoboot=true", 1);
return &get_zone($name);
}

# delete_zone(&zinfo)
# Deletes an existing zone
sub delete_zone
{
local ($zinfo) = @_;
&get_zonecfg_output($zinfo->{'name'}, "delete -F", 1);
rmdir($zinfo->{'zonepath'});
}

# get_zonecfg_output(zone, command, log)
# Returns an array of lines output by zonecfg in response to some command. 
# If some error occurs, calls &error instead
sub get_zonecfg_output
{
local ($zone, $cmd, $log) = @_;
local $temp = &transname();
open(TEMP, ">$temp");
print TEMP $cmd,"\n";
close(TEMP);
local @lines;
open(OUT, "zonecfg -z $zone -f $temp 2>&1 |");
while(<OUT>) {
	s/\r|\n//g;
	push(@lines, $_);
	}
close(OUT);
unlink($temp);
if ($?) {
	local $lines = join("", map { "<tt>".&html_escape($_)."</tt><br>" } @lines);
	$lines =~ s/$temp/input/g;
	$cmd = &html_escape($cmd);
	$cmd =~ s/\n/<br>/g;
	&error("<tt>zonecfg</tt> failed :<br>",
	       $lines,
	       "for command :<br>",
	       "<tt>$cmd</tt>");
	}
if ($log) {
	&additional_log("exec", undef, "zonecfg -z $zone", $cmd);
	}
return @lines;
}

# print_zones_list(&zones)
sub print_zones_list
{
local ($zones) = @_;
local @tds = ( "width=30%", "width=10%", "width=20%", "width=20%",
	       "width=20% nowrap" );
print &ui_columns_start([ $text{'list_name'},
			  $text{'list_id'},
			  $text{'list_path'},
			  $text{'list_status'},
			  $text{'list_actions'} ], "100%", 0, \@tds);
local $z;
foreach $z (@$zones) {
	local ($a, @actions);
	foreach $a (&zone_status_actions($z)) {
		push(@actions, &ui_link("save_zone.cgi?zone=$z->{'name'}&$a->[0]=1&list=1","$a->[1]"));
		}
	print &ui_columns_row([
		&ui_link("edit_zone.cgi?zone=$z->{'name'}",$z->{'name'}),
		$z->{'id'},
		$z->{'zonepath'},
		&nice_status($z->{'status'}),
		join(" | ", @actions),
		], \@tds);
	}
print &ui_columns_end();
}

sub nice_status
{
return $text{'status_'.$_[0]} || $_[0];
}

# pool_input(name, value)
# Returns HTML for selecting a pool
sub pool_input
{
local ($name, $value) = @_;
return &ui_opt_textbox($name, $value, 10, $text{'pool_none'});
}

# get_active_interface(&zinfo, &net)
# Returns the active interface object for some zone's network object
sub get_active_interface
{
local ($zinfo, $net) = @_;
if (!scalar(@active_interfaces_cache)) {
	@active_interfaces_cache = &net::active_interfaces();
	}
local $address = $net->{'address'};
$address =~ s/\/.*$//;
local ($iface) = grep { $_->{'zone'} eq $zinfo->{'name'} &&
			$_->{'address'} eq $address &&
			$_->{'name'} eq $net->{'physical'} }
		      @active_interfaces_cache;
return $iface;
}

# get_active_mount(&zinfo, &fs)
# Returns the mount array ref for some zone's filesystem in the global zone
sub get_active_mount
{
local ($zinfo, $fs) = @_;
local $dir = &get_zone_root($zinfo).$fs->{'dir'};
if (!scalar(@active_mounts_cache)) {
	@active_mounts_cache = &mount::list_mounted();
	}
local ($mount) = grep { $_->[0] eq $dir } @active_mounts_cache;
return $mount;
}

# get_zone_root(&zinfo)
# Returns the root directory for actual zone files
sub get_zone_root
{
return $_[0]->{'zonepath'}."/root";
}

sub zone_title
{
return &text('zone_in', "<tt>$_[0]</tt>");
}

# run_zone_command(&zinfo, command, [return-error])
# Executes some command within a zone, calling &error if it fails
sub run_zone_command
{
local ($zinfo, $cmd, $re) = @_;
local $out = &backquote_logged("ctrun -l child zoneadm -z $zinfo->{'name'} $cmd 2>&1");
if ($? && !$re) {
	&error("<tt>zoneadm</tt> failed : <tt>$out</tt>");
	}
return wantarray ? ($out, $?) : $out;
}

# output_zone_command(&zinfo, command, filehandle, escape)
# Executes some command within a zone, sending output to a file handle
sub output_zone_command
{
local ($zinfo, $cmd, $fh, $escape) = @_;
open(OUT, "zoneadm -z $zinfo->{'name'} $cmd 2>&1 |");
while($line = <OUT>) {
	next if ($line =~ /percent complete/);
	$line = &html_escape($line) if ($escape);
	print $line;
	}
close(OUT);
&additional_log("exec", undef, "zoneadm -z $zinfo->{'name'} $cmd");
return $? ? 0 : 1;
}

# callback_zone_command(&zinfo, command, function, &args)
# Executes some command within a zone, sending output to a function
sub callback_zone_command
{
local ($zinfo, $cmd, $func, $args) = @_;
open(OUT, "zoneadm -z $zinfo->{'name'} $cmd 2>&1 |");
local $last_percent;
while(1) {
	local $rmask;
	vec($rmask, fileno(OUT), 1) = 1;
	local $sel = select($rmask, undef, undef, 60);
	next if ($sel < 0);
	if (vec($rmask, fileno(OUT), 1)) {
		# Got something to read
		local $line = <OUT>;
		last if (!$line);
		if ($line =~ /percent complete/) {
			# Only show this every 10 seconds
			local $now = time();
			if ($now - $last_percent > 10) {
				&$func(@$args, $line);
				$last_percent = $now;
				}
			}
		else {
			&$func(@$args, $line);
			}
		}
	else {
		# Nothing to read for 60 seconds
		&$func(@$args, ".\n");
		}
	}
close(OUT);
&additional_log("exec", undef, "zoneadm -z $zinfo->{'name'} $cmd");
return $? ? 0 : 1;
}

# get_address_netmask(&net, &active)
# Returns the address and netmask for the interface
sub get_address_netmask
{
local ($net, $active) = @_;
local ($address, $netmask);
if ($net->{'address'} =~ /^(\S+)\/(\d+)$/) {
	$address = $1;
	$netmask = &net::prefix_to_mask($2);
	}
else {
	$address = $net->{'address'};
	$netmask = $active ? $active->{'netmask'} : undef;
	}
return ($address, $netmask);
}

# physical_input(name, value)
# Returns HTML for selecting a real interface
sub physical_input
{
local ($name, $value) = @_;
return &ui_select($name, $value,
       [ map { [ $_->{'name'} ] } grep { $_->{'virtual'} eq '' }
	     &net::active_interfaces() ], 0, 0, $value ? 1 : 0);
}

# list_filesystems()
# Returns a list of filesystems supported for Zones
sub list_filesystems
{
local @rv;
opendir(FS, "/usr/lib/fs");
foreach (readdir(FS)) {
	if ($_ ne "proc" && $_ ne "mntfs" && $_ ne "autofs" &&
	    $_ ne "cachefs" && $_ ne "nfs" && $_ !~ /^\./) {
		push(@rv, $_);
		}
	}
close(FS);
return @rv;
}

#list_brands()
#returns a list of valid brands
sub list_brands
{
	local @rv;
	opendir(BRND, "/usr/lib/brand");
	foreach (readdir(BRND)) {
		if ($_ !~ /^\./){
			push(@rv, $_);
		}
	}
	close(BRND);
return @rv;
}


# run_in_zone(&zinfo, command)
# Runs some command within a zone, and returns the output
sub run_in_zone
{
local $zinfo = $_[0];
local $qc = quotemeta($_[1]);
local $out = &backquote_logged("zlogin $zinfo->{'name'} $qc 2>&1");
return ($out, $?);
}

# run_in_zone_callback(&zinfo, command, &func, &args)
# Runs some command within a zone, calling back for each line output
sub run_in_zone_callback
{
local $zinfo = $_[0];
local $qc = quotemeta($_[1]);
local $func = $_[2];
local $args = $_[3];
open(OUT, "zlogin $zinfo->{'name'} $qc 2>&1 |");
while($line = <OUT>) {
	&$func(@$args, $line);
	}
close(OUT);
&additional_log("exec", undef, "zlogin $zinfo->{'name'} $qc");
return $?;
}

# list_rctls()
# Returns a list of possible resource control names
sub list_rctls
{
local @rv;
open(RCTL, "rctladm -l |");
while(<RCTL>) {
	if (/^(\S+)\s+(\S+)=(\S+)/) {
		push(@rv, $1);
		}
	}
close(RCTL);
return @rv;
}

# get_rctl_value(value)
# Returns the privilege, limit and action for an resource control
sub get_rctl_value
{
local ($value) = @_;
$value =~ s/^\((.*)\)$/$1/;
local ($s, %rv);
foreach $s (split(/,/, $value)) {
	local ($sn, $sv) = split(/=/, $s);
	$rv{$sn} = $sv;
	}
return ($rv{'priv'}, $rv{'limit'}, $rv{'action'});
}

sub list_attr_types
{
return ( "string", "int", "uint", "boolean" );
}

# find_clash(&zinfo, &thing)
# Returns an existing thing with the same key as the given one
sub find_clash
{
local ($zinfo, $thing) = @_;
local $kf = $thing_key_map{$thing->{'keytype'}};
local ($clash) = grep { $_ ne $thing && $_->{$kf} eq $thing->{$kf} }
		      @{$zinfo->{$thing->{'keytype'}}};
return $clash;
}

# get_default_physical()
# Returns the default physical interface name (the first non-local interface)
sub get_default_physical
{
@ifaces = &net::active_interfaces();
($nonlocal) = grep { $_->{'name'} ne "lo0" &&
		     $_->{'virtual'} eq "" } @ifaces;
return $nonlocal ? $nonlocal->{'fullname'} : "lo0";
}

# zone_status_actions(&zinfo, include-webmin)
# Returns possible actions for some status
sub zone_status_actions
{
local ($zinfo, $inc) = @_;
local $status = $zinfo->{'status'};
local $w = &zone_has_webmin($zinfo);
local $wr = &zone_running_webmin($zinfo);
return $status eq 'running' ?
	( [ "reboot", $text{'edit_reboot'} ],
	  [ "halt", $text{'edit_halt'} ],
	  $w == 1 && $inc ? ( [ "wupgrade", $text{'edit_wupgrade'} ] ) :
	  $w == 0 && $inc ? ( [ "winstall", $text{'edit_winstall'} ] ) : ( ),
	  $wr ? ( [ "webmin", $text{'edit_webmin'} ] ) : ( ) ) :
       $status eq 'installed' ?
	( [ "boot", $text{'edit_boot'} ],
	  [ "uninstall", $text{'edit_uninstall'} ] ) :
       $status eq 'configured' ?
	( [ "install", $text{'edit_install'} ] ) :
       $status eq 'ready' ?
	( [ "boot", $text{'edit_boot'} ],
	  [ "halt", $text{'edit_halt'} ] ) :
	( );

}

# create_webmin_install_script(&zinfo, file)
# Creates a shell script to install Webmin in a zone. Returns undef on success,
# or an error message if something would prevent Webmin from working.
sub create_webmin_install_script
{
local ($zinfo, $script) = @_;
local $perl_path = &get_perl_path();
local $root = &get_zone_root($zinfo);
if (!-x $root.$perl_path) {
	return &text('webmin_eperl', "<tt>$perl_path</tt>");
	}
local ($cat, $ex) = &run_in_zone($zinfo, "cat $root_directory/setup.sh");
if ($ex || !$cat) {
	return &text('webmin_eroot', "<tt>$root_directory</tt>");
	}
local %miniserv;
&get_miniserv_config(\%miniserv);

open(SCRIPT, ">$script");
print SCRIPT "#!/bin/sh\n";
print SCRIPT "config_dir=$config_directory\n";
print SCRIPT "var_dir=$var_directory\n";
print SCRIPT "perl=$perl_path\n";
print SCRIPT "autoos=3\n";
print SCRIPT "port=$miniserv{'port'}\n";
print SCRIPT "login=root\n";
print SCRIPT "crypt=x\n";
print SCRIPT "$perl_path -e 'use Net::SSLeay' >/dev/null 2>&1\n";
print SCRIPT "if [ \$? = 0 ]; then\n";
print SCRIPT "    ssl=1\n";
print SCRIPT "else\n";
print SCRIPT "    ssl=0\n";
print SCRIPT "fi\n";
print SCRIPT "atboot=1\n";
print SCRIPT "nochown=1\n";
print SCRIPT "autothird=1\n";
print SCRIPT "noperlpath=1\n";
print SCRIPT "nouninstall=1\n";
print SCRIPT "nostart=1\n";
print SCRIPT "export config_dir var_dir perl autoos port login crypt ssl atboot nochown autothird noperlpath nouninstall nostart\n";
print SCRIPT "cd $root_directory\n";
print SCRIPT "./setup.sh || exit 1\n";
print SCRIPT "$config_directory/start >/dev/null 2>&1 </dev/null &\n";
close(SCRIPT);
chmod(0755, $script);
return undef;
}

# zone_has_webmin(&zinfo)
# Returns 2 if Webmin is installed in the zone and is the same version, 1 if
# installed but older version, 0 if not installed at all
sub zone_has_webmin
{
local ($zinfo) = @_;
local $root = &get_zone_root($zinfo);
open(VERSION, $root.$config_directory."/version") || return 0;
local $version = <VERSION>;
close(VERSION);
chop($version);
return $version == &get_webmin_version() ? 2 : 1;
}

# zone_running_webmin(&zinfo)
# If a zone has Webmin installed and it is running, returns a URL for it
sub zone_running_webmin
{
local ($zinfo) = @_;
return undef if (!&zone_has_webmin($zinfo));
local $root = &get_zone_root($zinfo);
local %miniserv;
&read_file("$root$config_directory/miniserv.conf", \%miniserv);
local $pid = &check_pid_file($root.$miniserv{'pidfile'});
return undef if (!$pid);
local $prot = $miniserv{'ssl'} ? "https" : "http";
if (gethostbyname($zinfo->{'name'}) && !$zinfo->{'net'}) {
	# The zone name appears to resolve .. use it
	return "$prot://$zinfo->{'name'}:$miniserv{'port'}/";
	}
if ($zinfo->{'net'}) {
	local $ip = $zinfo->{'net'}->[0]->{'address'};
	$ip =~ s/\/\d+$//;
	if ($ip eq &to_ipaddress($zinfo->{'name'})) {
		$ip = $zinfo->{'name'};
		}
	return "$prot://$ip:$miniserv{'port'}/";
	}
return undef;
}

# get_global_locale()
# Returns the locale for the global zone (defaults to C)
sub get_global_locale
{
local %locale;
&read_env_file("/etc/default/init", \%locale);
return $locale{'LC_CTYPE'} || "C";
}

# save_sysidcfg(&sysid, file)
# Writes out a sysidcfg array
sub save_sysidcfg
{
local ($sysidcfg, $file) = @_;
open(FILE, ">$file");
local ($s, $k, $subs);
foreach $s (@$sysidcfg) {
	local ($sk, $sv) = @$s;
	if (ref($sv)) {
		# A sub-structure
		local ($v, @v) = @$sv;
		print FILE "$sk=$v {\n";
		foreach $subs (@v) {
			print FILE "\t$subs->[0]=$subs->[1]\n";
			}
		print FILE "}\n";
		}
	else {
		# A single value
		print FILE "$sk=$sv\n";
		}
	}
close(FILE);
}

# zone_sysidcfg_file(zone)
# Returns a filename for storing a temporary zone sysidcfg file before the
# zone is installed
sub zone_sysidcfg_file
{
return "$module_config_directory/$_[0].sysidcfg";
}

# config_zone_nfs(&zinfo)
# Setup the NFS configuration files for a zone. Should be called after installation
sub config_zone_nfs
{
local ($zinfo) = @_;
local $root = &get_zone_root($zinfo);
&system_logged("cp /etc/default/nfs $root/etc/default/nfs");
&system_logged("touch $root/etc/.NFS4inst_state.domain");
}

# post_webmin_install(&zinfo)
# Called after Webmin is installed in a Zone, to perform extra setup (like
# copying users/etc)
sub post_webmin_install
{
local $root = &get_zone_root($zinfo);
if (-r "$config_directory/webmin.cats") {
	system("cp $config_directory/webmin.cats $root/$config_directory/webmin.cats");
	}
if (-r "$config_directory/webmin.catnames") {
	system("cp $config_directory/webmin.catnames $root/$config_directory/webmin.catnames");
	}
}

1;

