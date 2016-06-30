#!/usr/local/bin/perl
# move.cgi
# Swap two rules in some chain

require './firewall6-lib.pl';
&ReadParse();
&lock_file($ip6tables_save_file);
@tables = &get_ip6tables_save();
$table = $tables[$in{'table'}];
&can_edit_table($table->{'name'}) || &error($text{'etable'});
$r = $table->{'rules'};
$c = $r->[$in{'idx'}]->{'chain'};
@rules = grep { lc($_->{'chain'}) eq lc($c) } @$r;
$pos = &indexof($r->[$in{'idx'}], @rules);
&can_jump($r->[$in{'idx'}]) || &error($text{'ejump'});
if ($in{'down'}) {
	# Swap with next rule in this chain
	$nxt = $rules[$pos+1]->{'index'};
	&can_jump($r->[$nxt]) || &error($text{'ejump'});
	($r->[$in{'idx'}], $r->[$nxt]) = ($r->[$nxt], $r->[$in{'idx'}]);
	}
else {
	# Swap with previous rule in this chain
	$prv = $rules[$pos-1]->{'index'};
	&can_jump($r->[$prv]) || &error($text{'ejump'});
	($r->[$in{'idx'}], $r->[$prv]) = ($r->[$prv], $r->[$in{'idx'}]);
	}
&run_before_command();
&save_table($table);
&run_after_command();
&copy_to_cluster();
&unlock_file($ip6tables_save_file);
&webmin_log("move", "rule", undef, { 'table' => $table->{'name'},
				     'chain' => $r->[$in{'idx'}]->{'chain'} });
&redirect("index.cgi?table=$in{'table'}");

