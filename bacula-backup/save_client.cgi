#!/usr/local/bin/perl
# Create, update or delete a client

require './bacula-backup-lib.pl';
&ReadParse();

if ($in{'status'}) {
	# Go to status page
	&redirect("clientstatus_form.cgi?client=".&urlize($in{'old'}));
	exit;
	}

$conf = &get_director_config();
$parent = &get_director_config_parent();
@clients = &find("Client", $conf);

if (!$in{'new'}) {
	$client = &find_by("Name", $in{'old'}, \@clients);
        $client || &error($text{'client_egone'});
	}
else {
	$client = { 'type' => 1,
		     'name' => 'Client',
		     'members' => [ ] };
	}

&lock_file($parent->{'file'});
if ($in{'delete'}) {
	# Just delete this one
	$name = &find_value("Name", $client->{'members'});
	$child = &find_dependency("Client", $name, [ "Job", "JobDefs" ], $conf);
	$child && &error(&text('client_echild', $child));
	&save_directive($conf, $parent, $client, undef, 0);
	}
else {
	# Validate and store inputs
	&error_setup($text{'client_err'});
	$in{'name'} =~ /^\S+$/ || &error($text{'client_ename'});
	if ($in{'new'} || $in{'name'} ne $in{'old'}) {
		$clash = &find_by("Name", $in{'name'}, \@clients);
		$clash && &error($text{'client_eclash'});
		}
	&save_directive($conf, $client, "Name", $in{'name'}, 1);

	$in{'pass'} || &error($text{'client_epass'});
	&save_directive($conf, $client, "Password", $in{'pass'}, 1);

	&to_ipaddress($in{'address'}) || &to_ip6address($in{'address'}) ||
		&error($text{'client_eaddress'});
	&save_directive($conf, $client, "Address", $in{'address'}, 1);

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

	# Save SSL options
	&parse_tls_directives($conf, $client, 1);

	# Create or update
	if ($in{'new'}) {
		&save_directive($conf, $parent, undef, $client, 0);
		}
	}

&flush_file_lines();
&unlock_file($parent->{'file'});
&auto_apply_configuration();
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "client", $in{'old'} || $in{'name'});
&redirect("list_clients.cgi");

