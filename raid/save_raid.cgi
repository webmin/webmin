#!/usr/local/bin/perl
# save_raid.cgi
# Activate, deactivate, delete or make a filesystem on a raid set

require './raid-lib.pl';
&ReadParse();
$conf = &get_raidtab();
$in{'idx'} eq '' && &error($text{'delete_eidx'});
$old = $conf->[$in{'idx'}];

if ($in{'delete'}) {
	# Delete a RAID set
	if (!$in{'confirm'}) {
		# Ask first!
		&ui_print_header(undef, $text{'delete_title'}, "");

		print "<center>\n";
		print &ui_form_start("save_raid.cgi");
		print &ui_hidden("delete", 1);
		print &ui_hidden("idx", $in{'idx'});
		print &text('delete_rusure', "<tt>$old->{'value'}</tt>",
			    &nice_size($old->{'size'}*1024)),"<p>\n";
		print &ui_form_end([ [ "confirm", $text{'delete_ok'} ] ]);
		print "</center>\n";

		&ui_print_footer("", $text{'index_return'});
		}
	else {
		# Really do it
		&lock_raid_files();
		&unmake_raid($old);
		&delete_raid($old);
		&unlock_raid_files();
		&webmin_log("delete", undef, $old->{'value'});
		&redirect("");
		}
	}
elsif ($in{'mkfs'}) {
	# Display form for making a filesystem
	&ui_print_header(undef, $text{'mkfs_title'}, "");

	print &text('mkfs_header2', "<tt>$old->{'value'}</tt>",
			  $in{'fs'}),"<br>\n";
	print &ui_form_start("mkfs.cgi");
	print &ui_hidden("idx", $in{'idx'});
	print &ui_hidden("fs", $in{'fs'});
	print &ui_table_start($text{'mkfs_options'}, undef, 4);
	&fdisk::mkfs_options($in{'fs'});
	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'create'} ] ]);

	&ui_print_footer("", $text{'index_return'});
	}
elsif ($in{'start'}) {
	# Start raid device
	&activate_raid($old);
	&webmin_log("start", undef, $old->{'value'});
	&redirect("");
	}
elsif ($in{'stop'}) {
	# Stop raid device
	&deactivate_raid($old);
	&webmin_log("stop", undef, $old->{'value'});
	&redirect("");
	}
elsif ($in{'add'}) {
	# Add a disk to a RAID set
	&lock_raid_files();
	&add_partition($old, $in{'disk'});
	&unlock_raid_files();
	&webmin_log("add", undef, $old->{'value'}, { 'disk' => $in{'disk'} } );
	&redirect("");
	}
elsif ($in{'grow'}) {
	# Grow the array
	&lock_raid_files();
	&grow($old, $in{'ndisk_grow'});
	&unlock_raid_files();
	&webmin_log("grow", undef, $old->{'value'}, { 'disk' => $in{'ndisk_grow'} } );
	&redirect("");
	}
elsif ($in{'remove'}) {
	# Remove a disk from a RAID set
	if (!$in{'confirm'}) {
		# Ask first!
		&ui_print_header(undef, $text{'remove_title'}, "");

		print "<center>\n";
		print &ui_form_start("save_raid.cgi");
		print &ui_hidden("remove", 1);
		print &ui_hidden("rdisk", $in{'rdisk'});
		print &ui_hidden("idx", $in{'idx'});
		print &text('remove_rusure', "<tt>$old->{'value'}</tt>",
			"<tt>$in{'rdisk'}</tt>"),"<p>\n";
		print &ui_form_end([ [ "confirm", $text{'remove_ok'} ] ]);
		print "</center>\n";

		&ui_print_footer("", $text{'index_return'});
		}
	else {
		# Really do it
		&lock_raid_files();
		&remove_partition($old, $in{'rdisk'});
		&unlock_raid_files();
		&webmin_log("remove", undef, $old->{'value'}, { 'disk' => $in{'rdisk'} } );
		&redirect("");
		}
	}
elsif ($in{'remove_det'}) {
	# Remove detached disk(s) from a RAID set
	&lock_raid_files();
	&remove_detached($old);
	&unlock_raid_files();
	&redirect("");
	}
elsif ($in{'replace'}) {
	# Hot replace a data disk with a spare disk
	&lock_raid_files();
	&replace_partition($old, $in{'replacedisk'}, $in{'replacesparedisk'});
	&unlock_raid_files();
	&webmin_log("replace", undef, $old->{'value'}, { 'disk' => $in{'replacedisk'} , 'disk2' => $in{'replacesparedisk'} } );
	&redirect("");
	}
elsif ($in{'convert_to_raid6'}) {
	# Convert RAID level to RAID6
	&lock_raid_files();
	&convert_raid($old, $in{'oldcount'}, $in{'ndisk_convert'}, 6);
	&unlock_raid_files();
	&webmin_log("convert_to_raid6", undef, $old->{'value'}, { 'disk' => $in{'ndisk_convert'} } );
	&redirect("");
	}
elsif ($in{'convert_to_raid5'}) {
	# Convert RAID level to RAID5
	&lock_raid_files();
	&convert_raid($old, $in{'oldcount'}, undef, 5);
	&unlock_raid_files();
	&webmin_log("convert_to_raid5", undef, $old->{'value'}, undef );
	&redirect("");
	}
elsif ($in{'mount'} || $in{'mountswap'}) {
	# Re-direct to mount module
	$type = $in{'mountswap'} ? "swap" :
		$config{'lasttype_'.$old->{'value'}} || "ext2";
	&redirect("../mount/edit_mount.cgi?newdev=$old->{'value'}&".
		  "newdir=".&urlize($in{'newdir'})."&".
		  "type=".$type);
	}

