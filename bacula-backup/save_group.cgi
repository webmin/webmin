#!/usr/local/bin/perl
# Create, update or delete a special client used as a group

require './bacula-backup-lib.pl';
&ReadParse();

$conf = &get_director_config();
$parent = &get_director_config_parent();
@clients = &find("Client", $conf);

# Get node group
@nodegroups = &list_node_groups();
$ngname = $in{'old'} || $in{'new'};
($nodegroup) = grep { $_->{'name'} eq $ngname } @nodegroups;

if (!$in{'new'}) {
	$client = &find_by("Name", "ocgroup_".$in{'old'}, \@clients);
        $client || &error($text{'group_egone'});
	}
else {
	$client = { 'type' => 1,
		     'name' => 'Client',
		     'members' => [ ] };
	}

&lock_file($parent->{'file'});
if ($in{'delete'}) {
	# Just delete this one
	# XXX
	#$name = &find_value("Name", $client->{'members'});
	#$child = &find_dependency("Client", $name, [ "Job", "JobDefs" ], $conf);
	#$child && &error(&text('client_echild', $child));
	&save_directive($conf, $parent, $client, undef, 0);
	}
else {
	# Validate and store inputs
	&error_setup($text{'group_err'});
	if ($in{'new'}) {
		&save_directive($conf, $client, "Name", "ocgroup_".$in{'new'}, 1);
		$clash = &find_by("Name", "ocgroup_".$in{'name'}, \@clients);
		$clash && &error($text{'group_eclash'});
		}

	&save_directive($conf, $client, "Address", "localhost", 1);

	$in{'pass'} || &error($text{'client_epass'});
	&save_directive($conf, $client, "Password", $in{'pass'}, 1);

	$in{'port'} =~ /^\d+$/ && $in{'port'} > 0 && $in{'port'} < 65536 ||
		&error($text{'client_eport'});
	&save_directive($conf, $client, "FDPort", $in{'port'}, 1);

	&save_directive($conf, $client, "Catalog", $in{'catalog'}, 1);

	&save_directive($conf, $client, "AutoPrune", $in{'prune'} || undef, 1);

	$fileret = &parse_period_input("fileret");
	$fileret || &error($text{'client_efileret'});
	&save_directive($conf, $client, "File Retention", $fileret, 1);

	$jobret = &parse_period_input("jobret");
	$jobret || &error($text{'client_ejobret'});
	&save_directive($conf, $client, "Job Retention", $jobret, 1);

	# Create or update
	if ($in{'new'}) {
		&save_directive($conf, $parent, undef, $client, 0);
		}
	}

if ($nodegroup) {
	# Force update to all dependent clients
	&sync_group_clients($nodegroup);
	}

&flush_file_lines();
&unlock_file($parent->{'file'});
&auto_apply_configuration();
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "group", $ngname);
&redirect("list_groups.cgi");

