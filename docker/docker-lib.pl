#!/usr/local/bin/perl
# docker-lib.pl
# Docker management library

use strict;
use warnings;

require '../web-lib.pl';
our (%text, %config, $module_name);

sub get_docker_cmd
{
return $config{'docker_cmd'} || '/usr/bin/docker';
}

sub get_docker_compose_cmd
{
return $config{'docker_compose_cmd'} || '/usr/bin/docker-compose';
}

sub list_containers
{
my ($all) = @_;
$all = $config{'show_all'} unless defined($all);

my @containers;
my $cmd = &get_docker_cmd()." ps --format '{{.ID}}|{{.Image}}|{{.Command}}|{{.CreatedAt}}|{{.Status}}|{{.Names}}|{{.Ports}}'";
$cmd .= " -a" if ($all);

my $out = &backquote_command($cmd);
foreach my $line (split(/\n/, $out)) {
    next if (!$line);
    my ($id, $image, $command, $created, $status, $names, $ports) = split(/\|/, $line);
    push(@containers, {
        'id' => $id,
        'image' => $image,
        'command' => $command,
        'created' => $created,
        'status' => $status,
        'names' => $names,
        'ports' => $ports,
        'running' => ($status =~ /^Up/i) ? 1 : 0
    });
}

return @containers;
}

sub list_images
{
my @images;
my $cmd = &get_docker_cmd()." images --format '{{.ID}}|{{.Repository}}|{{.Tag}}|{{.CreatedAt}}|{{.Size}}'";

my $out = &backquote_command($cmd);
foreach my $line (split(/\n/, $out)) {
    next if (!$line);
    my ($id, $repo, $tag, $created, $size) = split(/\|/, $line);
    push(@images, {
        'id' => $id,
        'repository' => $repo,
        'tag' => $tag,
        'created' => $created,
        'size' => $size
    });
}

return @images;
}

sub list_networks
{
my @networks;
my $cmd = &get_docker_cmd()." network ls --format '{{.ID}}|{{.Name}}|{{.Driver}}|{{.Scope}}'";

my $out = &backquote_command($cmd);
foreach my $line (split(/\n/, $out)) {
    next if (!$line);
    my ($id, $name, $driver, $scope) = split(/\|/, $line);
    push(@networks, {
        'id' => $id,
        'name' => $name,
        'driver' => $driver,
        'scope' => $scope
    });
}

return @networks;
}

sub list_volumes
{
my @volumes;
my $cmd = &get_docker_cmd()." volume ls --format '{{.Name}}|{{.Driver}}'";

my $out = &backquote_command($cmd);
foreach my $line (split(/\n/, $out)) {
    next if (!$line);
    my ($name, $driver) = split(/\|/, $line);
    push(@volumes, {
        'name' => $name,
        'driver' => $driver
    });
}

return @volumes;
}

