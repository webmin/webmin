# itsecure-lib.pl
# Version
# ITsecur
# Common functions for all firewall types
# XXX only backup firewall module users?

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
do "$config{'type'}-lib.pl";

@opts = ( 'rules', 'services', 'groups', 'nat','nat2', 'pat', 'spoof', 'syn', 'logs',
	  'authlogs', 'report',
	  'users',
	  &supports_time() ? ('times') : (),
	  'backup', 'restore',
	  'remote', 'import' );
# Take out to test
#	&supports_bandwidth() ? ('bandwidth') : (),
@backup_opts = grep { $_ ne 'logs' && $_ ne 'backup' && $_ ne 'restore' }
		    (@opts, 'ipsec', 'searches', 'config');

$groups_file = "$module_config_directory/groups";
$standard_services_file = "$module_root_directory/standard-services";
$services_file = "$module_config_directory/services";
$rules_file = "$module_config_directory/rules";
$nat_file = "$module_config_directory/nat";
$nat2_file = "$module_config_directory/nat2";
$pat_file = "$module_config_directory/pat";
$spoof_file = "$module_config_directory/spoof";
$syn_file = "$module_config_directory/syn";
$times_file = "$module_config_directory/times";
$active_interfaces = "$module_config_directory/active";
$prerules = "$module_config_directory/prerules";
$postrules = "$module_config_directory/postrules";
$prenat = "$module_config_directory/prenat";
$postnat = "$module_config_directory/postnat";
$debug_file = "$module_config_directory/debug";

$searches_dir = "$module_config_directory/searches";

@config_files = ( $groups_file, $services_file,
		  $rules_file, $nat_file, $nat2_file, $pat_file, $spoof_file,
		  $syn_file, $times_file );

%access = &get_module_acl();
if (defined($access{'edit'})) {
	if ($access{'edit'}) {
		@edit_access = @read_access = split(/\s+/, $access{'features'});
		}
	else {
		@read_access = split(/\s+/, $access{'features'});
		}
	}
else {
	@edit_access = split(/\s+/, $access{'features'});
	@read_access = split(/\s+/, $access{'rfeatures'});
	}
%edit_access = map { $_, 1 } @edit_access;
%read_access = map { $_, 1 } @read_access;

$cron_cmd = "$module_config_directory/backup.pl";

# list_groups([file])
# Returns a list of groups. Each has a name and zero or more member hosts,
# IP addresses, networks or other groups.
sub list_groups
{
local @rv;
open(GROUPS, $_[0] || $groups_file);
while(<GROUPS>) {
	s/\r|\n//g;
	if (/^(\S+)\t+(.*)$/) {
		local $group = { 'name' => $1,
				 'members' => [ split(/\t+/, $2) ],
				 'index' => scalar(@rv) };
		push(@rv, $group);
		}
	}
close(GROUPS);
return @rv;
}

# save_groups(group, ...)
# Updates the groups list
sub save_groups
{
local $g;
local @SortGroups=();
foreach $g (@_) {
	push(@SortGroups,$g->{'name'}."\t".join("\t", @{$g->{'members'}})."\n"); 
	}
open(GROUPS, ">$groups_file");
print GROUPS sort { lc($a) cmp lc($b) } @SortGroups;
close(GROUPS);
&automatic_backup();
}

# list_services([file])
# Returns a list of services, each of which has a name and multiple
# protocols and port
sub list_services
{
local ($sf, @rv);
#if (!-r $standard_services_file) {
#	system("cp $module_root_directory/standard-services $standard_services_file");
#	}
foreach $sf ($_[0] || $services_file, $standard_services_file) {
	local @frv;
	open(SERVS, $sf);
	while(<SERVS>) {
		s/\r|\n//g;
		s/#.*$//;
		s/\s+$//;
		if (/^(\S+)\t+(.*)$/) {
			local $serv = { 'name' => $1,
					'standard' =>
					    ($sf eq $standard_services_file),
					'index' => scalar(@frv) };
			local @pps = split(/\s*\t+\s*/, $2);
			local $i;
			for($i=0; $i<@pps; $i+=2) {
				if ($pps[$i] eq "other") {
					push(@{$serv->{'others'}}, $pps[$i+1]);
					}
				else {
					push(@{$serv->{'protos'}}, $pps[$i]);
					push(@{$serv->{'ports'}}, $pps[$i+1]);
					}
				}
			push(@frv, $serv);
			}
		}
	close(SERVS);
	if ($sf eq $standard_services_file) {
		push(@rv, sort { lc($a->{'name'}) cmp lc($b->{'name'}) } @frv);
		}
	else {
		push(@rv, @frv);
		}
	}
return @rv;
}

# combine_services(comma-list, &services-hash)
# Returns lists of protocols and port numbers taken from a comma-separated list
# of service names
sub combine_services
{
local (@protos, @ports);
foreach $sn (split(/,/, $_[0])) {
	local $serv = $_[1]->{$sn};
	push(@protos, @{$serv->{'protos'}});
	push(@ports, @{$serv->{'ports'}});
	local ($cprotos, $cports) = &combine_services(join(",", @{$serv->{'others'}}), $_[1]);
	push(@protos, @$cprotos);
	push(@ports, @$cports);
	}
return (\@protos, \@ports);
}

# save_services(service, ...)
sub save_services
{
#open(SERVS, ">$services_file");

local @SortGroups;
local $data;
foreach $serv (@_) {
	next if ($serv->{'standard'});
	$data=$serv->{'name'};
	local $i;
	for($i=0; $i<@{$serv->{'protos'}}; $i++) {
		$data = $data . "\t" . $serv->{'protos'}->[$i] . "\t" . $serv->{'ports'}->[$i];
		}
	for($i=0; $i<@{$serv->{'others'}}; $i++) {
		if ( $serv->{'others'}->[$i] ne $serv->{'name'}) {	
 			$data = $data . "\tother\t".$serv->{'others'}->[$i];
                	}
		}
	$data=$data . "\n";
	push(@SortGroups,$data);
	}


open(SERVS, ">$services_file");
print SERVS sort { lc($a) cmp lc($b) } @SortGroups;
close(SERVS);

}

