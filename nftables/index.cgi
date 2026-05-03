#!/usr/bin/perl
# index.cgi
# Display current nftables configuration

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text, %config);
ReadParse();
my $can_view_saved = check_acl('view');
if (!$can_view_saved && !check_acl('active') && !check_acl('create') &&
    !check_acl('setup')) {
    error($text{'acl_ecannot'});
}
my $partial = $in{'partial'};
if (!$partial) {
    ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1,
                    undef, restart_button());
}

# Check for nft command
my $cmd = get_nft_command();
if (!$cmd) {
    print text('index_ecommand', "<tt>nft</tt>");
    if (!$partial) {
        ui_print_footer("/", $text{'index'});
    }
    exit;
}

# Load tables
my @tables = $can_view_saved ? get_nftables_save() : ( );
@tables = grep { check_table_acl($_) } @tables;
my $rules_html = "";

if (!@tables) {
    $rules_html .= ui_buttons_start();
    $rules_html .= ui_buttons_row("setup.cgi", $text{'index_setup'}, $text{'index_setupdesc'})
        if (check_acl('setup'));
    $rules_html .= ui_buttons_row("create_table.cgi", $text{'index_table_create'},
                                   $text{'index_table_createdesc'})
        if (check_acl('create'));
    $rules_html .= ui_buttons_row("active.cgi", $text{'index_active'},
                                   $text{'index_activedesc'})
        if (check_acl('active'));
    $rules_html .= ui_buttons_end();
} else {
    # Select table
    my $found_table;
    if (defined($in{'table_family'}) && defined($in{'table_name'})) {
        for (my $i = 0; $i <= $#tables; $i++) {
            if ($tables[$i]->{'family'} eq $in{'table_family'} &&
                $tables[$i]->{'name'} eq $in{'table_name'}) {
                $in{'table'} = $i;
                $found_table = 1;
                last;
            }
        }
    }
    if (!$found_table &&
        (!defined($in{'table'}) || $in{'table'} !~ /^\d+$/ ||
         $in{'table'} > $#tables)) {
            $in{'table'} = 0;
    }
    my @table_opts;
    for (my $i = 0; $i <= $#tables; $i++) {
        my $t = $tables[$i];
        push(@table_opts, [ $i, $t->{'family'}." ".$t->{'name'} ]);
    }

    if (!$partial) {
        print ui_form_start("index.cgi");
        print "<div class='nftables_table_select'>\n";
        print text('index_change'),"&nbsp;&nbsp;";
        print ui_select("table", $in{'table'}, \@table_opts, 1, 0, 1, 0,
                         "onchange='this.form.querySelector(\"[name=nft_submit]\").click()'");
        print ui_submit("", "nft_submit", 0, "style='display:none'");
        print " ", ui_link_button("create_table.cgi", $text{'index_table_create'})
            if (check_acl('create'));
        print " ", ui_link_button(
            "delete_table.cgi?table=$in{'table'}&table_family=".
            urlize($tables[$in{'table'}]->{'family'}).
            "&table_name=".urlize($tables[$in{'table'}]->{'name'}),
            $text{'index_table_delete'}) if (check_acl('delete'));
        print "</div>\n";
        print ui_form_end();
    }

    # Identify current table
    my $curr = $tables[$in{'table'}];

    if ($curr) {
        my ($sets_html, $chains_html);

        # Show sets
        $sets_html .= ui_form_start("delete_sets.cgi", "post");
        $sets_html .= ui_hidden("table", $in{'table'});
        $sets_html .= ui_hidden("table_family", $curr->{'family'});
        $sets_html .= ui_hidden("table_name", $curr->{'name'});
        my $set_form = $partial ? 1 : 2;
        my $has_sets = $curr->{'sets'} && ref($curr->{'sets'}) eq 'HASH' &&
            keys(%{$curr->{'sets'}});
        my @set_select_links = $has_sets && check_acl('delete') ?
            ( select_all_link("s", $set_form),
              select_invert_link("s", $set_form) ) : ( );
        my @set_top_links = @set_select_links;
        push(@set_top_links, ui_link("edit_set.cgi?table=$in{'table'}&new=1",
                    $text{'index_set_create'})) if (check_acl('sets'));
        $sets_html .= ui_links_row(\@set_top_links);
        my @set_tds = ( "width=5" );
        $sets_html .= ui_columns_start(
            [ "", $text{'index_set_name'}, $text{'index_set_type'},
              $text{'index_set_flags'}, $text{'index_set_elements'},
              $text{'index_set_actions'} ], 100, 0, \@set_tds);
        if ($has_sets) {
            foreach my $s (sort keys %{$curr->{'sets'}}) {
                my $set = $curr->{'sets'}->{$s} || { };
                my $actions_html = check_acl('sets') ?
                    ui_link("edit_set.cgi?table=$in{'table'}&set=".
                            urlize($s), $text{'index_set_edit'}) : "-";
                my @cols = (
                    $s,
                    $set->{'type'} || "-",
                    $set->{'flags'} || "-",
                    set_elements_summary($set),
                    $actions_html
                    );
                $sets_html .= check_acl('delete') ?
                    ui_checked_columns_row(\@cols, \@set_tds, "s", $s) :
                    ui_columns_row([ "", @cols ]);
            }
        }
        $sets_html .= ui_columns_end();
        $sets_html .= @set_select_links ?
            ui_form_end([ [ undef, $text{'index_set_deletesel'} ] ]) :
            ui_form_end();

        # Show chains and rules
        $chains_html .= ui_form_start("delete_chains.cgi", "post", undef,
                                      "id='nftables_chains_form'");
        $chains_html .= ui_hidden("table", $in{'table'});
        $chains_html .= ui_hidden("table_family", $curr->{'family'});
        $chains_html .= ui_hidden("table_name", $curr->{'name'});
        my $chain_form = $partial ? 0 : 1;
        my @chain_select_links = keys(%{$curr->{'chains'}}) && check_acl('delete') ?
            ( select_all_link("d", $chain_form),
              select_invert_link("d", $chain_form) ) : ( );
        my @chain_top_links = @chain_select_links;
        push(@chain_top_links, ui_link("edit_chain.cgi?table=$in{'table'}&new=1",
                    $text{'index_chain_create'})) if (check_acl('chains'));
        $chains_html .= ui_links_row(\@chain_top_links);
        my @chain_tds = ( "width=5" );
        $chains_html .= ui_columns_start(
            [ "", $text{'index_chain_col'}, $text{'index_type'},
              $text{'index_hook'}, $text{'index_priority'},
              $text{'index_policy_col'}, $text{'index_rules'},
              $text{'index_actions'} ], 100, 0, \@chain_tds);

        foreach my $c (sort keys %{$curr->{'chains'}}) {
            my $chain_def = $curr->{'chains'}->{$c} || { };
            my $policy = $chain_def->{'policy'};
            my $policy_label = $policy ?
                ($text{'index_policy_'.lc($policy)} || uc($policy)) : "-";
            my @rules = grep { $_->{'chain'} eq $c } @{$curr->{'rules'}};
            my $rules_html_row;
            if (@rules) {
                my $ri = 0;
                $rules_html_row = ui_tag_start('table',
                    { 'class' => 'nftables_rules_table',
                      'width' => '100%',
                      'cellspacing' => 0,
                      'cellpadding' => 0 });
                foreach my $r (@rules) {
                    my $desc = describe_rule($r);
                    my $rule_url = "edit_rule.cgi?table=$in{'table'}&chain=".
                        urlize($c)."&idx=$r->{'index'}";
                    my $rule_link = check_acl('rules') ?
                        ui_tag('a', $desc, { 'href' => $rule_url }) : $desc;
                    my $imgdir = "@{[get_webprefix()]}/images";
                    my $up_url = "move_rule.cgi?table=$in{'table'}&chain=".
                        urlize($c)."&idx=$r->{'index'}&dir=up";
                    my $down_url = "move_rule.cgi?table=$in{'table'}&chain=".
                        urlize($c)."&idx=$r->{'index'}&dir=down";
                    my $down_move = check_acl('rules') && $ri < $#rules ?
                        ui_tag('a',
                            ui_tag('img', undef,
                                { 'class' => 'ui_up_down_arrows_down',
                                  'src' => "$imgdir/movedown.gif",
                                  'border' => 0 }),
                            { 'class' => 'ui_up_down_arrows_down',
                              'href' => $down_url }) :
                        ui_tag('img', undef,
                            { 'class' => 'ui_up_down_arrows_gap',
                              'src' => "$imgdir/movegap.gif" });
                    my $up_move = check_acl('rules') && $ri > 0 ?
                        ui_tag('a',
                            ui_tag('img', undef,
                                { 'class' => 'ui_up_down_arrows_up',
                                  'src' => "$imgdir/moveup.gif",
                                  'border' => 0 }),
                            { 'class' => 'ui_up_down_arrows_up',
                              'href' => $up_url }) :
                        ui_tag('img', undef,
                            { 'class' => 'ui_up_down_arrows_gap',
                              'src' => "$imgdir/movegap.gif" });
                    $rules_html_row .= ui_tag_start('tr');
                    $rules_html_row .= ui_tag('td', $rule_link,
                        { 'class' => 'nftables_rule_text' });
                    $rules_html_row .= ui_tag('td', $down_move,
                        { 'class' => 'nftables_rule_move_down',
                          'width' => 10,
                          'style' => 'white-space: nowrap; text-align: center;' });
                    $rules_html_row .= ui_tag('td', $up_move,
                        { 'class' => 'nftables_rule_move_up',
                          'width' => 10,
                          'style' => 'white-space: nowrap; text-align: center;' });
                    $rules_html_row .= ui_tag_end('tr');
                    $ri++;
                }
                $rules_html_row .= ui_tag_end('table');
            } else {
                $rules_html_row = ui_tag('i', $text{'index_rules_none'});
            }

            my @actions;
            if (check_acl('chains')) {
                push(@actions, ui_link("edit_chain.cgi?table=$in{'table'}&chain=".
                         urlize($c), $text{'index_cedit'}));
                push(@actions, ui_link("rename_chain.cgi?table=$in{'table'}&chain=".
                         urlize($c), $text{'index_crename'}));
                }
            push(@actions, ui_link("edit_rule.cgi?table=$in{'table'}&chain=".
                         urlize($c)."&new=1", $text{'index_radd'}))
                if (check_acl('rules'));
            my $actions_html = @actions ? join(" | ", @actions) : "-";
            my @cols = (
                $c,
                $chain_def->{'type'} || "-",
                $chain_def->{'hook'} || "-",
                defined($chain_def->{'priority'}) ? $chain_def->{'priority'} : "-",
                $policy_label,
                $rules_html_row,
                $actions_html
                );
            $chains_html .= check_acl('delete') ?
                ui_checked_columns_row(\@cols, \@chain_tds, "d", $c) :
                ui_columns_row([ "", @cols ]);
        }
        $chains_html .= ui_columns_end();
        $chains_html .= @chain_select_links ?
            ui_form_end([ [ undef, $text{'index_cdeletesel'} ] ]) :
            ui_form_end();

        my @tabs = ( [ 'chains', $text{'index_tab_chains'} ] );
        push(@tabs, [ 'sets', $text{'index_tab_sets'} ]) if (check_acl('sets'));
        my $tab = check_acl('sets') && $in{'view'} && $in{'view'} eq 'sets' ?
            'sets' : 'chains';
        $rules_html .= ui_hr();
        $rules_html .= ui_tabs_start(\@tabs, "view", $tab, 1);
        $rules_html .= ui_tabs_start_tab("view", "chains");
        $rules_html .= $chains_html;
        $rules_html .= ui_tabs_end_tab();
        if (check_acl('sets')) {
            $rules_html .= ui_tabs_start_tab("view", "sets");
            $rules_html .= $sets_html;
            $rules_html .= ui_tabs_end_tab();
        }
        $rules_html .= ui_tabs_end(1);

        if (check_acl('quick') && find_input_chain($curr)) {
            my $ip_placeholder =
                text('quick_ip_placeholder', '1.2.3.4', '2001:db8::1/64');
            foreach my $action (
                [ 'allow', $text{'index_allowip_go'} ],
                [ 'block', $text{'index_blockip_go'} ],
                ) {
                $rules_html .= "<br>".ui_form_start("manage_ip.cgi", "post");
                $rules_html .= ui_hidden("table", $in{'table'});
                $rules_html .= ui_hidden("table_family", $curr->{'family'});
                $rules_html .= ui_hidden("table_name", $curr->{'name'});
                $rules_html .= ui_submit($action->[1], $action->[0]).
                    ui_textbox("ip", undef, 22, undef, undef,
                        "placeholder='".quote_escape($ip_placeholder)."'");
                $rules_html .= ui_form_end();
            }
        }
    }
}

if ($partial) {
    print $rules_html;
    exit;
}

print $rules_html;

if (@tables && (check_acl('apply') || check_acl('active') || check_acl('setup'))) {
    print ui_hr();
    print ui_buttons_start();
    print ui_buttons_row("restart.cgi", $text{'index_apply'}, $text{'index_applydesc'})
        if (check_acl('apply'));
    print ui_buttons_row("active.cgi", $text{'index_active'}, $text{'index_activedesc'})
        if (check_acl('active'));
    print ui_buttons_row("setup.cgi", $text{'index_setup'}, $text{'index_setupdesc'})
        if (check_acl('setup'));
    print ui_buttons_end();
}

ui_print_footer("/", $text{'index'});
