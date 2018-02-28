#!/usr/local/bin/perl
# newchain.cgi
# Create a new user-defined chain

require './firewall-lib.pl';
&ReadParse();
if (&get_ipvx_version() == 6) {
	require './firewall6-lib.pl';
	}
else {
	require './firewall4-lib.pl';
	}
$access{'newchain'} || &error($text{'new_ecannot'});
@tables = &get_iptables_save();
$table = $tables[$in{'table'}];
&can_edit_table($table->{'name'}) || &error($text{'etable'});
&error_setup($text{'new_err'});
&lock_file($ipvx_save);
$in{'chain'} =~ /^\S+$/ || &error($text{'new_ename'});
$table->{'defaults'}->{$in{'chain'}} && &error($text{'new_etaken'});
$table->{'defaults'}->{$in{'chain'}} = '-';
&run_before_command();
&save_table($table);
&run_after_command();
&copy_to_cluster();
&unlock_file($ipvx_save);
&webmin_log("create", "chain", undef, { 'chain' => $in{'chain'},
					'table' => $table->{'name'} });

&redirect("index.cgi?version=${ipvx_arg}&table=$in{'table'}");

