#!/usr/local/bin/perl
# index.cgi
# Automation management main page

use strict;
use warnings;

require './automation-lib.pl';
&ReadParse();
our (%text, %in, %config, %module_info, %access, $module_name);

&ui_print_header(undef, $module_info{'desc'}, "", undef, 1, 1);

my @tabs = (
    [ "scripts", $text{'index_tabscripts'}, "index.cgi?mode=scripts" ],
    [ "configs", $text{'index_tabconfigs'}, "index.cgi?mode=configs" ],
    [ "deployments", $text{'index_tabdeployments'}, "index.cgi?mode=deployments" ],
    [ "cron", $text{'index_tabcron'}, "index.cgi?mode=cron" ],
);

my $mode = $in{'mode'} || "scripts";
my %tab = map { $_->[0], 1 } @tabs;
$mode = "scripts" if (!$tab{$mode});

print &ui_tabs_start(\@tabs, "mode", $mode, 1);

print &ui_tabs_start_tab("mode", "scripts");
&show_scripts_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "configs");
&show_configs_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "deployments");
&show_deployments_tab();
print &ui_tabs_end_tab();

print &ui_tabs_start_tab("mode", "cron");
&show_cron_tab();
print &ui_tabs_end_tab();

print &ui_tabs_end(1);

&ui_print_footer("/", $text{'index'});

sub show_scripts_tab
{
my @scripts = &list_scripts();

if (@scripts) {
    print &ui_form_start("script_action.cgi", "post");

    my @heads = (
        { 'type' => 'checkbox', 'name' => 'd', 'values' => [ map { $_->{'name'} } @scripts ] },
        $text{'index_name'},
        $text{'index_size'},
        $text{'index_mtime'},
        $text{'index_executable'},
        $text{'index_actions'},
    );

    my @data;
    foreach my $s (@scripts) {
        push(@data, [
            { 'type' => 'checkbox', 'name' => 'd', 'value' => $s->{'name'} },
            &ui_link("edit_script.cgi?name=".$s->{'name'}, $s->{'name'}),
            $s->{'size'},
            $s->{'mtime'},
            $s->{'executable'} ? $text{'yes'} : $text{'no'},
            &ui_links_row([
                &ui_link("run_script.cgi?name=".$s->{'name'}, $text{'action_run'}),
                &ui_link("edit_script.cgi?name=".$s->{'name'}, $text{'action_edit'}),
                &ui_link("script_action.cgi?action=delete&name=".$s->{'name'}, $text{'action_delete'}),
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
    print "<b>$text{'index_noscripts'}</b><p>\n";
}

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("edit_script.cgi",
    $text{'index_newscript'},
    $text{'index_newscriptdesc'});
print &ui_buttons_end();
}

sub show_configs_tab
{
my @configs = &list_configs();

if (@configs) {
    print &ui_form_start("config_action.cgi", "post");

    my @heads = (
        { 'type' => 'checkbox', 'name' => 'd', 'values' => [ map { $_->{'name'} } @configs ] },
        $text{'index_name'},
        $text{'index_size'},
        $text{'index_mtime'},
        $text{'index_actions'},
    );

    my @data;
    foreach my $c (@configs) {
        push(@data, [
            { 'type' => 'checkbox', 'name' => 'd', 'value' => $c->{'name'} },
            &ui_link("edit_config.cgi?name=".$c->{'name'}, $c->{'name'}),
            $c->{'size'},
            $c->{'mtime'},
            &ui_links_row([
                &ui_link("edit_config.cgi?name=".$c->{'name'}, $text{'action_edit'}),
                &ui_link("config_action.cgi?action=delete&name=".$c->{'name'}, $text{'action_delete'}),
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
    print "<b>$text{'index_noconfigs'}</b><p>\n";
}

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("edit_config.cgi",
    $text{'index_newconfig'},
    $text{'index_newconfigdesc'});
print &ui_buttons_end();
}

sub show_deployments_tab
{
my @deployments = &list_deployments();

if (@deployments) {
    print &ui_form_start("deployment_action.cgi", "post");

    my @heads = (
        { 'type' => 'checkbox', 'name' => 'd', 'values' => [ map { $_->{'name'} } @deployments ] },
        $text{'index_name'},
        $text{'index_app'},
        $text{'index_env'},
        $text{'index_status'},
        $text{'index_mtime'},
        $text{'index_actions'},
    );

    my @data;
    foreach my $d (@deployments) {
        my $status_color = $d->{'status'} eq 'success' ? 'green' :
                          ($d->{'status'} eq 'failed' ? 'red' : 'yellow');
        push(@data, [
            { 'type' => 'checkbox', 'name' => 'd', 'value' => $d->{'name'} },
            &ui_link("edit_deployment.cgi?name=".$d->{'name'}, $d->{'name'}),
            $d->{'app'},
            $d->{'env'},
            "<span style='color: $status_color'>".$d->{'status'}."</span>",
            $d->{'mtime'},
            &ui_links_row([
                &ui_link("execute_deployment.cgi?name=".$d->{'name'}, $text{'action_execute'}),
                &ui_link("edit_deployment.cgi?name=".$d->{'name'}, $text{'action_edit'}),
                &ui_link("deployment_action.cgi?action=delete&name=".$d->{'name'}, $text{'action_delete'}),
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

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("edit_deployment.cgi",
    $text{'index_newdeployment'},
    $text{'index_newdeploymentdesc'});
print &ui_buttons_end();
}

sub show_cron_tab
{
my @jobs = &list_cron_jobs();

if (@jobs) {
    print &ui_form_start("cron_action.cgi", "post");

    my @heads = (
        { 'type' => 'checkbox', 'name' => 'd', 'values' => [ map { $_->{'line'} } @jobs ] },
        $text{'index_minute'},
        $text{'index_hour'},
        $text{'index_day'},
        $text{'index_month'},
        $text{'index_dow'},
        $text{'index_command'},
    );

    my @data;
    foreach my $j (@jobs) {
        push(@data, [
            { 'type' => 'checkbox', 'name' => 'd', 'value' => $j->{'line'} },
            $j->{'minute'},
            $j->{'hour'},
            $j->{'day'},
            $j->{'month'},
            $j->{'dow'},
            $j->{'command'},
        ]);
    }

    print &ui_columns_table(\@heads, 100, \@data);

    my @actions = (
        [ 'delete', $text{'action_delete'} ],
    );
    print &ui_form_end(\@actions);
}
else {
    print "<b>$text{'index_nocron'}</b><p>\n";
}

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("edit_cron.cgi",
    $text{'index_newcron'},
    $text{'index_newcrondesc'});
print &ui_buttons_end();
}