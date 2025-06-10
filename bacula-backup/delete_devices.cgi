#!/usr/local/bin/perl
# Delete multiple storage devices from the SD config

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_storage_config();
$parent = &get_storage_config_parent();
@devices = &find("Device", $conf);

&error_setup($text{'devices_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'filesets_ednone'});

&lock_file($parent->{'file'});
foreach $d (@d) {
	$device = &find_by("Name", $d, \@devices);
	if ($device) {
		&save_directive($conf, $parent, $device, undef, 0);
		}
	}
&flush_file_lines($parent->{'file'});
&unlock_file($parent->{'file'});
&webmin_log("delete", "devices", scalar(@d));
&redirect("list_devices.cgi");

