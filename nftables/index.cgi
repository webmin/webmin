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
    if (!defined($in{'table'}) || $in{'table'} !~ /^\d+$/ ||
        $in{'table'} > $#tables) {
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
        print "</div>\n";
        print ui_form_end();
    }

    # Identify current table
    my $curr = $tables[$in{'table'}];

    if ($curr) {
        # Show sets
        $rules_html .= ui_hr();
        $rules_html .= "<b>$text{'index_sets'}</b><br>\n";
        if ($curr->{'sets'} && ref($curr->{'sets'}) eq 'HASH' &&
            keys %{$curr->{'sets'}}) {
            $rules_html .= ui_columns_start(
                [ $text{'index_set_name'}, $text{'index_set_type'},
                  $text{'index_set_flags'}, $text{'index_set_elements'},
                  $text{'index_set_actions'} ], 100);
            foreach my $s (sort keys %{$curr->{'sets'}}) {
                my $set = $curr->{'sets'}->{$s} || { };
                my $actions_html =
                    ui_link("edit_set.cgi?table=$in{'table'}&set=".
                            urlize($s), $text{'index_set_edit'})."<br>".
                    ui_link("delete_set.cgi?table=$in{'table'}&set=".
                            urlize($s), $text{'index_set_delete'});
                $rules_html .= ui_columns_row([
                    $s,
                    $set->{'type'} || "-",
                    $set->{'flags'} || "-",
                    set_elements_summary($set),
                    $actions_html
                ]);
            }
            $rules_html .= ui_columns_end();
        }
        else {
            $rules_html .= "<i>$text{'index_sets_none'}</i><br>\n";
        }
        $rules_html .= ui_buttons_start();
        $rules_html .= ui_buttons_row(
            "edit_set.cgi?table=$in{'table'}&new=1",
            $text{'index_set_create'},
            $text{'index_set_createdesc'});
        $rules_html .= ui_buttons_end();

        # Show chains and rules
        $rules_html .= ui_hr();
        $rules_html .= ui_columns_start(
            [ $text{'index_chain_col'}, $text{'index_type'},
              $text{'index_hook'}, $text{'index_priority'},
              $text{'index_policy_col'}, $text{'index_rules'},
              $text{'index_actions'} ], 100);

        foreach my $c (sort keys %{$curr->{'chains'}}) {
            my $chain_def = $curr->{'chains'}->{$c} || { };
            my $policy = $chain_def->{'policy'};
            my $policy_label = $policy ?
                ($text{'index_policy_'.lc($policy)} || uc($policy)) : "-";
            my @rules = grep { $_->{'chain'} eq $c } @{$curr->{'rules'}};
            my $rules_html_row;
            if (@rules) {
                my $ri = 0;
                $rules_html_row = "<table class='nftables_rules_table' width='100%'>\n";
                foreach my $r (@rules) {
                    my $desc = describe_rule($r);
                    my $rule_link = ui_link(
                        "edit_rule.cgi?table=$in{'table'}&chain=".
                        urlize($c)."&idx=$r->{'index'}",
                        $desc);
                    my $move = ui_up_down_arrows(
                        "move_rule.cgi?table=$in{'table'}&chain=".
                        urlize($c)."&idx=$r->{'index'}&dir=up",
                        "move_rule.cgi?table=$in{'table'}&chain=".
                        urlize($c)."&idx=$r->{'index'}&dir=down",
                        $ri > 0,
                        $ri < $#rules);
                    $rules_html_row .= "<tr><td>$rule_link</td>".
                                       "<td align='right' style='white-space:nowrap'>$move</td></tr>\n";
                    $ri++;
                }
                $rules_html_row .= "<tr><td colspan='2'>".
                    ui_link("edit_rule.cgi?table=$in{'table'}&chain=".
                             urlize($c)."&new=1", $text{'index_radd'}).
                    "</td></tr>\n";
                $rules_html_row .= "</table>";
            } else {
                $rules_html_row = "<i>$text{'index_rules_none'}</i>";
                $rules_html_row .= "<br>".
                    ui_link("edit_rule.cgi?table=$in{'table'}&chain=".
                             urlize($c)."&new=1", $text{'index_radd'});
            }

            my $actions_html =
                ui_link("edit_chain.cgi?table=$in{'table'}&chain=".
                         urlize($c), $text{'index_cedit'})."<br>".
                ui_link("rename_chain.cgi?table=$in{'table'}&chain=".
                         urlize($c), $text{'index_crename'})."<br>".
                ui_link("delete_chain.cgi?table=$in{'table'}&chain=".
                         urlize($c), $text{'index_cdelete'});
            $rules_html .= ui_columns_row([
                $c,
                $chain_def->{'type'} || "-",
                $chain_def->{'hook'} || "-",
                defined($chain_def->{'priority'}) ? $chain_def->{'priority'} : "-",
                $policy_label,
                $rules_html_row,
                $actions_html
            ]);
        }
        $rules_html .= ui_columns_end();
        $rules_html .= ui_hr();
        $rules_html .= ui_buttons_start();
        $rules_html .= ui_buttons_row(
            "edit_chain.cgi?table=$in{'table'}&new=1",
            $text{'index_chain_create'},
            $text{'index_chain_createdesc'});
        $rules_html .= ui_buttons_row("delete_table.cgi?table=$in{'table'}",
                                       $text{'index_table_delete'},
                                       $text{'index_table_deletedesc'});
        $rules_html .= ui_buttons_end();
    }
}

if ($partial) {
    print $rules_html;
    exit;
}

print "<div id='nftables_ruleset'>\n";
print $rules_html;
print "</div>\n";

if (@tables) {
    print ui_hr();
    print ui_buttons_start();
    print ui_buttons_row("create_table.cgi", $text{'index_table_create'},
                          $text{'index_table_createdesc'});
    print ui_buttons_row("apply.cgi", $text{'index_apply'}, $text{'index_applydesc'});
    print ui_buttons_end();
}

ui_print_footer("/", $text{'index'});
