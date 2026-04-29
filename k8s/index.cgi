#!/usr/local/bin/perl
# index.cgi
# Kubernetes management main page

use strict;
use warnings;

require './k8s-lib.pl';
&ReadParse();
our (%text, %in, %config, %module_info, %access, $module_name);

&ui_print_header(undef, $module_info{'desc'}, "", undef, 1, 1);

if (!&has_command(&get_kubectl_cmd())) {
    &ui_print_endpage(
        &text('index_ecmd', "<tt>".&get_kubectl_cmd()."</tt>",
        "../config.cgi?$module_name"));
}

my $k8s_version = &get_k8s_version();
if ($k8s_version) {
    print &ui_alert_box(&text('index_version', $k8s_version), 'info');
}

my $current_context = &get_current_context();
if ($current_context) {
    print &ui_alert_box(&text('index_context', $current_context), 'info');
}

my @tabs = (
    [ "pods", $text{'index_tabpods'}, "index.cgi?mode=pods" ],
    [ "services", $text{'index_tabservices'}, "index.cgi?mode=services" ],
    [ "deployments", $text{'index_tabdeployments'}, "index.cgi?mode=deployments" ],
    [ "nodes", $text{'index_tabnodes'}, "index.cgi?mode=nodes" ],
    [ "namespaces", $text{'index_tabnamespaces'}, "index.cgi?mode=namespaces" ],
    [ "configmaps", $text{'index_tabconfigmaps'}, "index.cgi?mode=configmaps" ],
    [ "secrets", $text{'index_tabsecrets'}, "index.cgi?mode=secrets" ],
    [ "contexts", $text{'index_tabcontexts'}, "index.cgi?mode=contexts" ],
);

my $mode = $in{'mode'} || "pods";
my %tab = map { $_->[0], 1 } @tabs;
$mode = "pods" if (!$tab{$mode});

my $namespace = $in{'namespace'} || 'default';

print "<form action='index.cgi' method='get'>\n";
print "<input type='hidden' name='mode' value='$mode'>\n";
print &text('index_namespace').": ";
print &ui_select("namespace", $namespace,
    [ map { $_->{'name'}, $_->{'name'} } &list_namespaces() ]);
print " <input type='submit' value='$text{'Go'}'>\n";
print "</form>\n";

print &ui_tabs_start(\@tabs, "mode", $mode, 1);

print &ui_tabs_start_tab("mode", "pods");
&show_pods_tab($namespace);
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "services");
&show_services_tab($namespace);
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "deployments");
&show_deployments_tab($namespace);
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "nodes");
&show_nodes_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "namespaces");
&show_namespaces_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "configmaps");
&show_configmaps_tab($namespace);
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "secrets");
&show_secrets_tab($namespace);
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "contexts");
&show_contexts_tab();
print &ui_tabs_end_tab();

print &ui_tabs_end(1);

&ui_print_footer("/", $text{'index'});

sub show_pods_tab
{
my ($namespace) = @_;
my @pods = &list_pods($namespace);

if (@pods) {
    print &ui_form_start("pod_action.cgi", "post");
    print "<input type='hidden' name='namespace' value='$namespace'>\n";

    my @heads = (
        { 'type' => 'checkbox', 'name' => 'd', 'values' => [ map { $_->{'name'} } @pods ] },
        $text{'index_name'},
        $text{'index_status'},
        $text{'index_node'},
        $text{'index_restarts'},
        $text{'index_image'},
        $text{'index_age'},
        $text{'index_actions'},
    );

    my @data;
    foreach my $p (@pods) {
        my $status_color = $p->{'status'} eq 'Running' ? 'green' : 
                          ($p->{'status'} eq 'Pending' ? 'yellow' : 'red');
        push(@data, [
            { 'type' => 'checkbox', 'name' => 'd', 'value' => $p->{'name'} },
            &ui_link("view_pod.cgi?name=".$p->{'name'}."&namespace=$namespace", $p->{'name'}),
            "<span style='color: $status_color'>".$p->{'status'}."</span>",
            $p->{'node'} || '-',
            $p->{'restarts'},
            $p->{'image'},
            $p->{'age'},
            &ui_links_row([
                &ui_link("pod_action.cgi?action=logs&name=".$p->{'name'}."&namespace=$namespace", $text{'action_logs'}),
                &ui_link("pod_action.cgi?action=delete&name=".$p->{'name'}."&namespace=$namespace", $text{'action_delete'}),
            ]),
        ]);
    }

    print &ui_columns_table(\@heads, 100, \@data);

    my @actions = (
        [ 'delete', $text{'action_delete'} ],
    );
    print &ui_form_end(\@actions);
}
else {
    print "<b>$text{'index_nopods'}</b><p>\n";
}
}

sub show_services_tab
{
my ($namespace) = @_;
my @services = &list_services($namespace);

if (@services) {
    print &ui_form_start("service_action.cgi", "post");
    print "<input type='hidden' name='namespace' value='$namespace'>\n";

    my @heads = (
        { 'type' => 'checkbox', 'name' => 'd', 'values' => [ map { $_->{'name'} } @services ] },
        $text{'index_name'},
        $text{'index_type'},
        $text{'index_clusterip'},
        $text{'index_ports'},
        $text{'index_age'},
    );

    my @data;
    foreach my $s (@services) {
        push(@data, [
            { 'type' => 'checkbox', 'name' => 'd', 'value' => $s->{'name'} },
            $s->{'name'},
            $s->{'type'},
            $s->{'cluster_ip'},
            $s->{'ports'},
            $s->{'age'},
        ]);
    }

    print &ui_columns_table(\@heads, 100, \@data);

    my @actions = (
        [ 'delete', $text{'action_delete'} ],
    );
    print &ui_form_end(\@actions);
}
else {
    print "<b>$text{'index_noservices'}</b><p>\n";
}
}