sub container_action
{
my ($id, $action) = @_;
my $cmd;

if ($action eq 'start') {
    $cmd = &get_docker_cmd()." start $id";
}
elsif ($action eq 'stop') {
    $cmd = &get_docker_cmd()." stop $id";
}
elsif ($action eq 'restart') {
    $cmd = &get_docker_cmd()." restart $id";
}
elsif ($action eq 'pause') {
    $cmd = &get_docker_cmd()." pause $id";
}
elsif ($action eq 'unpause') {
    $cmd = &get_docker_cmd()." unpause $id";
}
elsif ($action eq 'kill') {
    $cmd = &get_docker_cmd()." kill $id";
}
elsif ($action eq 'rm') {
    $cmd = &get_docker_cmd()." rm $id";
}
else {
    return (0, "Unknown action: $action");
}

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub pull_image
{
my ($image, $tag) = @_;
$tag ||= 'latest';
my $cmd = &get_docker_cmd()." pull $image:$tag";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub build_image
{
my ($path, $tag, $dockerfile) = @_;
$dockerfile ||= 'Dockerfile';
my $cmd = &get_docker_cmd()." build -t $tag -f $path/$dockerfile $path";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub remove_image
{
my ($id) = @_;
my $cmd = &get_docker_cmd()." rmi $id";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub get_container_details
{
my ($id) = @_;
my $cmd = &get_docker_cmd()." inspect $id --format '{{json .}}'";

my $out = &backquote_command($cmd);
my $exit = $?;

return (undef, "Failed to inspect container") if ($exit != 0);

eval "use JSON::PP";
if (!$@) {
    my $json = JSON::PP->new;
    eval {
        return ($json->decode($out), undef);
    };
}

return (undef, "JSON parsing failed: $@");
}

sub get_container_logs
{
my ($id, $lines) = @_;
$lines ||= $config{'max_log_lines'} || 1000;
my $cmd = &get_docker_cmd()." logs --tail $lines $id 2>&1";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($out, $exit == 0 ? undef : "Failed to get logs");
}

sub create_network
{
my ($name, $driver, $subnet) = @_;
$driver ||= 'bridge';
my $cmd = &get_docker_cmd()." network create";
$cmd .= " --driver $driver" if ($driver);
$cmd .= " --subnet $subnet" if ($subnet);
$cmd .= " $name";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub remove_network
{
my ($id) = @_;
my $cmd = &get_docker_cmd()." network rm $id";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub create_volume
{
my ($name, $driver) = @_;
$driver ||= 'local';
my $cmd = &get_docker_cmd()." volume create";
$cmd .= " --driver $driver" if ($driver);
$cmd .= " $name";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub remove_volume
{
my ($name) = @_;
my $cmd = &get_docker_cmd()." volume rm $name";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub run_container
{
my ($image, $name, $ports, $volumes, $env, $command, $detach) = @_;
$detach = 1 unless defined($detach);

my $cmd = &get_docker_cmd()." run";
$cmd .= " -d" if ($detach);
$cmd .= " --name $name" if ($name);

if ($ports && ref($ports) eq 'ARRAY') {
    foreach my $p (@$ports) {
        $cmd .= " -p $p";
    }
}

if ($volumes && ref($volumes) eq 'ARRAY') {
    foreach my $v (@$volumes) {
        $cmd .= " -v $v";
    }
}

if ($env && ref($env) eq 'ARRAY') {
    foreach my $e (@$env) {
        $cmd .= " -e $e";
    }
}

$cmd .= " $image";
$cmd .= " $command" if ($command);

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub docker_version
{
my $cmd = &get_docker_cmd()." version --format '{{.Server.Version}}'";
my $out = &backquote_command($cmd);
chomp($out);
return $out;
}

sub docker_info
{
my $cmd = &get_docker_cmd()." info";
my $out = &backquote_command($cmd);
return $out;
}

sub get_container_stats
{
my ($id) = @_;
my $cmd = &get_docker_cmd()." stats $id --no-stream --format '{{json .}}'";

my $out = &backquote_command($cmd);
my $exit = $?;

return (undef, "Failed to get stats") if ($exit != 0);

eval "use JSON::PP";
if (!$@) {
    my $json = JSON::PP->new;
    eval {
        return ($json->decode($out), undef);
    };
}

return (undef, "JSON parsing failed: $@");
}

sub docker_compose_up
{
my ($path, $detached) = @_;
$detached = 1 unless defined($detached);
my $cmd = &get_docker_compose_cmd()." -f $path up";
$cmd .= " -d" if ($detached);

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub docker_compose_down
{
my ($path) = @_;
my $cmd = &get_docker_compose_cmd()." -f $path down";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub docker_compose_ps
{
my ($path) = @_;
my @containers;
my $cmd = &get_docker_compose_cmd()." -f $path ps --format '{{.Name}}|{{.Command}}|{{.State}}|{{.Ports}}'";

my $out = &backquote_command($cmd);
foreach my $line (split(/\n/, $out)) {
    next if (!$line);
    my ($name, $command, $state, $ports) = split(/\|/, $line);
    push(@containers, {
        'name' => $name,
        'command' => $command,
        'state' => $state,
        'ports' => $ports,
        'running' => ($state =~ /Up/i) ? 1 : 0
    });
}

return @containers;
}

sub docker_compose_build
{
my ($path, $service) = @_;
my $cmd = &get_docker_compose_cmd()." -f $path build";
$cmd .= " $service" if ($service);

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub docker_compose_logs
{
my ($path, $service, $lines) = @_;
$lines ||= 100;
my $cmd = &get_docker_compose_cmd()." -f $path logs --tail $lines";
$cmd .= " $service" if ($service);

my $out = &backquote_command($cmd);
my $exit = $?;

return ($out, $exit == 0 ? undef : "Failed to get logs");
}

sub docker_compose_version
{
my $cmd = &get_docker_compose_cmd()." version --short";
my $out = &backquote_command($cmd);
chomp($out);
return $out;
}

sub tag_image
{
my ($source, $target) = @_;
my $cmd = &get_docker_cmd()." tag $source $target";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub push_image
{
my ($image) = @_;
my $cmd = &get_docker_cmd()." push $image";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub export_container
{
my ($id, $path) = @_;
my $cmd = &get_docker_cmd()." export -o $path $id";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub import_image
{
my ($path, $tag) = @_;
my $cmd = "cat $path | ".&get_docker_cmd()." import - $tag";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub prune_images
{
my $cmd = &get_docker_cmd()." image prune -f";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub prune_containers
{
my $cmd = &get_docker_cmd()." container prune -f";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub prune_volumes
{
my $cmd = &get_docker_cmd()." volume prune -f";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

sub prune_networks
{
my $cmd = &get_docker_cmd()." network prune -f";

my $out = &backquote_command($cmd);
my $exit = $?;

return ($exit == 0, $out);
}

1;
