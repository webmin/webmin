#!/usr/local/bin/perl
# save_raid.cgi
# Activate, deactivate, delete or make a filesystem on a raid set

require './raid-lib.pl';
&ReadParse();
$conf = &get_raidtab();
$old = $conf->[$in{'idx'}];

if ($in{'delete'}) {
	# Delete a RAID set
	&lock_raid_files();
	&unmake_raid($old);
	&delete_raid($old);
	&unlock_raid_files();
	&webmin_log("delete", undef, $old->{'value'});
	&redirect("");
	}
elsif ($in{'mkfs'}) {
	# Display form for making a filesystem
	&ui_print_header(undef, $text{'mkfs_title'}, "");

	print "<p>",&text('mkfs_header2', "<tt>$old->{'value'}</tt>",
			  $in{'fs'}),"<br>\n";
	print "<form action=mkfs.cgi>\n";
	print "<input type=hidden name=idx value='$in{'idx'}'>\n";
	print "<input type=hidden name=fs value='$in{'fs'}'>\n";
	print "<table border width=100%>\n";
	print "<tr $tb><td><b>$text{'mkfs_options'}</b></td> </tr>\n";
	print "<tr $cb><td><table width=100%>\n";
	&foreign_call("fdisk", "mkfs_options", $in{'fs'});
	print "</table></td></tr></table>\n";
	print "<input type=submit value='$text{'create'}'></form>\n";

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
elsif ($in{'remove'}) {
	# Remove a disk from a RAID set
	&lock_raid_files();
	&remove_partition($old, $in{'rdisk'});
	&unlock_raid_files();
	&webmin_log("remove", undef, $old->{'value'}, { 'disk' => $in{'rdisk'} } );
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

