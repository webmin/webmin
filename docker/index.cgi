#!/usr/local/bin/perl
# index.cgi
# Docker management main page

use strict;
use warnings;

require './docker-lib.pl';
&ReadParse();
our (%text, %in, %config, %module_info, %access, $module_name);

&ui_print_header(undef, $module_info{'desc'}, "", undef, 1, 1);

if (!&has_command(&get_docker_cmd())) {
    &ui_print_endpage(
        &text('index_ecmd', "<tt>".&get_docker_cmd()."</tt>",
        "../config.cgi?$module_name"));
}

my $docker_version = &docker_version();
if ($docker_version) {
    print &ui_alert_box(&text('index_version', $docker_version), 'info');
}

my @tabs = (
    [ "containers", $text{'index_tabcontainers'}, "index.cgi?mode=containers" ],
    [ "images", $text{'index_tabimages'}, "index.cgi?mode=images" ],
    [ "networks", $text{'index_tabnetworks'}, "index.cgi?mode=networks" ],
    [ "volumes", $text{'index_tabvolumes'}, "index.cgi?mode=volumes" ],
    [ "compose", $text{'index_tabcompose'}, "index.cgi?mode=compose" ],
    [ "info", $text{'index_tabinfo'}, "index.cgi?mode=info" ],
);

my $mode = $in{'mode'} || "containers";
my %tab = map { $_->[0], 1 } @tabs;
$mode = "containers" if (!$tab{$mode});

print &ui_tabs_start(\@tabs, "mode", $mode, 1);

print &ui_tabs_start_tab("mode", "containers");
&show_containers_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "images");
&show_images_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "networks");
&show_networks_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "volumes");
&show_volumes_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "compose");
&show_compose_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "info");
&show_info_tab();
print &ui_tabs_end_tab();

print &ui_tabs_end(1);

&ui_print_footer("/", $text{'index'});

sub show_containers_tab
{
my @containers = &list_containers();

if (@containers) {
    print &ui_form_start("container_action.cgi", "post");
    
    my @heads = (
        { 'type' => 'checkbox', 'name' => 'd', 'values' => [ map { $_->{'id'} } @containers ] },
        $text{'index_name'},
        $text{'index_image'},
        $text{'index_status'},
        $text{'index_ports'},
        $text{'index_created'},
        $text{'index_actions'},
    );
    
    my @data;
    foreach my $c (@containers) {
        my $status_color = $c->{'running'} ? 'green' : 'red';
        push(@data, [
            { 'type' => 'checkbox', 'name' => 'd', 'value' => $c->{'id'} },
            &ui_link("view_container.cgi?id=".$c->{'id'}, $c->{'names'}),
            $c->{'image'},
            "<span style='color: $status_color'>".$c->{'status'}."</span>",
            $c->{'ports'} || '-',
            $c->{'created'},
            &ui_links_row([
                $c->{'running'} ? 
                    &ui_link("container_action.cgi?action=stop&id=".$c->{'id'}, $text{'action_stop'}) :
                    &ui_link("container_action.cgi?action=start&id=".$c->{'id'}, $text{'action_start'}),
                $c->{'running'} ? 
                    &ui_link("container_action.cgi?action=restart&id=".$c->{'id'}, $text{'action_restart'}) : (),
                &ui_link("container_action.cgi?action=logs&id=".$c->{'id'}, $text{'action_logs'}),
                &ui_link("edit_container.cgi?id=".$c->{'id'}, $text{'action_edit'}),
            ]),
        ]);
    }
    
    print &ui_columns_table(\@heads, 100, \@data);
    
    my @actions = (
        [ 'start', $text{'action_start'} ],
        [ 'stop', $text{'action_stop'} ],
        [ 'restart', $text{'action_restart'} ],
        [ 'kill', $text{'action_kill'} ],
        [ 'rm', $text{'action_remove'} ],
    );
    print &ui_form_end(\@actions);
}
else {
    print "<b>$text{'index_nocontainers'}</b><p>\n";
}

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("run_container.cgi",
    $text{'index_runcontainer'},
    $text{'index_runcontainerdesc'});
print &ui_buttons_end();
}

