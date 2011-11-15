#!/usr/local/bin/perl
# save_cmd.cgi
# Save, create or delete a custom command

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
	&redirect("edit_cmd.cgi?id=$in{'id'}&idx=$in{'idx'}&clone=1&new=1");
	}
else {
	&error_setup($text{'save_err'});
	if (!$in{'new'}) {
		$cmd = &get_command($in{'id'}, $in{'idx'});
		}
	else {
		$cmd = { 'id' => time() };
		}

	# parse and validate inputs
	$in{'cmd'} =~ s/\r//g;
	$in{'cmd'} =~ s/\n/ /g;
	$in{'cmd'} =~ /\S/ || &error($text{'save_ecmd'});
	if ($in{'dir_def'}) {
		$cmd->{'cmd'} = $in{'cmd'};
		}
	else {
		$in{'dir'} =~ /^\S+$/ || &error($text{'save_edir'});
		$cmd->{'cmd'} = "cd $in{'dir'} ; $in{'cmd'}";
		}
	$in{'order_def'} || $in{'order'} =~ /^\-?(\d+)$/ ||
		&error($text{'save_eorder'});
	$in{'timeout_def'} || $in{'timeout'} =~ /^(\d+)$/ ||
		&error($text{'save_etimeout'});
	$cmd->{'desc'} = $in{'desc'};
	$in{'html'} =~ s/\r//g;
	$in{'html'} =~ s/\n*/\n/;
	$cmd->{'html'} = $in{'html'};
	if (&supports_users()) {
		$in{'user_def'} || (@u = getpwnam($in{'user'})) ||
			&error($text{'save_euser'});
		$cmd->{'user'} = $in{'user_def'} ? "*" : $in{'user'};
		$cmd->{'su'} = $in{'su'};
		}
	else {
		$cmd->{'user'} = 'root';
		}
	$cmd->{'raw'} = $in{'raw'};
	$cmd->{'order'} = $in{'order_def'} ? 0 : int($in{'order'});
	$cmd->{'timeout'} = $in{'timeout_def'} ? 0 : int($in{'timeout'});
	$cmd->{'clear'} = $in{'clear'};
	if ($in{'format_def'} == 0) {
		delete($cmd->{'format'});
		}
	elsif ($in{'format_def'} == 2) {
		$cmd->{'format'} = 'redirect';
		}
	elsif ($in{'format_def'} == 3) {
		$cmd->{'format'} = 'form';
		}
	else {
		$in{'format'} =~ /^[a-z0-9\.\_\-]+\/[a-z0-9\.\_\-]+/i ||
			&error($text{'save_eformat'});
		$cmd->{'format'} = $in{'format'};
		}
	$cmd->{'noshow'} = $in{'noshow'};
	$cmd->{'usermin'} = $in{'usermin'};
	@hosts = split(/\0/, $in{'hosts'});
	if (!@hosts || (@hosts == 1 && $hosts[0] eq "0")) {
		delete($cmd->{'hosts'});
		}
	else {
		$cmd->{'usermin'} && &error($text{'save_eusermin'});
		$cmd->{'hosts'} = \@hosts;
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

