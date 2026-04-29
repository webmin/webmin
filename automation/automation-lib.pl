#!/usr/local/bin/perl
# automation-lib.pl
# Automation and configuration management library

use strict;
use warnings;

require '../web-lib.pl';
our (%text, %config, $module_name);

sub get_scripts_dir
{
return $config{'scripts_dir'} || '/var/webmin/automation/scripts';
}

sub get_configs_dir
{
return $config{'configs_dir'} || '/var/webmin/automation/configs';
}

sub get_deployments_dir
{
return $config{'deployments_dir'} || '/var/webmin/automation/deployments';
}

sub ensure_directories
{
my $scripts_dir = &get_scripts_dir();
my $configs_dir = &get_configs_dir();
my $deployments_dir = &get_deployments_dir();

mkdir($scripts_dir, 0755) unless -d $scripts_dir;
mkdir($configs_dir, 0755) unless -d $configs_dir;
mkdir($deployments_dir, 0755) unless -d $deployments_dir;
}

sub list_scripts
{
&ensure_directories();
my $dir = &get_scripts_dir();
my @scripts;

opendir(DIR, $dir) || return ();
foreach my $file (sort readdir(DIR)) {
    next if ($file =~ /^\./);
    my $path = "$dir/$file";
    next unless -f $path;
    
    my ($size, $mtime) = (stat($path))[7, 9];
    push(@scripts, {
        'name' => $file,
        'path' => $path,
        'size' => &nice_size($size),
        'mtime' => scalar(localtime($mtime)),
        'executable' => -x $path ? 1 : 0,
    });
}
closedir(DIR);

return @scripts;
}

sub get_script_content
{
my ($name) = @_;
my $path = &get_scripts_dir()."/$name";
return undef unless -f $path;

open(FILE, $path) || return undef;
local $/;
my $content = <FILE>;
close(FILE);

return $content;
}

sub save_script
{
my ($name, $content) = @_;
&ensure_directories();
my $path = &get_scripts_dir()."/$name";

open(FILE, ">$path") || return (0, "Cannot write to $path");
print FILE $content;
close(FILE);

chmod(0755, $path);

return (1, "Script saved");
}

sub delete_script
{
my ($name) = @_;
my $path = &get_scripts_dir()."/$name";
return (0, "File not found") unless -f $path;

unlink($path) || return (0, "Cannot delete $path");
return (1, "Script deleted");
}

sub run_script
{
my ($name, $args) = @_;
my $path = &get_scripts_dir()."/$name";
return (undef, "Script not found") unless -f $path;
return (undef, "Script not executable") unless -x $path;

my $cmd = $path;
$cmd .= " $args" if ($args);

my $out = &backquote_command($cmd);
my $exit = $?;

return ($out, $exit == 0 ? undef : "Script failed with exit code $exit");
}

sub list_configs
{
&ensure_directories();
my $dir = &get_configs_dir();
my @configs;

opendir(DIR, $dir) || return ();
foreach my $file (sort readdir(DIR)) {
    next if ($file =~ /^\./);
    my $path = "$dir/$file";
    next unless -f $path;
    
    my ($size, $mtime) = (stat($path))[7, 9];
    push(@configs, {
        'name' => $file,
        'path' => $path,
        'size' => &nice_size($size),
        'mtime' => scalar(localtime($mtime)),
    });
}
closedir(DIR);

return @configs;
}

sub get_config_content
{
my ($name) = @_;
my $path = &get_configs_dir()."/$name";
return undef unless -f $path;

open(FILE, $path) || return undef;
local $/;
my $content = <FILE>;
close(FILE);

return $content;
}

sub save_config
{
my ($name, $content) = @_;
&ensure_directories();
my $path = &get_configs_dir()."/$name";

open(FILE, ">$path") || return (0, "Cannot write to $path");
print FILE $content;
close(FILE);

return (1, "Config saved");
}

sub delete_config
{
my ($name) = @_;
my $path = &get_configs_dir()."/$name";
return (0, "File not found") unless -f $path;

unlink($path) || return (0, "Cannot delete $path");
return (1, "Config deleted");
}

sub list_deployments
{
&ensure_directories();
my $dir = &get_deployments_dir();
my @deployments;

opendir(DIR, $dir) || return ();
foreach my $file (sort readdir(DIR)) {
    next if ($file =~ /^\./);
    my $path = "$dir/$file";
    next unless -f $path;
    
    my ($size, $mtime) = (stat($path))[7, 9];
    
    my $config = &read_deployment_config($path);
    
    push(@deployments, {
        'name' => $file,
        'path' => $path,
        'size' => &nice_size($size),
        'mtime' => scalar(localtime($mtime)),
        'app' => $config->{'app'} || '-',
        'env' => $config->{'env'} || '-',
        'status' => $config->{'status'} || 'pending',
    });
}
closedir(DIR);

return @deployments;
}