sub show_images_tab
{
my @images = &list_images();

if (@images) {
    print &ui_form_start("image_action.cgi", "post");
    
    my @heads = (
        { 'type' => 'checkbox', 'name' => 'd', 'values' => [ map { $_->{'id'} } @images ] },
        $text{'index_repository'},
        $text{'index_tag'},
        $text{'index_imageid'},
        $text{'index_created'},
        $text{'index_size'},
    );
    
    my @data;
    foreach my $i (@images) {
        push(@data, [
            { 'type' => 'checkbox', 'name' => 'd', 'value' => $i->{'id'} },
            $i->{'repository'},
            $i->{'tag'},
            substr($i->{'id'}, 0, 12),
            $i->{'created'},
            $i->{'size'},
        ]);
    }
    
    print &ui_columns_table(\@heads, 100, \@data);
    
    my @actions = (
        [ 'rmi', $text{'action_remove'} ],
    );
    print &ui_form_end(\@actions);
}
else {
    print "<b>$text{'index_noimages'}</b><p>\n";
}

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("pull_image.cgi",
    $text{'index_pullimage'},
    $text{'index_pullimagedesc'});
print &ui_buttons_row("build_image.cgi",
    $text{'index_buildimage'},
    $text{'index_buildimagedesc'});
print &ui_buttons_end();
}

sub show_networks_tab
{
my @networks = &list_networks();

if (@networks) {
    print &ui_form_start("network_action.cgi", "post");
    
    my @heads = (
        { 'type' => 'checkbox', 'name' => 'd', 'values' => [ map { $_->{'id'} } @networks ] },
        $text{'index_name'},
        $text{'index_driver'},
        $text{'index_scope'},
    );
    
    my @data;
    foreach my $n (@networks) {
        push(@data, [
            { 'type' => 'checkbox', 'name' => 'd', 'value' => $n->{'id'} },
            $n->{'name'},
            $n->{'driver'},
            $n->{'scope'},
        ]);
    }
    
    print &ui_columns_table(\@heads, 100, \@data);
    
    my @actions = (
        [ 'rm', $text{'action_remove'} ],
    );
    print &ui_form_end(\@actions);
}
else {
    print "<b>$text{'index_nonetworks'}</b><p>\n";
}

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("create_network.cgi",
    $text{'index_createnetwork'},
    $text{'index_createnetworkdesc'});
print &ui_buttons_end();
}

sub show_volumes_tab
{
my @volumes = &list_volumes();

if (@volumes) {
    print &ui_form_start("volume_action.cgi", "post");
    
    my @heads = (
        { 'type' => 'checkbox', 'name' => 'd', 'values' => [ map { $_->{'name'} } @volumes ] },
        $text{'index_name'},
        $text{'index_driver'},
    );
    
    my @data;
    foreach my $v (@volumes) {
        push(@data, [
            { 'type' => 'checkbox', 'name' => 'd', 'value' => $v->{'name'} },
            $v->{'name'},
            $v->{'driver'},
        ]);
    }
    
    print &ui_columns_table(\@heads, 100, \@data);
    
    my @actions = (
        [ 'rm', $text{'action_remove'} ],
    );
    print &ui_form_end(\@actions);
}
else {
    print "<b>$text{'index_novolumes'}</b><p>\n";
}

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("create_volume.cgi",
    $text{'index_createvolume'},
    $text{'index_createvolumedesc'});
print &ui_buttons_end();
}

sub show_compose_tab
{
my $compose_version = &docker_compose_version();
if ($compose_version) {
    print &ui_alert_box(&text('index_composeversion', $compose_version), 'info');
}

print &ui_form_start("compose_action.cgi", "post");

print &ui_table_start($text{'compose_title'}, "width=100%", 2);
print &ui_table_row($text{'compose_path'},
    &ui_textbox("compose_file", $in{'compose_file'} || '/path/to/docker-compose.yml', 60));
print &ui_table_end();

print &ui_hr();

my @actions = (
    [ 'up', $text{'compose_up'} ],
    [ 'down', $text{'compose_down'} ],
    [ 'build', $text{'compose_build'} ],
    [ 'logs', $text{'compose_logs'} ],
);
print &ui_form_end(\@actions);

if ($in{'compose_file'}) {
    my @containers = &docker_compose_ps($in{'compose_file'});
    if (@containers) {
        print "<p><b>".$text{'index_containers'}."</b></p>\n";
        
        my @heads = (
            $text{'index_name'},
            $text{'index_command'},
            $text{'index_status'},
            $text{'index_ports'},
        );
        
        my @data;
        foreach my $c (@containers) {
            my $status_color = $c->{'running'} ? 'green' : 'red';
            push(@data, [
                $c->{'name'},
                $c->{'command'},
                "<span style='color: $status_color'>".$c->{'state'}."</span>",
                $c->{'ports'} || '-',
            ]);
        }
        
        print &ui_columns_table(\@heads, 100, \@data);
    }
}
}

sub show_info_tab
{
my $info = &docker_info();

print &ui_table_start($text{'index_dockerinfo'}, "width=100%", 2);
print &ui_table_row(undef, "<pre>".&html_escape($info)."</pre>");
print &ui_table_end();
}
