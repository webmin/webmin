#!/usr/local/bin/perl
# Create, update or delete a device device

require './bacula-backup-lib.pl';
&ReadParse();

$conf = &get_storage_config();
$parent = &get_storage_config_parent();
@devices = &find("Device", $conf);

if (!$in{'new'}) {
	$device = &find_by("Name", $in{'old'}, \@devices);
        $device || &error($text{'device_egone'});
	}
else {
	$device = { 'type' => 1,
		     'name' => 'Device',
		     'members' => [ ] };
	}

&lock_file($parent->{'file'});
if ($in{'delete'}) {
	# Just delete this one
	$name = &find_value("Name", $device->{'members'});
	$child = &find_dependency("Device", $name, [ "Job", "JobDefs" ], $conf);
	$child && &error(&text('device_echild', $child));
	&save_directive($conf, $parent, $device, undef, 0);
	}
else {
	# Validate and store inputs
	&error_setup($text{'device_err'});
	$in{'name'} =~ /\S/ || &error($text{'device_ename'});
	if ($in{'new'} || $in{'name'} ne $in{'old'}) {
		$clash = &find_by("Name", $in{'name'}, \@devices);
		$clash && &error($text{'device_eclash'});
		}
	&save_directive($conf, $device, "Name", $in{'name'}, 1);

	-r $in{'device'} || -d $in{'device'} || &error($text{'device_edevice'});
	&save_directive($conf, $device, "Archive Device", $in{'device'}, 1);

	$in{'media'} =~ /\S/ || &error($text{'device_emedia'});
	&save_directive($conf, $device, "Media Type", $in{'media'}, 1);

	# Save yes/no options
	&save_directive($conf, $device, "LabelMedia", $in{'label'} || undef, 1);
	&save_directive($conf, $device, "Random Access", $in{'random'} || undef, 1);
	&save_directive($conf, $device, "AutomaticMount", $in{'auto'} || undef, 1);
	&save_directive($conf, $device, "RemovableMedia", $in{'removable'} || undef, 1);
	&save_directive($conf, $device, "AlwaysOpen", $in{'always'} || undef, 1);

	# Create or update
	if ($in{'new'}) {
		&save_directive($conf, $parent, undef, $device, 0);
		}
	}

&flush_file_lines();
&unlock_file($parent->{'file'});
&auto_apply_configuration();
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "device", $in{'old'} || $in{'name'});
&redirect("list_devices.cgi");

