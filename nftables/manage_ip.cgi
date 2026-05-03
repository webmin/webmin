#!/usr/bin/perl
# manage_ip.cgi
# Quickly allow or block an IP/CIDR in the selected table

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
assert_acl('quick');

my $action = $in{'allow'} ? 'allow' : $in{'block'} ? 'block' : '';
error_setup($action eq 'allow' ? $text{'quick_allow_err'} :
	    $text{'quick_block_err'});

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
else {
	$table = $tables[$table_idx];
	}
$table || error($text{'quick_etable'});
assert_table_acl($table);

my $err = add_quick_ip_rule($table, $in{'ip'}, $action);
error($err) if ($err);

$err = save_table_configuration($table, @tables);
error(text('quick_failed', $err)) if ($err);

# Quick allow/block is expected to affect the live firewall immediately.
$err = apply_restore();
error(text('quick_failed', $err)) if ($err);

webmin_log($action, "ip", $in{'ip'},
	   { 'table' => $table->{'name'}, 'family' => $table->{'family'} });
redirect("index.cgi?table_family=".urlize($table->{'family'}).
	 "&table_name=".urlize($table->{'name'}));
