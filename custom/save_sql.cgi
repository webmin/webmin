#!/usr/local/bin/perl
# Save, create or delete an SQL command

require './custom-lib.pl';
&ReadParse();

$access{'edit'} || &error($text{'save_ecannot'});
if ($in{'delete'}) {
	$cmd = &get_command($in{'id'}, $in{'idx'});
	&delete_command($cmd);
	&webmin_log("delete", "command", $cmd->{'id'}, $cmd);
	&redirect("");
	}
elsif ($in{'clone'}) {
	&redirect("edit_sql.cgi?id=$in{'id'}&idx=$in{'idx'}&clone=1&new=1");
	}
else {
	&error_setup($text{'sql_err'});
	if (!$in{'new'}) {
		$cmd = &get_command($in{'id'}, $in{'idx'});
		}
	else {
		$cmd = { 'id' => time() };
		}

	# parse and validate inputs
	$cmd->{'desc'} = $in{'desc'};
	$in{'order_def'} || $in{'order'} =~ /^\-?(\d+)$/ ||
		&error($text{'save_eorder'});
	$cmd->{'order'} = $in{'order_def'} ? 0 : int($in{'order'});
	$in{'html'} =~ s/\r//g;
        $in{'html'} =~ s/\n*/\n/;
	$cmd->{'html'} = $in{'html'};
	$cmd->{'type'} = $in{'type'};
	$in{'db'} =~ /^\S+$/ || &error($text{'sql_edb'});
	$cmd->{'db'} = $in{'db'};
	$in{'sql'} =~ /\S/ || &error($text{'sql_esql'});
	$in{'sql'} =~ s/\r//g;
	$cmd->{'sql'} = $in{'sql'};
	$cmd->{'user'} = $in{'dbuser'};
	$cmd->{'pass'} = $in{'dbpass'};
	if ($in{'host_def'}) {
		delete($cmd->{'host'});
		}
	else {
		&to_ipaddress($in{'host'}) ||
			&error($text{'sql_ehost'});
		$cmd->{'host'} = $in{'host'};
		}
	&parse_params_inputs($cmd);
	&save_command($cmd);
	&webmin_log($in{'new'} ? "create" : "modify", "command",
		    $cmd->{'id'}, $cmd);

	if ($in{'new'} && $access{'cmds'} ne '*') {
		$access{'cmds'} .= " ".$cmd->{'id'};
		&save_module_acl(\%access);
		}
	&redirect("");
	}

