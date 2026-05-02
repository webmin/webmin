#!/usr/bin/perl
# move_rule.cgi
# Move a rule up or down within a chain

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'move_err'});

my @tables = get_nftables_save();
my $table = $tables[$in{'table'}];
$table || error($text{'move_notable'});

my $chain = $in{'chain'};
$chain || error($text{'move_nochain'});

my $dir = $in{'dir'};
$dir = '' if (!defined($dir));

my $idx = $in{'idx'};
$idx =~ /^\d+$/ || error($text{'move_norule'});

my $rv = move_rule_in_chain($table, $chain, $idx, $dir);
if (!defined($rv)) {
    error($text{'move_norule'});
}

if ($rv) {
    my $err = save_table_configuration($table, @tables);
    error(text('move_failed', $err)) if ($err);
    webmin_log("move", "rule", undef,
                { 'table' => $table->{'name'},
                  'family' => $table->{'family'},
                  'chain' => $chain,
                  'dir' => $dir });
}

redirect("index.cgi?table=$in{'table'}");
