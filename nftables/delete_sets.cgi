#!/usr/bin/perl
# delete_sets.cgi
# Delete selected nftables sets

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'delete_sets_err'});
assert_acl('delete');

my @tables = get_nftables_save();
my $table_idx = $in{'table'};
my $table;
if (defined($in{'table_family'}) && defined($in{'table_name'})) {
	for (my $i = 0 ; $i <= $#tables ; $i++) {
		if ($tables[$i]->{'family'} eq $in{'table_family'} &&
			$tables[$i]->{'name'} eq $in{'table_name'})
		{
			$table_idx = $i;
			$table = $tables[$i];
			last;
			}
		}
	}
$table ||= $tables[$table_idx];
$table || error($text{'set_notable'});
assert_table_acl($table);

my @sets = split(/\0/, $in{'s'} || "");
my %seen;
@sets = grep { defined($_) && $_ ne '' && !$seen{$_}++ } @sets;
@sets || error($text{'delete_sets_enone'});

foreach my $s (@sets) {
	$table->{'sets'}->{$s} || error(text('delete_sets_noset', $s));
	}

my $refs = 0;
foreach my $s (@sets) {
	$refs += count_set_references($table, $s);
	}
$refs && error(text('delete_sets_inuse', $refs));

foreach my $s (@sets) {
	delete($table->{'sets'}->{$s});
	}

my $err = save_table_configuration($table, @tables);
error(text('delete_sets_failed', $err)) if ($err);
webmin_log(
	"delete", "sets",
	scalar(@sets),
	{
		'table' => $table->{'name'},
		'family' => $table->{'family'}
	}
);
redirect("index.cgi?table_family=".
	    urlize($table->{'family'}).
	    "&table_name=".
	    urlize($table->{'name'}).
	    "&view=sets");
