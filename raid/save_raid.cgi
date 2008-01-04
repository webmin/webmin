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

