#!/usr/local/bin/perl
# save_part.cgi
# Save changes to an existing or new partition

require './fdisk-lib.pl';
&error_setup($text{'save_err'});
&ReadParse();

@dlist = &list_disks_partitions();
$dinfo = $dlist[$in{'disk'}];
&can_edit_disk($dinfo->{'device'}) ||
	&error($text{'save_ecannot'});
@plist = @{$dinfo->{'parts'}};
if ($in{'delete'} && $in{'confirm'}) {
	# deleting a partition
	$pinfo = $plist[$in{'part'}];
	&delete_partition($dinfo->{'device'}, $pinfo->{'number'});
	&webmin_log("delete", "part", $dinfo->{'device'}, \%in);
	&redirect("edit_disk.cgi?device=$dinfo->{'device'}");
	}
elsif ($in{'delete'}) {
	# Ask the user if he really wants to delete the partition
	&ui_print_header(undef, $text{'delete_title'}, "");

	$pinfo = $plist[$in{'part'}];
	$dname = &mount::device_name($pinfo->{'device'});
	print "<center><form action=save_part.cgi>\n";
	print "<input type=hidden name=disk value='$in{'disk'}'>\n";
	print "<input type=hidden name=part value='$in{'part'}'>\n";
	print "<input type=hidden name=delete value=1>\n";
	print "<b>",&text('delete_rusure', $dname,
			  "<tt>$pinfo->{'device'}</tt>"),"</b><p>\n";
	print "<input type=submit name=confirm value='$text{'delete_ok'}'>\n";
	print "</form></center>\n";

	&ui_print_footer("edit_disk.cgi?device=$dinfo->{'device'}",
			 $text{'disk_return'});
	}
elsif (!$in{'new'}) {
	# Changing existing partition type and label
	$pinfo = $plist[$in{'part'}];
	if ($pinfo->{'edittype'}) {
		&change_type($dinfo->{'device'}, $pinfo->{'number'},
			     $in{'type'});
		$pinfo->{'type'} = $in{'type'};
		}
	if (defined($in{'label'}) && &supports_label($pinfo)) {
		&set_label($pinfo->{'device'}, $in{'label'});
		}
	if (defined($in{'name'}) && &supports_name($dinfo)) {
		&set_name($dinfo, $pinfo, $in{'name'});
		}
	&webmin_log("modify", "part", $dinfo->{'device'}, \%in);
	&redirect("edit_disk.cgi?device=$dinfo->{'device'}");
	}
else {
	# Adding new partition
	$in{start} =~ /^\d+$/ ||
		&error(&text('save_estart', $in{'start'}));
	$in{end} =~ /^\d+$/ ||
		&error(&text('save_eend', $in{'end'}));
	$in{start} >= $in{'min'} ||
		&error(&text('save_emin', $in{'min'}));
	$in{end} <= $in{'max'} ||
		&error(&text('save_emax', $in{'max'}));
	$in{start} < $in{end} ||
		&error($text{'save_eminmax'});

	# Check for partition overlap..
	foreach $pinfo (@plist) {
		if (($in{'start'} >= $pinfo->{'start'} &&
		     $in{'start'} <= $pinfo->{'end'} ||
		     $in{'end'} >= $pinfo->{'start'} &&
		     $in{'end'} <= $pinfo->{'end'}) &&
		     !($in{'new'}==2 && $pinfo->{'extended'})) {
			&error(&text('save_eoverlap', $pinfo->{'number'},
				     $pinfo->{'start'}, $pinfo->{'end'}));
			}
		}
	if ($in{'new'} == 3) {
		&create_extended($dinfo->{'device'}, $in{'newpart'},
				$in{'start'}, $in{'end'});
		&webmin_log("create", "part", $dinfo->{'device'}, \%in);
		}
	else {
		&create_partition($dinfo->{'device'}, $in{'newpart'},
				  $in{'start'}, $in{'end'}, $in{'type'});
		$pinfo = { 'type' => $in{'type'},
			   'number' => $in{'newpart'} };
		if ($in{'label'} && &supports_label($pinfo)) {
			local $dev = $dinfo->{'prefix'}.$in{'newpart'};
			&set_label($dev, $in{'label'});
			}
		if ($in{'name'} && &supports_name($dinfo)) {
			&set_name($dinfo, $pinfo, $in{'name'});
			}
		&webmin_log("create", "part", $dinfo->{'device'}, \%in);
		}
	if (&need_reboot($dinfo)) {
		&ask_reboot($dinfo);
		}
	else {
		&redirect("edit_disk.cgi?device=$dinfo->{'device'}");
		}
	}

# ask_reboot(disk)
# Display a form asking for a reboot
sub ask_reboot
{
&ui_print_header(undef, $text{'reboot_title'}, "");
local $what = &text('select_device', uc($_[0]->{'type'}),
		    uc(substr($_[0]->{'device'}, -1)));
print "<b>",&text('reboot_why', $what),"</b> <p>\n";
print &ui_form_start("reboot.cgi");
print &ui_form_end([ [ undef, $text{'reboot_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});
}

