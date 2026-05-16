#!/usr/bin/perl
# manage_forward.cgi
# Quickly add a simple port forward in the selected table

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
assert_quick_acl('forward');
error_setup($text{'quick_forward_err'});

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
else {
	$table = $tables[$table_idx];
	}
$table || error($text{'quick_etable'});
assert_table_acl($table);

my $err = add_quick_forward_rule(
	$table,
	$in{'src_port'},
	$in{'proto'},
	$in{'dst_port'},
	$in{'dst_addr'}
);
error($err) if ($err);

$err = save_table_configuration($table, @tables);
error(text('quick_failed', $err)) if ($err);

# Quick forwarding is expected to affect the live firewall immediately.
$err = apply_restore();
error(text('quick_failed', $err)) if ($err);

webmin_log(
	"create",
	"forward",
	$in{'src_port'},
	{'table' => $table->{'name'}, 'family' => $table->{'family'}}
);
my $redir = "index.cgi?table_family=".
	    urlize($table->{'family'}).
	    "&table_name=".
	    urlize($table->{'name'});
$redir .= "&view=".urlize($in{'view'})
	if (($in{'view'} || '') =~ /^(chains|sets)$/);
redirect($redir);
