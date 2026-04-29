#!/usr/local/bin/perl
# monitoring-lib.pl
# System monitoring and performance analysis library

use strict;
use warnings;

require '../web-lib.pl';
our (%text, %config, $module_name);

sub get_cpu_usage
{
my $cmd = "top -bn1 | grep 'Cpu(s)'";
my $out = &backquote_command($cmd);

if ($out =~ /Cpu\(s\):\s*([\d.]+)%us,\s*([\d.]+)%sy,\s*([\d.]+)%ni,\s*([\d.]+)%id,\s*([\d.]+)%wa,\s*([\d.]+)%hi,\s*([\d.]+)%si,\s*([\d.]+)%st/) {
    return {
        'user' => $1,
        'system' => $2,
        'nice' => $3,
        'idle' => $4,
        'iowait' => $5,
        'irq' => $6,
        'softirq' => $7,
        'steal' => $8,
        'total' => 100 - $4,
    };
}

return undef;
}

sub get_memory_usage
{
my $cmd = "free -m";
my $out = &backquote_command($cmd);

my ($total, $used, $free, $shared, $buffers, $cached);
foreach my $line (split(/\n/, $out)) {
    if ($line =~ /^Mem:\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
        $total = $1;
        $used = $2;
        $free = $3;
        $shared = $4;
        $buffers = $5;
        $cached = $6;
    }
}

return undef unless defined($total);

my $used_percent = sprintf("%.1f", ($used / $total) * 100);

return {
    'total' => $total,
    'used' => $used,
    'free' => $free,
    'shared' => $shared,
    'buffers' => $buffers,
    'cached' => $cached,
    'used_percent' => $used_percent,
    'available' => $free + $buffers + $cached,
};
}

sub get_disk_usage
{
my $cmd = "df -h";
my $out = &backquote_command($cmd);

my @disks;
foreach my $line (split(/\n/, $out)) {
    next if $line =~ /^Filesystem/;
    if ($line =~ /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)%\s+(\S+)/) {
        push(@disks, {
            'filesystem' => $1,
            'size' => $2,
            'used' => $3,
            'available' => $4,
            'used_percent' => $5,
            'mounted' => $6,
        });
    }
}

return @disks;
}

sub get_network_stats
{
my $cmd = "cat /proc/net/dev";
my $out = &backquote_command($cmd);

my @interfaces;
foreach my $line (split(/\n/, $out)) {
    next if $line =~ /^Inter|^ /;
    if ($line =~ /^\s*(\w+):\s*(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)/) {
        push(@interfaces, {
            'name' => $1,
            'rx_bytes' => $2,
            'tx_bytes' => $3,
            'rx_human' => &nice_size($2),
            'tx_human' => &nice_size($3),
        });
    }
}

return @interfaces;
}

sub get_load_average
{
my $cmd = "cat /proc/loadavg";
my $out = &backquote_command($cmd);

if ($out =~ /^(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+)\/(\d+)/) {
    return {
        'load1' => $1,
        'load5' => $2,
        'load15' => $3,
        'processes_running' => $4,
        'processes_total' => $5,
    };
}

return undef;
}

sub get_process_list
{
my $cmd = "ps aux --sort=-%mem";
my $out = &backquote_command($cmd);

my @processes;
my $header = 1;
foreach my $line (split(/\n/, $out)) {
    if ($header) {
        $header = 0;
        next;
    }
    if ($line =~ /^(\S+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)$/) {
        push(@processes, {
            'user' => $1,
            'pid' => $2,
            'cpu' => $3,
            'mem' => $4,
            'vsz' => &nice_size($5 * 1024),
            'rss' => &nice_size($6 * 1024),
            'tty' => $7,
            'stat' => $8,
            'start' => $9,
            'command' => $10,
        });
    }
}

return @processes;
}

sub get_process_count
{
my $cmd = "ps aux | wc -l";
my $out = &backquote_command($cmd);
chomp($out);
return $out - 1;
}

sub get_system_uptime
{
my $cmd = "uptime";
my $out = &backquote_command($cmd);

if ($out =~ /up\s+(.+?),\s+(\d+)\s+users?/) {
    return {
        'uptime' => $1,
        'users' => $2,
    };
}

return undef;
}

