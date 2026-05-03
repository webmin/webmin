#!/usr/bin/perl
# rename_chain.cgi
# Rename an existing chain

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
assert_acl('chains');

my @tables = get_nftables_save();
my $table = $tables[$in{'table'}];
$table || error($text{'chain_notable'});
assert_table_acl($table);

my $chain = $table->{'chains'}->{$in{'chain'}};
$chain || error($text{'chain_nochain'});

ui_print_header(undef, $text{'rename_chain_title'}, "", "intro", 1, 1);
print ui_form_start("save_chain.cgi");
print ui_hidden("table", $in{'table'});
print ui_hidden("rename", 1);
print ui_hidden("chain_old", $in{'chain'});

print ui_table_start($text{'rename_chain_header'}, "width=100%", 2);
print ui_table_row($text{'rename_chain_old'},
    "<tt>".html_escape($in{'chain'})."</tt>");
print ui_table_row(hlink($text{'rename_chain_new'}, "chain_name"),
    ui_textbox("chain_name", $in{'chain'}, 20));
print ui_table_end();

print ui_form_end([ [ undef, $text{'rename_chain_ok'} ] ]);
ui_print_footer("index.cgi?table=$in{'table'}", $text{'index_return'});
