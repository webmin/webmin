#!/usr/bin/perl
# manage_port.cgi
# Quickly allow a port or service in the selected table

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();

my $mode = $in{'mode'} || '';
assert_quick_acl($mode eq 'service' ? 'service' : 'port');
error_setup(
	$mode eq 'service' ? $text{'quick_service_err'} : $text{'quick_port_err'}
);

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

my $err;
my $service = $in{'service'};
if (!defined($service) || $service eq '') {
	$service = $in{'service_text'};
	}
if ($mode eq 'service') {
	$err = add_quick_service_rule($table, $service);
	}
else {
	$err = add_quick_port_rule($table, $in{'port'}, $in{'proto'});
	}
error($err) if ($err);

$err = save_table_configuration($table, @tables);
error(text('quick_failed', $err)) if ($err);

# Quick allow actions are expected to affect the live firewall immediately.
$err = apply_restore();
error(text('quick_failed', $err)) if ($err);

webmin_log(
	"allow",
	$mode eq 'service' ? "service" : "port",
	$mode eq 'service' ? $service : $in{'port'},
	{'table' => $table->{'name'}, 'family' => $table->{'family'}}
);
my $redir = "index.cgi?table_family=".
	    urlize($table->{'family'}).
	    "&table_name=".
	    urlize($table->{'name'});
$redir .= "&view=".urlize($in{'view'})
	if (($in{'view'} || '') =~ /^(chains|sets)$/);
redirect($redir);
