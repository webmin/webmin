# heartbeat-lib.pl
# Common functions for heartbeat tool configuration

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

$ha_cf = $config{'ha_cf'} ? $config{'ha_cf'} : "$config{'ha_dir'}/ha.cf";
$haresources = $config{'haresources'} ? $config{'haresources'}
				      : "$config{'ha_dir'}/haresources";
$authkeys = $config{'authkeys'} ? $config{'authkeys'}
				: "$config{'ha_dir'}/authkeys";
$resource_d = $config{'resource_d'} ? $config{'resource_d'}
				    : "$config{'ha_dir'}/resource.d";

open(VERSION, "$module_config_directory/version");
chop($heartbeat_version = <VERSION>);
close(VERSION);

sub get_ha_config
{
local @rv;
local $lnum = 0;
open(CONF, $ha_cf);
while(<CONF>) {
	s/\s+$//;
	s/#.*$//;
	if (/^(\S+)\s+(\S.*)$/) {
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'line' => $lnum });
		}
	$lnum++;
	}
close(CONF);
return @rv;
}

# find(name, &config)
sub find
{
local @rv;
foreach $c (@{$_[1]}) {
	if ($c->{'name'} eq $_[0]) {
		push(@rv, $c->{'value'});
		}
	}
return wantarray ? @rv : @rv==0 ? undef : $rv[0];
}

# find_struct(name, &config)
sub find_struct
{
local @rv;
foreach $c (@{$_[1]}) {
	if ($c->{'name'} eq $_[0]) {
		push(@rv, $c);
		}
	}
return wantarray ? @rv : @rv==0 ? undef : $rv[0];
}

# save_directive(&config, name, &values)
sub save_directive
{
local $lref = &read_file_lines($ha_cf);
local @old = &find_struct($_[1], $_[0]);
for($i=0; $i<@old || $i<@{$_[2]}; $i++) {
	if ($i >= @old) {
		# adding a directive
		push(@$lref, "$_[1]\t$_[2]->[$i]");
		push(@{$_[0]}, { 'name' => $_[1],
				 'value' => $_[2]->[$i],
				 'line' => scalar(@$lref)-1 });
		}
	elsif ($i >= @{$_[2]}) {
		# removing a directive
		splice(@$lref, $old[$i]->{'line'}, 1);
		splice(@{$_[0]}, &indexof($old[$i], @{$_[0]}), 1);
		&renumber($_[0], $old[$i]->{'line'}, -1);
		}
	else {
		# updating a directive
		splice(@$lref, $old[$i]->{'line'}, 1, "$_[1]\t$_[2]->[$i]");
		$old[$i]->{'value'} = $_[2]->[$i];
		}
	}
}

# renumber(&config, line, offset)
sub renumber
{
foreach $c (@{$_[0]}) {
	if ($c->{'line'} > $_[1]) {
		$c->{'line'} += $_[2];
		}
	}
}

sub list_resources()
{
local @rv;
local $lnum = 0;
open(RES, $haresources);
while(<RES>) {
	s/\s+$//;
	s/#.*$//;
	local @res = split(/\s+/, $_);
	if (@res > 0) {
		local $r = { 'node' => shift(@res),
			     'line' => $lnum };
		foreach $v (@res) {
			if ($v =~ /^[0-9\.\/]+$/) {
				push(@{$r->{'ips'}}, $v);
				}
			elsif ($v =~ /^IPaddr::(\S+)$/) {
				push(@{$r->{'ips'}}, $1);
				}
			else {
				push(@{$r->{'servs'}}, $v);
				}
			}
		push(@rv, $r);
		}
	$lnum++;
	}
close(RES);
return @rv;
}

sub create_resource
{
local $lref = &read_file_lines($haresources);
push(@$lref, &resource_line($_[0]));
&flush_file_lines();
}

sub modify_resource
{
local $lref = &read_file_lines($haresources);
$lref->[$_[0]->{'line'}] = &resource_line($_[0]);
&flush_file_lines();
}

sub delete_resource
{
local $lref = &read_file_lines($haresources);
splice(@$lref, $_[0]->{'line'}, 1);
&flush_file_lines();
}

sub resource_line
{
local @l = ( $_[0]->{'node'} );
push(@l, @{$_[0]->{'ips'}});
push(@l, @{$_[0]->{'servs'}});
return join(" ", @l);
}

sub get_auth_config
{
local $rv;
open(AUTH, $authkeys);
while(<AUTH>) {
	s/\r|\n//g;
	s/#.*$//;
	local @l = split(/\s+/, $_);
	if (@l > 0) {
		$rv->{shift(@l)} = \@l;
		}
	}
close(AUTH);
return $rv;
}

sub save_auth_config
{
local %auth;
&open_tempfile(AUTH, ">$authkeys");
if ($_[0]->{'auth'}) {
	&print_tempfile(AUTH, "auth ",join(" ", @{$_[0]->{'auth'}}),"\n");
	map { $auth{$_}++ } @{$_[0]->{'auth'}};
	}
foreach $k (keys %{$_[0]}) {
	if ($k ne 'auth') {
		&print_tempfile(AUTH, "# ") if (!$auth{$k});
		&print_tempfile(AUTH, "$k ",join(" ", @{$_[0]->{$k}}),"\n");
		}
	}
&close_tempfile(AUTH);
}

# add two more functions (Christof Amelunxen, 22.08.2003)
sub check_status_resource {
	@ips = @_;
	$ifconfig="/sbin/ifconfig";
	@lines=qx|$ifconfig| or die("ifconfig does not seem to work: ".$!);
	foreach(@lines){
        if(/inet addr:([\d.]+)/){ 
		push(@realips,$1);
	}
	}
	$iplist = join (' ',@realips);
	foreach my $ip (@ips) {
		$ip =~ s/\/.*//;
		return 0 unless ( $iplist =~ m/$ip/);
	}		
	return 1;
}

sub get_resource {
	foreach(@_) {
		system("$config{req_resource_cmd} $_");
	}
}	

# version_atleast(v1, v2, v3)
sub version_atleast
{
local @vsp = split(/\./, $heartbeat_version);
local $i;
for($i=0; $i<@vsp || $i<@_; $i++) {
	return 0 if ($vsp[$i] < $_[$i]);
	return 1 if ($vsp[$i] > $_[$i]);
	}
return 1;	# same!
}

# apply_configuration()
# Apply the heartbeat configuration, and return undef on success or an error
# message on failure
sub apply_configuration
{
if ($config{'apply_cmd'}) {
	$out = &backquote_logged("$config{'apply_cmd'} 2>&1 </dev/null");
	if ($?) {
		return $out;
		}
	}
else {
	local $pid = &check_pid_file($config{'pid_file'});
	if ($pid) {
		kill(HUP, $pid);
		}
	else {
		return $text{'apply_epid'};
		}
	}
return undef;
}

1;

