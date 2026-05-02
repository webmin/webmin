#!/usr/bin/perl
# delete_chains.cgi
# Delete selected nftables chains

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'delete_chains_err'});

my @tables = get_nftables_save();
my $table_idx = $in{'table'};
my $table;
if (defined($in{'table_family'}) && defined($in{'table_name'})) {
    for (my $i = 0; $i <= $#tables; $i++) {
        if ($tables[$i]->{'family'} eq $in{'table_family'} &&
            $tables[$i]->{'name'} eq $in{'table_name'}) {
            $table_idx = $i;
            $table = $tables[$i];
            last;
        }
    }
}
$table ||= $tables[$table_idx];
$table || error($text{'chain_notable'});

my @chains = split(/\0/, $in{'d'} || "");
my %seen;
@chains = grep { defined($_) && $_ ne '' && !$seen{$_}++ } @chains;
@chains || error($text{'delete_chains_enone'});

foreach my $c (@chains) {
    $table->{'chains'}->{$c} || error(text('delete_chains_nochain', $c));
}

my %delete = map { $_ => 1 } @chains;
my @refs = grep {
    !$delete{$_->{'chain'}} &&
    (($_->{'jump'} && $delete{$_->{'jump'}}) ||
     ($_->{'goto'} && $delete{$_->{'goto'}}))
} @{$table->{'rules'}};
@refs && error(text('delete_chains_inuse', scalar(@refs)));

@{$table->{'rules'}} = grep { !$delete{$_->{'chain'}} } @{$table->{'rules'}};
foreach my $c (@chains) {
    delete($table->{'chains'}->{$c});
}

my $err = save_table_configuration($table, @tables);
error(text('delete_chains_failed', $err)) if ($err);
webmin_log("delete", "chains", scalar(@chains),
            { 'table' => $table->{'name'},
              'family' => $table->{'family'} });
redirect("index.cgi?table_family=".urlize($table->{'family'}).
         "&table_name=".urlize($table->{'name'}));
