#!/usr/local/bin/perl
# index.cgi
# System monitoring main page

use strict;
use warnings;

require './monitoring-lib.pl';
&ReadParse();
our (%text, %config, %module_info, %access, $module_name);

&ui_print_header(undef, $module_info{'desc'}, "", undef, 1, 1);

my $system_info = &get_system_info();
my $uptime = &get_system_uptime();
my $load = &get_load_average();
my $cpu = &get_cpu_usage();
my $mem = &get_memory_usage();
my @disks = &get_disk_usage();
my @network = &get_network_stats();
my @services = &list_services();

print &ui_alert_box(&text('index_sysinfo',
    $system_info->{'hostname'},
    $system_info->{'distro'},
    $system_info->{'kernel'},
    $system_info->{'cpu_count'}.' x '.$system_info->{'cpu_model'}), 'info');

print &ui_table_start($text{'index_overview'}, "width=100%", 2);

print &ui_table_row($text{'index_uptime'}, $uptime->{'uptime'}.' ('.$text{'index_users'}.': '.$uptime->{'users'}.')');
print &ui_table_row($text{'index_load'}, $load->{'load1'}.' / '.$load->{'load5'}.' / '.$load->{'load15'});

print &ui_table_row($text{'index_cpu'},
    &ui_progress_bar($cpu->{'total'}, 100, 200, $cpu->{'total'}.'%'));
print &ui_table_row($text{'index_cpu_breakdown'},
    $text{'index_cpu_user'}.': '.$cpu->{'user'}.'% | '.
    $text{'index_cpu_system'}.': '.$cpu->{'system'}.'% | '.
    $text{'index_cpu_idle'}.': '.$cpu->{'idle'}.'%');

print &ui_table_row($text{'index_memory'},
    &ui_progress_bar($mem->{'used_percent'}, 100, 200, $mem->{'used'}.'/'.$mem->{'total'}.' MB'));
print &ui_table_row($text{'index_memory_details'},
    $text{'index_mem_free'}.': '.$mem->{'free'}.' MB | '.
    $text{'index_mem_buffers'}.': '.$mem->{'buffers'}.' MB | '.
    $text{'index_mem_cached'}.': '.$mem->{'cached'}.' MB');

print &ui_table_end();

print &ui_tabs_start([
    [ "disks", $text{'index_tabdisks'}, "index.cgi?mode=disks" ],
    [ "network", $text{'index_tabnetwork'}, "index.cgi?mode=network" ],
    [ "services", $text{'index_tabservices'}, "index.cgi?mode=services" ],
    [ "processes", $text{'index_tabprocesses'}, "index.cgi?mode=processes" ],
    [ "logs", $text{'index_tablogs'}, "index.cgi?mode=logs" ],
], "mode", $in{'mode'} || "disks", 1);

print &ui_tabs_start_tab("mode", "disks");
&show_disks_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "network");
&show_network_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "services");
&show_services_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "processes");
&show_processes_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "logs");
&show_logs_tab();
print &ui_tabs_end_tab();

print &ui_tabs_end(1);

&ui_print_footer("/", $text{'index'});

sub show_disks_tab
{
my @disks = &get_disk_usage();

if (@disks) {
    my @heads = (
        $text{'index_fs'},
        $text{'index_size'},
        $text{'index_used'},
        $text{'index_available'},
        $text{'index_usage'},
        $text{'index_mounted'},
    );

    my @data;
    foreach my $d (@disks) {
        push(@data, [
            $d->{'filesystem'},
            $d->{'size'},
            $d->{'used'},
            $d->{'available'},
            &ui_progress_bar($d->{'used_percent'}, 100, 200, $d->{'used_percent'}.'%'),
            $d->{'mounted'},
        ]);
    }

    print &ui_columns_table(\@heads, 100, \@data);
}
else {
    print "<b>$text{'index_nodisks'}</b><p>\n";
}
}

sub show_network_tab
{
my @interfaces = &get_network_stats();

if (@interfaces) {
    my @heads = (
        $text{'index_interface'},
        $text{'index_rx'},
        $text{'index_tx'},
    );

    my @data;
    foreach my $i (@interfaces) {
        push(@data, [
            $i->{'name'},
            $i->{'rx_human'},
            $i->{'tx_human'},
        ]);
    }

    print &ui_columns_table(\@heads, 100, \@data);
}
else {
    print "<b>$text{'index_nonetwork'}</b><p>\n";
}
}

sub show_services_tab
{
my @services = &list_services();

if (@services) {
    my @heads = (
        $text{'index_service'},
        $text{'index_status'},
    );

    my @data;
    foreach my $s (@services) {
        my $status_color = $s->{'status'} eq 'active' || $s->{'status'} eq 'running' ? 'green' : 'red';
        push(@data, [
            $s->{'name'},
            "<span style='color: $status_color'>".ucfirst($s->{'status'})."</span>",
        ]);
    }

    print &ui_columns_table(\@heads, 100, \@data);
}
else {
    print "<b>$text{'index_noservices'}</b><p>\n";
}
}

sub show_processes_tab
{
my @processes = &get_process_list();
my $count = &get_process_count();

print "<p>$text{'index_totalprocesses'}: $count</p>\n";

if (@processes) {
    print &ui_form_start("process_action.cgi", "post");

    my @heads = (
        { 'type' => 'checkbox', 'name' => 'd', 'values' => [ map { $_->{'pid'} } @processes ] },
        $text{'index_pid'},
        $text{'index_user'},
        $text{'index_cpu'},
        $text{'index_mem'},
        $text{'index_vsz'},
        $text{'index_rss'},
        $text{'index_command'},
    );

    my @data;
    foreach my $p (@processes[0..19]) {
        push(@data, [
            { 'type' => 'checkbox', 'name' => 'd', 'value' => $p->{'pid'} },
            $p->{'pid'},
            $p->{'user'},
            $p->{'cpu'}.'%',
            $p->{'mem'}.'%',
            $p->{'vsz'},
            $p->{'rss'},
            $p->{'command'},
        ]);
    }

    print &ui_columns_table(\@heads, 100, \@data);

    my @actions = (
        [ 'kill', $text{'action_kill'} ],
        [ 'kill9', $text{'action_kill9'} ],
    );
    print &ui_form_end(\@actions);
}
else {
    print "<b>$text{'index_noprocesses'}</b><p>\n";
}
}

sub show_logs_tab
{
my @logs = &get_recent_logs();

if (@logs) {
    print &ui_table_start($text{'index_recentlogs'}, "width=100%", 2);
    foreach my $log (@logs) {
        print &ui_table_row(undef, "<pre>".&html_escape($log)."</pre>");
    }
    print &ui_table_end();
}
else {
    print "<b>$text{'index_nologs'}</b><p>\n";
}
}