sub read_deployment_config
{
my ($path) = @_;
my %config;

open(FILE, $path) || return {};
while (<FILE>) {
    chomp;
    next if (/^#/ || /^\s*$/);
    if (/^(\w+)\s*=\s*(.+)$/) {
        $config{$1} = $2;
    }
}
close(FILE);

return \%config;
}

sub get_deployment_content
{
my ($name) = @_;
my $path = &get_deployments_dir()."/$name";
return undef unless -f $path;

open(FILE, $path) || return undef;
local $/;
my $content = <FILE>;
close(FILE);

return $content;
}

sub save_deployment
{
my ($name, $content) = @_;
&ensure_directories();
my $path = &get_deployments_dir()."/$name";

open(FILE, ">$path") || return (0, "Cannot write to $path");
print FILE $content;
close(FILE);

return (1, "Deployment config saved");
}

sub delete_deployment
{
my ($name) = @_;
my $path = &get_deployments_dir()."/$name";
return (0, "File not found") unless -f $path;

unlink($path) || return (0, "Cannot delete $path");
return (1, "Deployment deleted");
}

sub execute_deployment
{
my ($name) = @_;
my $path = &get_deployments_dir()."/$name";
return (undef, "Deployment config not found") unless -f $path;

my $config = &read_deployment_config($path);
my $script = $config->{'script'};
return (undef, "No script specified in deployment") unless $script;

my $script_path = &get_scripts_dir()."/$script";
return (undef, "Script $script not found") unless -f $script_path;
return (undef, "Script not executable") unless -x $script_path;

my $cmd = $script_path;
$cmd .= " ".($config->{'args'} || "");

my $out = &backquote_command($cmd);
my $exit = $?;

if ($exit == 0) {
    $config->{'status'} = 'success';
    $config->{'last_run'} = scalar(localtime());
    &save_deployment($name, &config_to_string($config));
}
else {
    $config->{'status'} = 'failed';
    $config->{'last_run'} = scalar(localtime());
    &save_deployment($name, &config_to_string($config));
}

return ($out, $exit == 0 ? undef : "Deployment failed with exit code $exit");
}

sub config_to_string
{
my ($config) = @_;
my @lines;
foreach my $key (sort keys %$config) {
    push(@lines, "$key=$config->{$key}");
}
return join("\n", @lines)."\n";
}

sub list_cron_jobs
{
my @jobs;
my $cmd = 'crontab -l 2>/dev/null';
my $out = &backquote_command($cmd);

my $line_num = 0;
foreach my $line (split(/\n/, $out)) {
    $line_num++;
    next if $line =~ /^\s*#/ || $line =~ /^\s*$/;
    
    my ($minute, $hour, $day, $month, $dow, $command) = split(/\s+/, $line, 6);
    push(@jobs, {
        'line' => $line_num,
        'minute' => $minute,
        'hour' => $hour,
        'day' => $day,
        'month' => $month,
        'dow' => $dow,
        'command' => $command,
        'full' => $line,
    });
}

return @jobs;
}

sub add_cron_job
{
my ($minute, $hour, $day, $month, $dow, $command) = @_;

my $job = "$minute $hour $day $month $dow $command\n";
my $tmpfile = &transname();

my $current = &backquote_command('crontab -l 2>/dev/null');
open(FILE, ">$tmpfile") || return (0, "Cannot create temp file");
print FILE $current if $current;
print FILE $job;
close(FILE);

my $cmd = "crontab $tmpfile";
my $out = &backquote_command($cmd);
my $exit = $?;

unlink($tmpfile);

return ($exit == 0, $exit == 0 ? "Job added" : "Failed to add job: $out");
}

sub delete_cron_job
{
my ($line_num) = @_;

my $current = &backquote_command('crontab -l 2>/dev/null');
my @lines = split(/\n/, $current);

splice(@lines, $line_num - 1, 1);

my $tmpfile = &transname();
open(FILE, ">$tmpfile") || return (0, "Cannot create temp file");
print FILE join("\n", @lines)."\n";
close(FILE);

my $cmd = "crontab $tmpfile";
my $out = &backquote_command($cmd);
my $exit = $?;

unlink($tmpfile);

return ($exit == 0, $exit == 0 ? "Job deleted" : "Failed to delete job: $out");
}

sub nice_size
{
my ($bytes) = @_;
return "0 B" if ($bytes == 0);
my @units = ('B', 'KB', 'MB', 'GB');
my $unit = 0;
while ($bytes >= 1024 && $unit < $#units) {
    $bytes /= 1024;
    $unit++;
}
return sprintf("%.1f %s", $bytes, $units[$unit]);
}

1;