sub get_cpu_info
{
my $cmd = "cat /proc/cpuinfo";
my $out = &backquote_command($cmd);

my @cpus;
my %cpu;
foreach my $line (split(/\n/, $out)) {
    if ($line =~ /^processor\s*:\s*(\d+)/) {
        push(@cpus, \%cpu) if keys %cpu;
        %cpu = ();
    }
    elsif ($line =~ /^model name\s*:\s*(.+)/) {
        $cpu{'model'} = $1;
    }
    elsif ($line =~ /^cpu MHz\s*:\s*(\d+)/) {
        $cpu{'mhz'} = $1;
    }
    elsif ($line =~ /^cache size\s*:\s*(.+)/) {
        $cpu{'cache'} = $1;
    }
}
push(@cpus, \%cpu) if keys %cpu;

return @cpus;
}

sub get_system_info
{
my $distro = &backquote_command('lsb_release -d 2>/dev/null | cut -f2');
chomp($distro);
$distro ||= &backquote_command('cat /etc/issue 2>/dev/null | head -1');
chomp($distro);

my $kernel = &backquote_command('uname -r');
chomp($kernel);

my $hostname = &backquote_command('hostname');
chomp($hostname);

my $arch = &backquote_command('uname -m');
chomp($arch);

my @cpus = &get_cpu_info();

return {
    'distro' => $distro,
    'kernel' => $kernel,
    'hostname' => $hostname,
    'arch' => $arch,
    'cpu_count' => scalar(@cpus),
    'cpu_model' => $cpus[0]->{'model'} || '-',
};
}

sub get_recent_logs
{
my ($lines) = @_;
$lines ||= 50;

my $cmd = "tail -n $lines /var/log/syslog 2>/dev/null || tail -n $lines /var/log/messages 2>/dev/null || tail -n $lines /var/log/auth.log 2>/dev/null";
my $out = &backquote_command($cmd);

my @logs;
foreach my $line (split(/\n/, $out)) {
    push(@logs, $line);
}

return @logs;
}

sub get_service_status
{
my ($service) = @_;
my $cmd = "systemctl is-active $service 2>/dev/null || service $service status 2>/dev/null | grep -q running && echo running || echo stopped";
my $out = &backquote_command($cmd);
chomp($out);
return $out;
}

sub list_services
{
my @services = qw(ssh docker nginx apache2 mysql postgresql redis);
my @statuses;

foreach my $service (@services) {
    push(@statuses, {
        'name' => $service,
        'status' => &get_service_status($service),
    });
}

return @statuses;
}

sub nice_size
{
my ($bytes) = @_;
return "0 B" if ($bytes == 0);
my @units = ('B', 'KB', 'MB', 'GB', 'TB');
my $unit = 0;
while ($bytes >= 1024 && $unit < $#units) {
    $bytes /= 1024;
    $unit++;
}
return sprintf("%.1f %s", $bytes, $units[$unit]);
}

sub get_performance_history
{
my $history_file = $config{'history_file'} || '/var/webmin/monitoring/history.csv';
my @history;

return @history unless -f $history_file;

open(FILE, $history_file) || return @history;
while (<FILE>) {
    chomp;
    my ($time, $cpu, $mem, $disk) = split(/,/);
    push(@history, {
        'time' => $time,
        'cpu' => $cpu,
        'mem' => $mem,
        'disk' => $disk,
    });
}
close(FILE);

return @history;
}

sub save_performance_data
{
my $history_file = $config{'history_file'} || '/var/webmin/monitoring/history.csv';

my $cpu = &get_cpu_usage();
my $mem = &get_memory_usage();
my @disks = &get_disk_usage();

my $disk_usage = 0;
$disk_usage = $disks[0]->{'used_percent'} if @disks;

my $line = join(',', time(), $cpu->{'total'} || 0, $mem->{'used_percent'} || 0, $disk_usage)."\n";

open(FILE, ">>$history_file") || return;
print FILE $line;
close(FILE);

&trim_history();
}

sub trim_history
{
my $history_file = $config{'history_file'} || '/var/webmin/monitoring/history.csv';
my $max_lines = $config{'history_lines'} || 1000;

my @lines;
open(FILE, $history_file) || return;
@lines = <FILE>;
close(FILE);

if (@lines > $max_lines) {
    @lines = splice(@lines, -$max_lines);
    open(FILE, ">$history_file") || return;
    print FILE @lines;
    close(FILE);
}
}

1;