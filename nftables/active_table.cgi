#!/usr/bin/perl
# active_table.cgi
# Show a read-only active nftables table

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'active_table_err'});

my ($tables, $err) = get_active_nftables_save();
error(text('active_failed', $err)) if ($err);

my $table;
foreach my $t (@$tables) {
	if ($t->{'family'} eq $in{'family'} && $t->{'name'} eq $in{'name'}) {
		$table = $t;
		last;
	}
}
$table || error($text{'active_table_notable'});
my @saved_tables = get_nftables_save();
my $status_key = active_table_status($table, \@saved_tables);
my $is_saved = table_is_webmin_managed($table, \@saved_tables);

ui_print_header(undef, $text{'active_table_title'}, "", "intro", 1, 1,
                undef, restart_button());

print ui_table_start($text{'active_table_summary'}, "width=100%", 2);
print ui_table_row($text{'active_table'}, html_escape(nft_table_spec($table)));
print ui_table_row($text{'active_flags'}, html_escape($table->{'flags'} || "-"));
print ui_table_row($text{'active_status'}, $text{'active_'.$status_key});
print ui_table_end();

if (!$is_saved) {
	print ui_buttons_start();
	print ui_buttons_row(
		"import_table.cgi?family=".urlize($table->{'family'}).
		"&name=".urlize($table->{'name'}),
		$text{'active_import'}, $text{'active_importdesc'});
	print ui_buttons_end();
	}

my ($chains_html, $sets_html);

$chains_html .= ui_columns_start(
	[ $text{'index_chain_col'}, $text{'index_type'}, $text{'index_hook'},
	  $text{'index_priority'}, $text{'index_policy_col'}, $text{'index_rules'} ],
	100);
foreach my $c (sort keys %{$table->{'chains'}}) {
	my $chain_def = $table->{'chains'}->{$c} || { };
	my $policy = $chain_def->{'policy'};
	my $policy_label = $policy ?
		($text{'index_policy_'.lc($policy)} || uc($policy)) : "-";
	my @rules = grep { $_->{'chain'} eq $c } @{$table->{'rules'}};
	my $rules_html = @rules ?
		ui_tag('div',
			join("", map {
				ui_tag('div', describe_rule($_),
					{ 'class' => 'nftables_rule_text' })
			} @rules),
			{ 'class' => 'nftables_rules_list',
			  'style' => 'display: grid; row-gap: 0.25em;' }) :
		ui_tag('i', $text{'index_rules_none'});
	$chains_html .= ui_columns_row([
		html_escape($c),
		html_escape($chain_def->{'type'} || "-"),
		html_escape($chain_def->{'hook'} || "-"),
		defined($chain_def->{'priority'}) ?
			html_escape($chain_def->{'priority'}) : "-",
		html_escape($policy_label),
		$rules_html,
	]);
}
$chains_html .= ui_columns_end();

$sets_html .= ui_columns_start(
	[ $text{'index_set_name'}, $text{'index_set_type'},
	  $text{'index_set_flags'}, $text{'index_set_elements'} ], 100);
if ($table->{'sets'} && ref($table->{'sets'}) eq 'HASH') {
	foreach my $s (sort keys %{$table->{'sets'}}) {
		my $set = $table->{'sets'}->{$s} || { };
		$sets_html .= ui_columns_row([
			html_escape($s),
			html_escape($set->{'type'} || "-"),
			html_escape($set->{'flags'} || "-"),
			html_escape(set_elements_summary($set)),
		]);
	}
}
$sets_html .= ui_columns_end();

my @tabs = (
	[ 'chains', $text{'index_tab_chains'} ],
	[ 'sets', $text{'index_tab_sets'} ],
	);
my $tab = $in{'view'} && $in{'view'} eq 'sets' ? 'sets' : 'chains';
print ui_hr();
print ui_tabs_start(\@tabs, "view", $tab, 1);
print ui_tabs_start_tab("view", "chains");
print $chains_html;
print ui_tabs_end_tab();
print ui_tabs_start_tab("view", "sets");
print $sets_html;
print ui_tabs_end_tab();
print ui_tabs_end(1);

ui_print_footer("active.cgi", $text{'active_return'});
