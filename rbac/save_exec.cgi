#!/usr/local/bin/perl
# Create, update or delete one RBAC execution profile

require './rbac-lib.pl';
$access{'execs'} || &error($text{'execs_ecannot'});
&ReadParse();
&error_setup($text{'exec_err'});

&lock_rbac_files();
$execs = &list_exec_attrs();
if (!$in{'new'}) {
	$exec = $execs->[$in{'idx'}];
	$logname = $exec->{'name'};
	}
else {
	$exec = { 'attr' => { } };
	$logname = $in{'name'};
	}

if ($in{'delete'}) {
	# Just delete this execution profile
	&delete_exec_attr($exec);
	}
else {
	# Validate and store inputs
	$exec->{'name'} = $in{'name'};
	$exec->{'policy'} = $in{'policy'};
	if ($in{'id_def'}) {
		$exec->{'id'} = '*';
		}
	else {
		$in{'id'} =~ /^\/\S+/ || &error($text{'exec_eid'});
		$exec->{'id'} = $in{'id'};
		}
	$exec->{'cmd'} ||= 'cmd';
	foreach $i ("uid", "gid", "euid", "egid") {
		if ($in{$i."_def"}) {
			delete($exec->{'attr'}->{$i});
			}
		else {
			$in{$i} =~ /\S/ || &error($text{'exec_err'.$i});
			$exec->{'attr'}->{$i} = $in{$i};
			}
		}

	# Save or update execution profile
	if ($in{'new'}) {
		&create_exec_attr($exec);
		}
	else {
		&modify_exec_attr($exec);
		}
	}

&unlock_rbac_files();
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "exec", $logname, $exec);
&redirect("list_execs.cgi");