# list_rules([file])
# Returns a list of rules, each of which has a source, destination, service,
# action and log-flag
sub list_rules
{
local @rv;
open(RULES, $_[0] || $rules_file);
local $rn = 1;
while(<RULES>) {
	s/\r|\n//g;
	if (/^(#*)([^\t]+)\t+([^\t]+)\t+(\S+)\t+(\S+)\t+(\d+)(\t+(\S+))?(\t+(\S+))?$/) {
		local $rule = { 'enabled' => !$1,
				'source' => $2,
				'dest' => $3,
				'service' => $4,
				'action' => $5,
				'log' => $6,
				'time' => $8 || "*",
				'desc' => &un_urlize($10 || "*"),
				'index' => scalar(@rv),
				'num' => $rn++ };
		push(@rv, $rule);
		}
	elsif (/^(\S+)$/) {
		local $sep = { 'sep' => 1,
			       'desc' => &un_urlize($1),
				'index' => scalar(@rv) };
		push(@rv, $sep);
		}
	}
close(RULES);
return @rv;
}

# save_rules(rule, ...)
sub save_rules
{
open(RULES, ">$rules_file");
local $rule;
foreach $rule (@_) {
	if ($rule->{'sep'}) {
		print RULES &urlize($rule->{'desc'}),"\n";
		}
	else {
		print RULES ($rule->{'enabled'} ? "" : "#"),
			    $rule->{'source'},"\t",
			    $rule->{'dest'},"\t",
			    $rule->{'service'},"\t",
			    $rule->{'action'},"\t",
			    $rule->{'log'},"\t",
			    $rule->{'time'},"\t",
			    $rule->{'desc'} eq "*" ? "*"
				: &urlize($rule->{'desc'}),"\n";
		}
	}
close(RULES);
}

# group_name(string, [direction])
# Given a source or destination name that may be a group, makes it nice
sub group_name
{
if ($_[0] =~ /^\@(.*)$/) {
	# Host group
	return "<font color=#0000ff>$1</font>";
	}
elsif ($_[0] =~ /^\!\@(.*)$/) {
	# Negated host group
	return "<font color=#0000ff>".&text('not', "$1")."</font>";
	}
elsif ($_[0] =~ /^\%(.*)$/) {
	# Interface
	return "<font color=#C0C0C0>".&text('iface', "$1")."</font>";
	}
elsif ($_[0] =~ /^\!\%(.*)$/) {
	# Negated interface
	return "<font color=#C0C0C0>".&text('iface_not', "$1")."</font>";
	}
elsif ($_[0] eq '*') {
	# Anywhere
	return $text{'anywhere'};
	}
elsif ($_[0] eq '!*') {
	# Nowhere
	return $text{'nowhere'};
	}
elsif ($_[0] =~ /^\!(.*\/.*)$/) {
	# Negated network address
	return &text('not', "<tt><font color=#008800>$1</font></tt>");
	}
elsif ($_[0] =~ /^\!([0-9\.]+)\-([0-9]+)$/) {
	# Negated address range
	return &text('not', "<tt><font color=#ffff00>$1-$2</font></tt>");
	}
elsif ($_[0] =~ /^\!(.*)$/) {
	# Negated hostname or IP
	return &text('not', "<tt>$1</tt>");
	}
elsif ($_[0] =~ /^(.*\/.*)$/) {
	# Network address
	return "<tt><font color=#008800>$_[0]</font></tt>";
	}
elsif ($_[0] =~ /^([0-9\.]+)\-([0-9]+)$/) {
	# Address range
	return "<tt><font color=#ffff00>$1-$2</font></tt>";
	}
else {
	# Hostname or IP
	return "<tt>$_[0]</tt>";
	}
}

# group_names(string)
sub group_names
{
return join(", ", map { &group_name($_) } split(/\s+/, $_[0]));
}

# group_names_link(dest, [from], [direction])
sub group_names_link
{
local $g;
local @rv;
foreach $g (split(/\s+/, $_[0])) {
	if ($g =~ /^\@(.*)$/ || $g =~ /^\!\@(.*)$/) {
		push(@rv, &ui_link("edit_group.cgi?name=$1&from=$_[1]",&group_name($g, $_[2])));
		}
	else {
		push(@rv, &group_name($g, $_[2]));
		}
	}
return join(", ", @rv);
}

# group_input(name, [value], [blankoption], [multiple])
sub group_input
{
local @groups = &list_groups();
return undef if (!@groups);
local $rv = $_[3] ? "<select name=$_[0] size=5 multiple>"
		  : "<select name=$_[0]>\n";
if ($_[2]) {
	$rv .= sprintf "<option value='' %s>%s</option>\n",
		$_[1] ? "" : "selected", $_[2] == 2 ? $text{'other'} : "&nbsp;";
	}
local $g;
local %vals = map { $_, 1 } split(/\s+/, $_[1]);
foreach $g (@groups) {
	$rv .= sprintf "<option value=%s %s>%s</option>\n",
		$g->{'name'}, $vals{$g->{'name'}} ? "selected" : "",
		$g->{'name'};
	}
$rv .= "</select>\n";
return $rv;
}

# service_input(name, value, [blankoption], [multiple], [norange])
sub service_input
{
local @servs = &list_services();
local %got = map { $_, 1 } split(/,/, $_[1]);
local $rv = $_[3] ? "<select name=$_[0] size=5 multiple>"
		  : "<select name=$_[0]>\n";
if ($_[2]) {
	$rv .= sprintf "<option value='' %s>%s</option>\n",
		$_[1] ? "" : "selected", $_[2] == 2 ? $text{'other'} : "&nbsp;";
	}
local $s;
foreach $s (@servs) {
	local $desc;
	local @up = &unique(@{$s->{'protos'}});
	local $i;
	if (@up == 1) {
		$desc = uc($up[0])." ".join(", ", @{$s->{'ports'}});
		}
	else {
		for($i=0; $i<@{$s->{'protos'}}; $i++) {
			$desc .= ", " if ($desc);
			$desc .= uc($s->{'protos'}->[$i])."/".	
				 $s->{'ports'}->[$i];
			}
		}
	for($i=0; $i<@{$s->{'others'}}; $i++) {
		$desc .= ", " if ($desc);
		$desc .= $s->{'others'}->[$i];
		}
	$rv .= sprintf "<option value=%s %s>%s%s</option>\n",
		$s->{'name'}, $got{$s->{'name'}} ? "selected" : "",
		$s->{'name'}, $_[4] ? "" : " ($desc)";
	}
$rv .= "</select>\n";
return $rv;
}

# action_input(name, value, [select-mode])
sub action_input
{
local $rv;
local $a;
if ($_[2]) {
	$rv .= "<select name=$_[0]>\n";
	foreach $a (@actions) {
		$rv .= sprintf "<option value=%s %s>%s</option>\n",
			$a, $_[1] eq $a ? "selected" : "",
			$text{"rule_".$a};
		}
	$rv .= "</select>\n";
	}
else {
	foreach $a (@actions) {
		$rv .= sprintf "<input type=radio name=%s value=%s %s>%s\n",
			$_[0], $a, $_[1] eq $a ? "checked" : "",
			$text{"rule_".$a};
		}
	}
return $rv;
}


# protocol_input(name, value)
sub protocol_input
{
local @protos = ( 'tcp', 'udp', 'icmp', 'ip' );
#open(PROTOS, "/etc/protocols");
#while(<PROTOS>) {
#        s/\r|\n//g;
#        s/#.*$//;
#        push(@protos, $1) if (/^(\S+)\s+(\d+)/);
#        }
#close(PROTOS);
local $p;
local $rv = "<select name=$_[0]>\n";
$rv .= sprintf "<option value='' %s>&nbsp;</option>\n",
		$_[1] eq '' ? "selected" : "";
foreach $p (&unique(@protos)) {
        $rv .= sprintf "<option value='%s' %s>%s</option>\n",
                        $p, $_[1] eq $p && $p ? "selected" : "",
                        uc($p) || "-------";
        }
$rv .= "</select>\n";
return $rv;
}

sub valid_host
{

if (&check_ipaddress($_[0])) {
	return 1;
	}
elsif (gethostbyname($_[0])) {
	return 2;
	}
elsif (&check_netaddress($_[0])) {
	#$_[0] =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/) {
	return 3;
	}
elsif ($_[0] =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\-(\d+)$/) {
	return 4;
	}
else {
	return 0;
	}
}

# iface_input(name, value, [realonly], [nother], [nonemode])
sub iface_input
{
local @ifaces;
if (&foreign_check("net")) {
	&foreign_require("net", "net-lib.pl");
	local $i;
	foreach $i (&net::active_interfaces(), &net::boot_interfaces()) {
		push(@ifaces, $i->{'fullname'})
			if (!$_[2] || $i->{'virtual'} eq '');
		}
	@ifaces = &unique(@ifaces);
	}
if (@ifaces) {
	local $rv = "<select name=$_[0]>\n";
	local ($i, $found);
	if ($_[4]) {
		$rv .= sprintf "<option value='' %s>%s</option>\n",
			$_[1] eq "" ? "selected" : "", "&lt;None&gt;";
		$found++ if ($_[1] eq "");
		}
	foreach $i (@ifaces) {
		$rv .= sprintf "<option value=%s %s>%s</option>\n",
			$i, $_[1] eq $i ? "selected" : "", $i;
		$found++ if ($_[1] eq $i);
		}
	if ($_[3]) {
		$rv .= "<option value=$_[1] selected>$_[1]</option>\n" if (!$found && $_[1]);
		}
	else {
		$rv .= sprintf "<option value='' %s>%s</option>\n",
				!$found && $_[1] ? "selected" : "", $text{'rule_oifc'};
		$rv .= "</select>\n";
		$rv .= sprintf "<input name=$_[0]_other size=6 value='%s'>\n",
				!$found ? $_[1] : "";
		}
	return $rv;
	}
else {
	return "<input name=$_[0] size=6 value='$_[1]'>";
	}
}

# time_input(name, [value])
sub time_input
{
local @times = &list_times();
return undef if (!@times);
local $rv = "<select name=$_[0]>\n";
local $t;
foreach $t (@times) {
	$rv .= sprintf "<option value=%s %s>%s</option>\n",
		$t->{'name'}, $t->{'name'} eq $_[1] ? "selected" : "",
		$t->{'name'};
	}
$rv .= "</select>\n";
return $rv;
}

# get_nat([file])
sub get_nat
{
local ($iface, @nets, @maps);
open(NAT, $_[0] || $nat_file) || return ( );
chop($iface = <NAT>);
while(<NAT>) {
	s/\r|\n//g;
	if (/^(\S+)$/) {
		push(@nets, $_);
		}
	elsif (/^(\S+)\t+(\S+)\t+(\S+)$/) {
		push(@maps, [ $1, $2, $3 ]);
		}
	elsif (/^(\S+)\t+(\S+)$/) {
		push(@maps, [ $1, $2 ]);
		}
	}
close(NAT);
return ( $iface, @nets, @maps );
}

# save_nat(iface, net, ..)
sub save_nat
{
open(NAT, ">$nat_file");
print NAT shift(@_),"\n";
local $n;
foreach $n (@_) {
        if (ref($n)) {
                print NAT join("\t", @$n),"\n";
                }
        else {
                print NAT $n,"\n";
                }
        }
close(NAT);
}

sub save_nat2
{
open(NAT, ">$nat2_file");
print NAT shift(@_),"\n";
local $n;
foreach $n (@_) {
        if (ref($n)) {
                print NAT join("\t", @$n),"\n";
                }
        else {
                print NAT $n,"\n";
                }
        }
close(NAT);
}


# get_pat([file])
sub get_pat
{
local ($defiface, @forwards);
open(PAT, $_[0] || $pat_file) || return ( );
chop($defiface = <PAT>);
while(<PAT>) {
	s/\r|\n//g;
	if (/^(\S+)\t+(\S+)\t+(\S+)$/) {
		push(@forwards, { 'service' => $1,
				  'host' => $2,
				  'iface' => $3 });
		}
	elsif (/^(\S+)\t+(\S+)$/) {
		push(@forwards, { 'service' => $1,
				  'host' => $2,
				  'iface' => $defiface });
		}
	}
close(PAT);
return @forwards;
}

# save_pat(forward, ...)
sub save_pat
{
open(PAT, ">$pat_file");
print PAT (@_ ? $_[0]->{'iface'} : ""),"\n";
local $f;
foreach $f (@_) {
	if ($f->{'iface'}) {
		print PAT "$f->{'service'}\t$f->{'host'}\t$f->{'iface'}\n";
		}
	else {
		print PAT "$f->{'service'}\t$f->{'host'}\n";
		}
	}
close(PAT);
}

# get_spoof([file])
sub get_spoof
{
local ($iface, @nets);
open(PAT, $_[0] || $spoof_file) || return ( );
chop($iface = <PAT>);
while(<PAT>) {
	s/\r|\n//g;
	if (/^(\S+)$/) {
		push(@nets, $_);
		}
	}
close(PAT);
return ( $iface, @nets );
}

# save_spoof(iface, net, ...)
sub save_spoof
{
open(PAT, ">$spoof_file");
print PAT shift(@_),"\n";
local $s;
foreach $s (@_) {
	print PAT "$s\n";
	}
close(PAT);
}

# get_syn([file])
sub get_syn
{
local ($flood, $spoof, $fin);
open(SYN, $_[0] || $syn_file) || return ( );
chop($flood = <SYN>);
chop($spoof = <SYN>);
chop($fin = <SYN>);
close(SYN);
return ($flood, $spoof, $fin);
}

# save_syn(flood, spoof, fin)
sub save_syn
{
open(SYN, ">$syn_file");
print SYN int($_[0]),"\n";
print SYN int($_[1]),"\n";
print SYN int($_[2]),"\n";
close(SYN);
}

# list_times([file])
# Returns a list of all time ranges
sub list_times
{
local @rv;
open(TIMES, $_[0] || $times_file);
while(<TIMES>) {
	s/\r|\n//g;
	local @t = split(/\t/, $_);
	if (@t >= 3) {
		local $time = { 'index' => scalar(@rv),
			        'name' => $t[0],
				'hours' => $t[1],
				'days' => $t[2] };
		push(@rv, $time);
		}
	}
close(TIMES);
return @rv;
}

# save_times(time, ...)
# Updates the time ranges list
sub save_times
{
open(TIMES, ">$times_file");
local $t;
foreach $t (@_) {
	print TIMES $t->{'name'},"\t",
		    $t->{'hours'},"\t",
		    $t->{'days'},"\n";
	}
close(TIMES);
}

# activate_interface(base, ip)
sub activate_interface
{
&foreign_require("net", "net-lib.pl");
local @active = &net::active_interfaces();
local ($base) = grep { $_->{'fullname'} eq $_[0] } @active;
local ($already) = grep { $_->{'address'} eq $_[1] } @active;
if ($base && !$already) {
	# Work out an interface number
	local $vmax = 0;
	foreach $a (@active) {
		$vmax = $a->{'virtual'}
			if ($a->{'name'} eq $base->{'name'} &&
			    $a->{'virtual'} > $vmax);
		}

	# Activate now
	$virt = { 'address' => $_[1],
		  'netmask' => $base->{'netmask'},
		  'broadcast' => $base->{'broadcast'},
		  'name' => $base->{'name'},
		  'virtual' => $vmax+1,
		  'up' => 1 };
	$virt->{'fullname'} = $virt->{'name'}.":".$virt->{'virtual'};
	&net::activate_interface($virt);

	# Save for later
	open(ACTIVE, ">>$active_interfaces");
	print ACTIVE "$virt->{'fullname'}\t$virt->{'address'}\n";
	close(ACTIVE);
	}
}

# deactivate_all_interfaces()
# Shuts down all interfaces activated by the above function
sub deactivate_all_interfaces
{
&foreign_require("net", "net-lib.pl");
open(ACTIVE, $active_interfaces);
while(<ACTIVE>) {
	if (/^(\S+)\s+(\S+)/) {
		local $addr = $2;
		local @active = &net::active_interfaces();
		local ($virt) = grep { $_->{'address'} eq $addr } @active;
		if ($virt && $virt->{'virtual'} ne '') {
			&net::deactivate_interface($virt);
			}
		}
	}
close(ACTIVE);
unlink($active_interfaces);
}

sub apply_button
{
if (&can_edit("apply")) {
	return &ui_link("apply.cgi?return=1",$text{'apply_button'});
	}
else {
	return undef;
	}
}

# expand_hosts(names, &groups)
# Give a list of host or group names, expands them to hosts
sub expand_hosts
{
local ($e, @rv);
local %groups = map { $_->{'name'}, $_ } @{$_[1]};
foreach $e (split(/\s+/, $_[0])) {
	if ($e =~ /^\@(.*)$/) {
		# Expand to all group members
		local $group = $groups{$1};
		foreach $m (@{$group->{'members'}}) {
			push(@rv, &expand_hosts($m, $_[1]));
			}
		}
	elsif ($e =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\-(\d+)$/) {
		# Expand to all IPs in range
		push(@rv, map { "$1.$2.$3.$_" } ($4 .. $5) );
		}
	else {
		# Just a single IP, host or network
		push(@rv, $e);
		}
	}
return @rv;
}

# can_use(feature)
sub can_use
{
return 1 if ($read_access{'*'} || $edit_access{'*'});
return $read_access{$_[0]} || $edit_access{$_[0]};
}

# can_edit(feature)
sub can_edit
{
return 0 if (!&can_use($_[0]));
return $edit_access{'*'} || $edit_access{$_[0]};
}

# can_use_error(feature)
sub can_use_error
{
&can_use($_[0]) || &error($text{$_[0]."_ecannot"} ||
			  &text('ecannot', $text{$_[0]."_title"}));
}

# can_edit_error(feature)
sub can_edit_error
{
&can_edit($_[0]) || &error($text{$_[0]."_ecannot"} ||
			  &text('ecannot', $text{$_[0]."_title"}));
}

# can_edit_disable(feature)
sub can_edit_disable
{
if (!&can_edit($_[0])) {
	print "<script>\n";
	print "l = document.forms[0].elements;\n";
	print "for(i=0; i<l.length; i++) {\n";
	print "    if (l[i].name != \"burn\" && l[i].name != \"test\" &&\n";
	print "        l[i].type != \"hidden\") {\n";
	print "        l[i].disabled = true;\n";
	print "    }\n";
	print "}\n";
	print "</script>\n";
	}
}

# protocol_name(proto, port)
sub protocol_name
{
local $pr = uc($_[0]);
local $pt = $_[1];
if ($pr eq "TCP") {
	return "<font color=#0000ff>$pr/$pt</font>";
	}
elsif ($pr eq "UDP") {
	return "<font color=#008800>$pr/$pt</font>";
	}
elsif ($pr eq "ICMP") {
	return "<font color=#f00000>$pr/$pt</font>";
	}
else {
	return "$pr/$pt";
	}
}

# protocol_names(comma-list, [&services])
sub protocol_names
{
if ($_[0] eq "*") {
	return $text{'rule_any'};
	}
else {
	local %sn = map { $_->{'name'}, $_ }
			( $_[1] ? @{$_[1]} : &list_services() );
	local $sn;
	local @rv;
	local ($editServO,$editServC);
	foreach $sn (split(/,/, $_[0])) {
		local $serv = $sn{$sn};
		if (!$serv->{'standard'}){
				$editServO = &ui_link("edit_service.cgi?name=".$serv->{'name'}, $editServC);				
			} else {
				$editServO="";
				$editServC="";							
			}
		local $pr = @{$serv->{'protos'}} == 1 ? uc($serv->{'protos'}->[0]) : undef;
		if ($pr eq "TCP") {
			push(@rv, "$editServO<font color=#0000ff>$sn</font>$editServC");
			}
		elsif ($pr eq "UDP") {
			push(@rv, "$editServO<font color=#008800>$sn</font>$editServC");
			}
		elsif ($pr eq "ICMP") {
			push(@rv, "$editServO<font color=#f00000>$sn</font>$editServC");
			}
		else {
			push(@rv, "$editServO $sn $editServC");
			}
		}
	return join(", ", @rv);
	}
}

# my_address_in(address/network)
# Returns this system's IP address in some network
sub my_address_in
{
local $net = $_[0];
$net =~ s/^\!\s+//;
if ($net =~ /[a-z]/i) {
	$net = &to_ipaddress($net);
	}
$net =~ s/^(\d+\.\d+\.\d+).*$/$1/;
&foreign_require("net", "net-lib.pl");
local @ifaces = &net::active_interfaces();
local $i;
local $primary;
foreach $i (@ifaces) {
	if ($i->{'up'}) {
		if (!$primary && $i->{'fullname'} !~ /^lo/) {
			$primary = $i->{'address'};
			}
		local $addr = $i->{'address'};
		$addr =~ s/^(\d+\.\d+\.\d+).*$/$1/;
		if ($addr eq $net) {
			return $i->{'address'};
			}
		}
	}
return $primary;
}

sub has_ipsec
{
return &foreign_installed("ipsec", 1);
}

# backup_firewall(&what, file, [password])
# Backs up the firewall to some file
sub backup_firewall
{
local ($mode, @dest) = &parse_backup_dest($_[1]);
local $file = $mode == 1 ? $dest[0] : &tempname();
local $ipsec_tmp = "$module_config_directory/ipsec.conf";
local $secrets_tmp = "$module_config_directory/ipsec.secrets";
local $users_tmp = "$module_config_directory/miniserv.users";
local $acl_tmp = "$module_config_directory/webmin.acl";
local $w;
local (@files, @delfiles);
foreach $w (@{$_[0]}) {
	if ($w eq "ipsec") {
		# Copy the ipsec.conf files
		if (&has_ipsec()) {
			system("cp $ipsec::config{'file'} $ipsec_tmp");
			system("cp $ipsec::config{'secrets'} $secrets_tmp");
			push(@delfiles, "ipsec.conf", "ipsec.secrets");
			}
		}
	elsif ($w eq "users") {
		# Copy all Webmin users
		opendir(DIR, $module_config_directory);
		push(@files, grep { /\.acl$/ } readdir(DIR));
		closedir(DIR);
		system("cp $config_directory/miniserv.users $users_tmp");
		system("cp $config_directory/webmin.acl $acl_tmp");
		push(@delfiles, "miniserv.users", "webmin.acl");
		}
	else {
		push(@files, $w) if (-r "$module_config_directory/$w");
		}
	}
push(@files, @delfiles);
local $what = join(" ", @files);
return $text{'backup_ewhat2'} if (!$what);
local $pass = $_[2] ? "-P '$_[2]'" : "";
local $out = &backquote_logged("(cd $module_config_directory ; zip -r $pass '$file' $what) 2>&1");
return "<pre>$out</pre>" if ($?);
unlink(map { "$module_config_directory/$_" } @delfiles);

# Send to destination
if ($mode == 2) {
	# FTP somewhere
	local $err;
	&ftp_upload($dest[2], $dest[3], $file, \$err, undef, $dest[0], $dest[1]);
	unlink($file);
	return $err if ($err);
	}
elsif ($mode == 3) {
	# Email somewhere
	$data = `cat $file`;
	unlink($file);
	$host = &get_system_hostname();
	$body = "The backup of the firewall configuration on $host is attached to this email.\n";
	local $mail = { 'headers' =>
			[ [ 'From', $config{'from'} || "webmin\@$host" ],
			  [ 'To', $dest[0] ],
			  [ 'Subject', "Firewall backup" ] ],
			'attach' =>
			[ { 'headers' => [ [ 'Content-type', 'text/plain' ] ],
			    'data' => $body },
			  { 'headers' => [ [ 'Content-type', 'application/zip' ],
					   [ 'Content-Transfer-Encoding', 'base64' ] ],
			    'data' => $data } ] };
	$main::errors_must_die = 1;
	if (&foreign_check("mailboxes")) {
		&foreign_require("mailboxes", "mailboxes-lib.pl");
		eval { &mailboxes::send_mail($mail); };
		}
	else {
		&foreign_require("sendmail", "sendmail-lib.pl");
		&foreign_require("sendmail", "boxes-lib.pl");
		eval { &sendmail::send_mail($mail); };
		}
	return $@ if ($@);
	}

return undef;
}

sub check_zip
{
&has_command("zip") && &has_command("unzip") ||
	&error($text{'backup_ezipcmd'});
}

sub find_backup_job
{
&foreign_require("cron", "cron-lib.pl");
local @jobs = &cron::list_cron_jobs();
local ($job) = grep { $_->{'user'} eq 'root' &&
		      $_->{'command'} eq $cron_cmd } @jobs;
return $job;
}

sub parse_backup_dest
{
if ($_[0] =~ /^mailto:(.*)/) {
	return (3, $1);
	}
elsif ($_[0] =~ /^ftp:\/\/([^:]*):([^@]*)@([^\/]+)(\/.*)$/) {
	return (2, $1, $2, $3, $4);
	}
elsif ($_[0] =~ /^\//) {
	return (1, $_[0]);
	}
else {
	return (0);
	}
}

# ftp_upload(host, file, srcfile, [&error], [&callback], [user, pass])
# Download data from a local file to an FTP site
sub ftp_upload
{
local($buf, @n);
local $cbfunc = $_[4];

$download_timed_out = undef;
local $SIG{ALRM} = "download_timeout";
alarm(60);

# connect to host and login
&open_socket($_[0], 21, "SOCK", $_[3]) || return 0;
alarm(0);
if ($download_timed_out) {
	if ($_[3]) { ${$_[3]} = $download_timed_out; return 0; }
	else { &error($download_timed_out); }
	}
&ftp_command("", 2, $_[3]) || return 0;
if ($_[5]) {
	# Login as supplied user
	local @urv = &ftp_command("USER $_[5]", [ 2, 3 ], $_[3]);
	@urv || return 0;
	if (int($urv[1]/100) == 3) {
		&ftp_command("PASS $_[6]", 2, $_[3]) || return 0;
		}
	}
else {
	# Login as anonymous
	local @urv = &ftp_command("USER anonymous", [ 2, 3 ], $_[3]);
	@urv || return 0;
	if (int($urv[1]/100) == 3) {
		&ftp_command("PASS root\@".&get_system_hostname(), 2,
			     $_[3]) || return 0;
		}
	}
&$cbfunc(1, 0) if ($cbfunc);

&ftp_command("TYPE I", 2, $_[3]) || return 0;

# get the file size and tell the callback
local @st = stat($_[2]);
if ($cbfunc) {
	&$cbfunc(2, $st[7]);
	}

# send the file
local $pasv = &ftp_command("PASV", 2, $_[3]);
defined($pasv) || return 0;
$pasv =~ /\(([0-9,]+)\)/;
@n = split(/,/ , $1);
&open_socket("$n[0].$n[1].$n[2].$n[3]", $n[4]*256 + $n[5], "CON", $_[3]) || return 0;
&ftp_command("STOR $_[1]", 1, $_[3]) || return 0;

# transfer data
local $got;
open(PFILE, $_[2]);
while(read(PFILE, $buf, 1024) > 0) {
	print CON $buf;
	$got += length($buf);
	&$cbfunc(3, $got) if ($cbfunc);
	}
close(PFILE);
close(CON);
if ($got != $st[7]) {
	if ($_[3]) { ${$_[3]} = "Upload incomplete"; return 0; }
	else { &error("Upload incomplete"); }
	}
&$cbfunc(4) if ($cbfunc);

# finish off..
&ftp_command("", 2, $_[3]) || return 0;
&ftp_command("QUIT", 2, $_[3]) || return 0;
close(SOCK);

return 1;
}

# lock_itsecur_files()
# Lock all firewall config files
sub lock_itsecur_files
{
local $f;
foreach $f (@config_files) {
	&lock_file($f);
	}
}

# unlock_itsecur_files()
# Unlock all firewall config files
sub unlock_itsecur_files
{
local $f;
foreach $f (@config_files) {
	&unlock_file($f);
	}
}

sub remote_webmin_log
{
if ($config{'remote_log'} && !fork()) {
	# Disconnect from TTY
	untie(*STDIN);
	untie(*STDOUT);
	untie(*STDERR);
	close(STDIN);
	close(STDOUT);
	close(STDERR);

	# Send log to remote host
	&remote_foreign_require($config{'remote_log'}, $module_name,
				"itsecur-lib.pl");
	local $d;
	foreach $d (@main::locked_file_diff) {
		&remote_foreign_call($config{'remote_log'}, $module_name,
				     "additional_log", $d->{'type'},
				     $d->{'object'}, $d->{'data'});
		}
	local $script_name = $0 =~ /([^\/]+)$/ ? $1 : '';
	&remote_foreign_call($config{'remote_log'}, $module_name,
			     "webmin_log", @_[0..3], $module_name,
			     &get_system_hostname(),
			     $script_name,
			     $ENV{'REMOTE_HOST'});

	exit(0);
	}
&webmin_log(@_);
}

# automatic_backup()
# If a change has been made and an automatic backup directory set, save the
# module's configuration
sub automatic_backup
{
return if (!$config{'auto_dir'} || !-d $config{'auto_dir'});

# Backup to a temp file
local $temp = &tempname();
local $err = &backup_firewall(\@backup_opts, $temp, undef);
if ($err) {
	unlink($temp);
	return 0;
	}

# Make sure this backup is actually different from the last
local $linkfile = "$config{'auto_dir'}/latest.zip";
if (-r $linkfile) {
	local $out = `diff '$config{'auto_dir'}/latest.zip' '$temp' 2>&1`;
	if ($? == 0) {
		# No change!
		unlink($temp);
		return 0;
		}
	}

# Copy to directory, and update latest link
use POSIX;
local $newfile = strftime "$config{'auto_dir'}/firewall.%Y-%m-%d-%H:%M:%S.zip",
			localtime(time());
system("mv '$temp' '$newfile'");
unlink($linkfile);
symlink($newfile, $linkfile);

return 1;
}

# parse_all_logs([base-only])
# Returns a list of all log structures, newest first
sub parse_all_logs
{
local $baselog = $config{'log'} || &get_log_file();
local @rv;
foreach $log ($config{'all_files'} && !$_[0] ? &all_log_files($baselog)
					     : ($baselog)) {
	if ($log =~ /\.gz$/i) {
		open(LOG, "gunzip -c ".quotemeta($log)." |");
		}
	elsif ($log =~ /\.Z$/i) {
		open(LOG, "uncompress -c ".quotemeta($log)." |");
		}
	else {
		open(LOG, $log);
		}
	while(<LOG>) {
		local $info = &parse_log_line($_);
		push(@rv, $info) if ($info);
		}
	close(LOG);
	}
return reverse(@rv);
}

# all_log_files(file)
sub all_log_files
{
$_[0] =~ /^(.*)\/([^\/]+)$/;
local $dir = $1;
local $base = $2;
local ($f, @rv);
opendir(DIR, $dir);
foreach $f (readdir(DIR)) {
	if ($f =~ /^\Q$base\E/ && -f "$dir/$f") {
		push(@rv, "$dir/$f");
		}
	}
closedir(DIR);
return @rv;
}

@search_fields = ("src", "dst", "dst_iface", "proto", "src_port", "dst_port",
		  "first", "last", "action", "rule");

# filter_logs(&logs, &in, [&searchvars])
sub filter_logs
{
local @logs = @{$_[0]};
local %in = %{$_[1]};
local $f;
local @servs = &list_services();
local @groups = &list_groups();
local %servs = map { $_->{'name'}, $_ } @servs;
foreach $f (@search_fields) {
	if ($in{$f."_mode"}) {
		# This search applies .. find all suitable match types
		local %matches;
		local $tm;
		if (($f eq "src_port" || $f eq "dst_port") && $in{$f."_what"}) {
			# Lookup all ports and protocols
			local ($protos, $ports) =
				&combine_services($in{$f."_what"}, \%servs);
			local $i;
			for($i=0; $i<@$protos; $i++) {
				if ($ports->[$i] =~ /^(\d+)\-(\d+)$/) {
					local $p;
					foreach $p ($1 .. $2) {
						$matches{lc($protos->[$i]),$p}++;
						}
					}
				else {
					$matches{lc($protos->[$i]),$ports->[$i]}++;
					}
				}
			}
		elsif (($f eq "src_port" || $f eq "dst_port") && !$in{$f."_what"}) {
			# One specified port number
			$matches{$in{$f."_other"}}++;
			}
		elsif (($f eq "src" || $f eq "dst") && $in{$f."_what"}) {
			# Lookup all hosts
			local @hosts = &expand_hosts(
				'@'.$in{$f."_what"}, \@groups);
			local $h;
			foreach $h (@hosts) {
				local $eh;
				foreach $eh (&expand_net($h)) {
					$matches{$eh}++;
					}
				}
			}
		elsif (($f eq "src" || $f eq "dst") && !$in{$f."_what"}) {
			# One other host
			local $eh;
			foreach $eh (&expand_net($in{$f."_other"})) {
				$matches{$eh}++;
				}
			}
		elsif ($f eq "first" || $f eq "last") {
			# A time range
			eval { $tm = timelocal(
				0, $in{$f."_min"}, $in{$f."_hour"},
				$in{$f."_day"}, $in{$f."_month"}-1,
				$in{$f."_year"}-1900); };
			}
		else {
			$matches{lc($in{$f."_what"})}++;
			}

		if ($f eq "first" && $tm) {
			# Find those after start minute
			@logs = grep { $_->{'time'} >= $tm } @logs;
			}
		elsif ($f eq "last" && $tm) {
			# Find those before end minute
			@logs = grep { $_->{'time'} < $tm+60 } @logs;
			}
		elsif ($in{$f."_mode"} == 1) {
			# Find matching entries
			@logs = grep {
				$matches{lc($_->{$f})} ||
				$matches{lc($_->{'proto'}),lc($_->{$f})} }
				     @logs;
			}
		elsif ($in{$f."_mode"} == 2) {
			# Find non-matching entries
			@logs = grep {
				!($matches{lc($_->{$f})} ||
				  $matches{lc($_->{'proto'}),lc($_->{$f})}) }
				     @logs;
			}
		if ($_[2]) {
			local $e;
			foreach $e ("mode", "what", "other", "day",
				    "month", "year") {
				if ($in{$f."_".$e} ne "") {
					push(@{$_[2]}, $f."_".$e."=".
					     &urlize($in{$f."_".$e}));
					}
				}
			}
		}
	}
return @logs;
}

# expand_net(network)
# Given a network address, hostname or IP address, returns a list of all
# IP addresses it contains
sub expand_net
{
if ($_[0] =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/) {
	local @rv;
	local $first = ($1<<24) + ($2<<16) + ($3<<8) + ($4);
	local $last = $first + (1<<(32-$5)) - 1;
	for($ipnum=$first; $ipnum<=$last; $ipnum++) {
		local @ip = ( ($ipnum>>24)&0xff,
			      ($ipnum>>16)&0xff,
			      ($ipnum>>8)&0xff,
			      ($ipnum)&0xff );
		push(@rv, join(".", @ip));
		}
	return @rv;
	}
else {
	return &to_ipaddress($_[0]);
	}
}

# list_searches()
# Returns a list of all saved searches
sub list_searches
{
local @rv;
opendir(DIR, $searches_dir);
local $f;
while($f = readdir(DIR)) {
	if ($f ne "." && $f ne "..") {
		local $search = &get_search($f);
		push(@rv, $search) if ($search);
		}
	}
closedir(DIR);
return @rv;
}

sub get_search
{
local %search;
if (&read_file("$searches_dir/$_[0]", \%search)) {
	return \%search;
	}
else {
	return undef;
	}
}

# save_search(&search)
sub save_search
{
mkdir($searches_dir, 0755);
&write_file("$searches_dir/$_[0]->{'save_name'}", $_[0]);
}

# get_remote()
# Returns the webmin servers object used for remote logging, or undef
sub get_remote
{
return undef if (!$config{'remote_log'});
&foreign_require("servers", "servers-lib.pl");
local @servers = &servers::list_servers();
local ($server) = grep { $_->{'host'} eq $config{'remote_log'} } @servers;
return $server;
}

# save_remote(server, port, username, password, test, save)
sub save_remote
{
local ($host, $port, $user, $pass, $test, $save) = @_;
&foreign_require("servers", "servers-lib.pl");
if ($host) {
	# Enabling or updating
	local @servers = &servers::list_servers();
	local ($newserver) = grep { $_->{'host'} eq $host } @servers;
	local $server = &get_remote();
	if ($newserver && $server) {
		if ($newserver ne $server) {
			# Re-name would cause clash, so delete it
			&servers::delete_server($newserver->{'id'});
			}
		}
	elsif ($newserver && !$server) {
		# Re-naming server
		$server = $newserver;
		}
	elsif (!$newserver && $server) {
		# Can just stick to old server
		}
	else {
		# Totally new
		$server = { 'id' => time(),
			    'port' => $port,
			    'ssl' => 0,
			    'desc' => 'Firewall logging server',
			    'type' => 'unknown',
			    'fast' => 0 };
		}
	$server->{'host'} = $host;
	$server->{'port'} = $port;
	$server->{'user'} = $user;
	$server->{'pass'} = $pass;
	&servers::save_server($server);
	$config{'remote_log'} = $server->{'host'};

	if ($test) {
		# Try a test connection
		&remote_error_setup(\&test_error);
		eval {
			$SIG{'ALRM'} = sub { die "alarm\n" };
			alarm(10);
			&remote_foreign_require($server->{'host'}, "webmin",
						"webmin-lib.pl");
			alarm(0);
			};
		if ($@) {
			&error(&text('remote_econnect', $text{'remote_etimeout'}));
			}
		elsif ($test_error_msg) {
			&error(&text('remote_econnect', $test_error_msg));
			}
		}
	}
else {
	# Disabling
	delete($config{'remote_log'});
	}
if ($save) {
	&lock_file($module_config_file);
	&write_file($module_config_file, \%config);
	&unlock_file($module_config_file);
	}
}

sub test_error
{
$test_error_msg = join("", @_);
}

sub check_netaddress
{
return $_[0] =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/ &&
	$1 >= 0 && $1 <= 255 &&
	$2 >= 0 && $2 <= 255 &&
	$3 >= 0 && $3 <= 255 &&
	$4 >= 0 && $4 <= 255 &&
	$5 >= 0 && $5 <= 32;
}

sub is_one_host
{
local @groups = &list_groups();
local @rv=&expand_hosts($_[0], \@groups);
return $#rv;
}

1;