sub show_deployments_tab
{
my ($namespace) = @_;
my @deployments = &list_deployments($namespace);

if (@deployments) {
    print &ui_form_start("deployment_action.cgi", "post");
    print "<input type='hidden' name='namespace' value='$namespace'>\n";

    my @heads = (
        { 'type' => 'checkbox', 'name' => 'd', 'values' => [ map { $_->{'name'} } @deployments ] },
        $text{'index_name'},
        $text{'index_replicas'},
        $text{'index_available'},
        $text{'index_ready'},
        $text{'index_image'},
        $text{'index_age'},
        $text{'index_actions'},
    );

    my @data;
    foreach my $d (@deployments) {
        push(@data, [
            { 'type' => 'checkbox', 'name' => 'd', 'value' => $d->{'name'} },
            $d->{'name'},
            $d->{'replicas'},
            $d->{'available'},
            $d->{'ready'},
            $d->{'image'},
            $d->{'age'},
            &ui_links_row([
                &ui_link("scale_deployment.cgi?name=".$d->{'name'}."&namespace=$namespace", $text{'action_scale'}),
                &ui_link("deployment_action.cgi?action=delete&name=".$d->{'name'}."&namespace=$namespace", $text{'action_delete'}),
            ]),
        ]);
    }

    print &ui_columns_table(\@heads, 100, \@data);

    my @actions = (
        [ 'delete', $text{'action_delete'} ],
    );
    print &ui_form_end(\@actions);
}
else {
    print "<b>$text{'index_nodeployments'}</b><p>\n";
}
}

sub show_nodes_tab
{
my @nodes = &list_nodes();

if (@nodes) {
    my @heads = (
        $text{'index_name'},
        $text{'index_status'},
        $text{'index_roles'},
        $text{'index_version'},
        $text{'index_os'},
        $text{'index_kernel'},
        $text{'index_age'},
    );

    my @data;
    foreach my $n (@nodes) {
        push(@data, [
            $n->{'name'},
            $n->{'status'},
            $n->{'roles'},
            $n->{'version'},
            $n->{'os'},
            $n->{'kernel'},
            $n->{'age'},
        ]);
    }

    print &ui_columns_table(\@heads, 100, \@data);
}
else {
    print "<b>$text{'index_nonodes'}</b><p>\n";
}
}

sub show_namespaces_tab
{
my @namespaces = &list_namespaces();

if (@namespaces) {
    my @heads = (
        $text{'index_name'},
        $text{'index_status'},
        $text{'index_age'},
    );

    my @data;
    foreach my $n (@namespaces) {
        push(@data, [
            $n->{'name'},
            $n->{'status'},
            $n->{'age'},
        ]);
    }

    print &ui_columns_table(\@heads, 100, \@data);
}
else {
    print "<b>$text{'index_nonamespaces'}</b><p>\n";
}
}

sub show_configmaps_tab
{
my ($namespace) = @_;
my @configmaps = &list_configmaps($namespace);

if (@configmaps) {
    my @heads = (
        $text{'index_name'},
        $text{'index_datakeys'},
        $text{'index_age'},
    );

    my @data;
    foreach my $c (@configmaps) {
        push(@data, [
            $c->{'name'},
            $c->{'data_keys'},
            $c->{'age'},
        ]);
    }

    print &ui_columns_table(\@heads, 100, \@data);
}
else {
    print "<b>$text{'index_noconfigmaps'}</b><p>\n";
}
}

sub show_secrets_tab
{
my ($namespace) = @_;
my @secrets = &list_secrets($namespace);

if (@secrets) {
    my @heads = (
        $text{'index_name'},
        $text{'index_type'},
        $text{'index_age'},
    );

    my @data;
    foreach my $s (@secrets) {
        push(@data, [
            $s->{'name'},
            $s->{'type'},
            $s->{'age'},
        ]);
    }

    print &ui_columns_table(\@heads, 100, \@data);
}
else {
    print "<b>$text{'index_nosecrets'}</b><p>\n";
}
}

sub show_contexts_tab
{
my @contexts = &get_k8s_contexts();
my $current = &get_current_context();

if (@contexts) {
    print &ui_form_start("context_action.cgi", "post");

    my @heads = (
        { 'type' => 'checkbox', 'name' => 'd', 'values' => [ map { $_->{'name'} } @contexts ] },
        $text{'index_name'},
        $text{'index_cluster'},
        $text{'index_user'},
        $text{'index_current'},
    );

    my @data;
    foreach my $c (@contexts) {
        push(@data, [
            { 'type' => 'checkbox', 'name' => 'd', 'value' => $c->{'name'} },
            $c->{'name'},
            $c->{'cluster'},
            $c->{'user'},
            $c->{'name'} eq $current ? '<span style="color:green">*</span>' : '',
        ]);
    }

    print &ui_columns_table(\@heads, 100, \@data);

    my @actions = (
        [ 'use', $text{'action_use'} ],
    );
    print &ui_form_end(\@actions);
}
else {
    print "<b>$text{'index_nocontexts'}</b><p>\n";
}
}