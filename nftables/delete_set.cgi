#!/usr/bin/perl
# delete_set.cgi
# Delete an existing nftables set

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'delete_set_err'});
assert_acl('delete');

my @tables = get_nftables_save();
my $table = $tables[$in{'table'}];
$table || error($text{'set_notable'});
assert_table_acl($table);

my $set = $table->{'sets'}->{$in{'set'}};
$set || error($text{'set_noset'});

my $refs = count_set_references($table, $in{'set'});
$refs && error(text('delete_set_inuse', $in{'set'}, $refs));

delete($table->{'sets'}->{$in{'set'}});

my $err = save_table_configuration($table, @tables);
error(text('delete_set_failed', $err)) if ($err);
webmin_log("delete", "set", $in{'set'},
	{'table' => $table->{'name'}, 'family' => $table->{'family'}});
redirect("index.cgi?table=$in{'table'}&view=sets");
