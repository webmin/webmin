#!/usr/local/bin/perl
# newchain.cgi
# Create a new user-defined chain

require './firewall6-lib.pl';
$access{'newchain'} || &error($text{'new_ecannot'});
&ReadParse();
@tables = &get_ip6tables_save();
$table = $tables[$in{'table'}];
&can_edit_table($table->{'name'}) || &error($text{'etable'});
&error_setup($text{'new_err'});
&lock_file($ip6tables_save_file);
$in{'chain'} =~ /^\S+$/ || &error($text{'new_ename'});
$table->{'defaults'}->{$in{'chain'}} && &error($text{'new_etaken'});
$table->{'defaults'}->{$in{'chain'}} = '-';
&run_before_command();
&save_table($table);
&run_after_command();
&copy_to_cluster();
&unlock_file($ip6tables_save_file);
&webmin_log("create", "chain", undef, { 'chain' => $in{'chain'},
					'table' => $table->{'name'} });

&redirect("index.cgi?table=$in{'table'}");

