#!/usr/local/bin/perl
# Create, update or delete a storage daemon

require './bacula-backup-lib.pl';
&ReadParse();

if ($in{'status'}) {
	# Go to status page
	&redirect("storagestatus_form.cgi?storage=".&urlize($in{'old'}));
	exit;
	}

$conf = &get_director_config();
$parent = &get_director_config_parent();
@storages = &find("Storage", $conf);

if (!$in{'new'}) {
	$storage = &find_by("Name", $in{'old'}, \@storages);
        $storage || &error($text{'storage_egone'});
	}
else {
	$storage = { 'type' => 1,
		     'name' => 'Storage',
		     'members' => [ ] };
	}

&lock_file($parent->{'file'});
if ($in{'delete'}) {
	# Just delete this one
	$name = &find_value("Name", $storage->{'members'});
	$child = &find_dependency("Storage", $name, [ "Job", "JobDefs" ], $conf);
	$child && &error(&text('storage_echild', $child));
	&save_directive($conf, $parent, $storage, undef, 0);
	}
else {
	# Validate and store inputs
	&error_setup($text{'storage_err'});
	$in{'name'} =~ /\S/ || &error($text{'storage_ename'});
	if ($in{'new'} || $in{'name'} ne $in{'old'}) {
		$clash = &find_by("Name", $in{'name'}, \@storages);
		$clash && &error($text{'storage_eclash'});
		}
	&save_directive($conf, $storage, "Name", $in{'name'}, 1);

	$in{'pass'} || &error($text{'storage_epass'});
	&save_directive($conf, $storage, "Password", $in{'pass'}, 1);

	&to_ipaddress($in{'address'}) || &to_ip6address($in{'address'}) ||
		&error($text{'storage_eaddress'});
	&save_directive($conf, $storage, "Address", $in{'address'}, 1);

	$in{'port'} =~ /^\d+$/ && $in{'port'} > 0 && $in{'port'} < 65536 ||
		&error($text{'storage_eport'});
	&save_directive($conf, $storage, "SDPort", $in{'port'}, 1);

	$in{'device'} ||= $in{'other'};
	$in{'device'} =~ /\S/ || &error($text{'storage_edevice'});
	&save_directive($conf, $storage, "Device", $in{'device'}, 1);

	$in{'media'} =~ /\S/ || &error($text{'storage_emedia'});
	&save_directive($conf, $storage, "Media Type", $in{'media'}, 1);

	$in{'maxjobs'} =~ /\S/ || &error($text{'storage_emaxjobs'});
	&save_directive($conf, $storage, "Maximum Concurrent Jobs", $in{'maxjobs'}, 1);

	# SSL directives
	&parse_tls_directives($conf, $storage, 1);

	# Create or update
	if ($in{'new'}) {
		&save_directive($conf, $parent, undef, $storage, 0);
		}
	}

&flush_file_lines();
&unlock_file($parent->{'file'});
&auto_apply_configuration();
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "storage", $in{'old'} || $in{'name'});
&redirect("list_storages.cgi");

