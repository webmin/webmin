#!/usr/bin/perl
# index.cgi
# Display current nftables configuration

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text, %config);
ReadParse();
my $partial = $in{'partial'};
if (!$partial) {
    ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
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

# Check if kernel supports it (basic check)
my $out = backquote_command("$cmd list ruleset 2>&1");
if ($? && $out !~ /no ruleset/i) {
    # If it fails and not just empty
    print text('index_ekernel', "<pre>$out</pre>");
    if (!$partial) {
        ui_print_footer("/", $text{'index'});
    }
    exit;
}

# Load tables
my @tables = get_nftables_save();
my $rules_html = "";

if (!@tables) {
    $rules_html .= "<b>$text{'index_none'}</b><p>\n";
    $rules_html .= ui_buttons_start();
    $rules_html .= ui_buttons_row("setup.cgi", $text{'index_setup'}, $text{'index_setupdesc'});
    $rules_html .= ui_buttons_row("create_table.cgi", $text{'index_table_create'},
                                   $text{'index_table_createdesc'});
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
        print text('index_change')," ";
        print ui_select("table", $in{'table'}, \@table_opts, 1, 0, 1, 0,
                         "onchange='this.form.querySelector(\"[name=nft_submit]\").click()'");
        print ui_submit("", "nft_submit", 0, "style='display:none'");
        print " ", ui_link_button("create_table.cgi", $text{'index_table_create'});
        print " ", ui_link_button(
            "delete_table.cgi?table=$in{'table'}&table_family=".
            urlize($tables[$in{'table'}]->{'family'}).
            "&table_name=".urlize($tables[$in{'table'}]->{'name'}),
            $text{'index_table_delete'});
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
        my @set_select_links = $has_sets ?
            ( select_all_link("s", $set_form),
              select_invert_link("s", $set_form) ) : ( );
        my @set_top_links = (
            @set_select_links,
            ui_link("edit_set.cgi?table=$in{'table'}&new=1",
                    $text{'index_set_create'})
            );
        $sets_html .= ui_links_row(\@set_top_links);
        my @set_tds = ( "width=5" );
        $sets_html .= ui_columns_start(
            [ "", $text{'index_set_name'}, $text{'index_set_type'},
              $text{'index_set_flags'}, $text{'index_set_elements'},
              $text{'index_set_actions'} ], 100, 0, \@set_tds);
        if ($has_sets) {
            foreach my $s (sort keys %{$curr->{'sets'}}) {
                my $set = $curr->{'sets'}->{$s} || { };
                my $actions_html =
                    ui_link("edit_set.cgi?table=$in{'table'}&set=".
                            urlize($s), $text{'index_set_edit'});
                $sets_html .= ui_checked_columns_row([
                    $s,
                    $set->{'type'} || "-",
                    $set->{'flags'} || "-",
                    set_elements_summary($set),
                    $actions_html
                ], \@set_tds, "s", $s);
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
        my @chain_select_links = keys(%{$curr->{'chains'}}) ?
            ( select_all_link("d", $chain_form),
              select_invert_link("d", $chain_form) ) : ( );
        my @chain_top_links = (
            @chain_select_links,
            ui_link("edit_chain.cgi?table=$in{'table'}&new=1",
                    $text{'index_chain_create'})
            );
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
                my @rule_rows;
                foreach my $r (@rules) {
                    my $desc = describe_rule($r);
                    my $rule_url = "edit_rule.cgi?table=$in{'table'}&chain=".
                        urlize($c)."&idx=$r->{'index'}";
                    my $rule_link = ui_tag('a', $desc,
                        { 'href' => $rule_url });
                    my $imgdir = "@{[get_webprefix()]}/images";
                    my $up_url = "move_rule.cgi?table=$in{'table'}&chain=".
                        urlize($c)."&idx=$r->{'index'}&dir=up";
                    my $down_url = "move_rule.cgi?table=$in{'table'}&chain=".
                        urlize($c)."&idx=$r->{'index'}&dir=down";
                    my $down_move = $ri < $#rules ?
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
                    my $up_move = $ri > 0 ?
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
                    push(@rule_rows, ui_tag('div',
                        ui_tag('div', $rule_link,
                            { 'class' => 'nftables_rule_text' }).
                        ui_tag('div', $down_move,
                            { 'class' => 'nftables_rule_move_down',
                              'style' => 'white-space: nowrap; text-align: center;' }).
                        ui_tag('div', $up_move,
                            { 'class' => 'nftables_rule_move_up',
                              'style' => 'white-space: nowrap; text-align: center;' }),
                        { 'class' => 'nftables_rule_row',
                          'style' => 'display: grid; grid-template-columns: '.
                                      'minmax(0, 1fr) auto auto; align-items: '.
                                      'center; column-gap: 0.5em;' }));
                    $ri++;
                }
                $rules_html_row = ui_tag('div', join("", @rule_rows),
                    { 'class' => 'nftables_rules_list',
                      'style' => 'display: grid; row-gap: 0.25em;' });
            } else {
                $rules_html_row = ui_tag('i', $text{'index_rules_none'});
            }

            my $actions_html =
                ui_link("edit_chain.cgi?table=$in{'table'}&chain=".
                         urlize($c), $text{'index_cedit'})."<br>".
                ui_link("rename_chain.cgi?table=$in{'table'}&chain=".
                         urlize($c), $text{'index_crename'})."<br>".
                ui_link("edit_rule.cgi?table=$in{'table'}&chain=".
                         urlize($c)."&new=1", $text{'index_radd'});
            $chains_html .= ui_checked_columns_row([
                $c,
                $chain_def->{'type'} || "-",
                $chain_def->{'hook'} || "-",
                defined($chain_def->{'priority'}) ? $chain_def->{'priority'} : "-",
                $policy_label,
                $rules_html_row,
                $actions_html
            ], \@chain_tds, "d", $c);
        }
        $chains_html .= ui_columns_end();
        $chains_html .= @chain_select_links ?
            ui_form_end([ [ undef, $text{'index_cdeletesel'} ] ]) :
            ui_form_end();

        my @tabs = (
            [ 'chains', $text{'index_tab_chains'} ],
            [ 'sets', $text{'index_tab_sets'} ],
            );
        my $tab = $in{'view'} && $in{'view'} eq 'sets' ? 'sets' : 'chains';
        $rules_html .= ui_hr();
        $rules_html .= ui_tabs_start(\@tabs, "view", $tab, 1);
        $rules_html .= ui_tabs_start_tab("view", "chains");
        $rules_html .= $chains_html;
        $rules_html .= ui_tabs_end_tab();
        $rules_html .= ui_tabs_start_tab("view", "sets");
        $rules_html .= $sets_html;
        $rules_html .= ui_tabs_end_tab();
        $rules_html .= ui_tabs_end(1);
    }
}

if ($partial) {
    print $rules_html;
    exit;
}

print $rules_html;

if (@tables && !$config{'direct'}) {
    print ui_hr();
    print ui_buttons_start();
    print ui_buttons_row("apply.cgi", $text{'index_apply'}, $text{'index_applydesc'});
    print ui_buttons_end();
}

ui_print_footer("/", $text{'index'});
