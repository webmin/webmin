#!/usr/bin/perl
# delete_chain.cgi
# Delete an existing nftables chain

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'delete_chain_err'});
assert_acl('delete');

my @tables = get_nftables_save();
my $table = $tables[$in{'table'}];
$table || error($text{'chain_notable'});
assert_table_acl($table);

my $chain = $table->{'chains'}->{$in{'chain'}};
$chain || error($text{'chain_nochain'});

my @refs = grep {
	($_->{'jump'} && $_->{'jump'} eq $in{'chain'}) ||
	($_->{'goto'} && $_->{'goto'} eq $in{'chain'})
} @{$table->{'rules'}};
@refs && error(text('delete_chain_inuse', $in{'chain'}, scalar(@refs)));

@{$table->{'rules'}} = grep { $_->{'chain'} ne $in{'chain'} } @{$table->{'rules'}};
delete($table->{'chains'}->{$in{'chain'}});

my $err = save_table_configuration($table, @tables);
error(text('delete_chain_failed', $err)) if ($err);
webmin_log("delete", "chain", $in{'chain'},
			{ 'table' => $table->{'name'}, 'family' => $table->{'family'} });
redirect("index.cgi?table=$in{'table'}");
