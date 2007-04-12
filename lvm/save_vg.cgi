#!/usr/local/bin/perl
# save_vg.cgi
# Create, update or delete a volume group

require './lvm-lib.pl';
&ReadParse();

($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups()
	if ($in{'vg'});

if ($in{'confirm'}) {
	# Delete the volume group
	&error_setup($text{'vg_err2'});
	$err = &delete_volume_group($vg);
	&error("<pre>$err</pre>") if ($err);
	&webmin_log("delete", "vg", $in{'vg'}, $vg);
	&redirect("");
	}
elsif ($in{'delete'}) {
	# Ask the user if he is sure
	&ui_print_header(undef, $text{'vg_delete'}, "");
	@lvs = &list_logical_volumes($in{'vg'});
	if (@lvs) {
		print "<p><b>",&text('vg_cannot', scalar(@lvs)),"</b> <p>\n";
		}
	else {
		print "<center><form action=save_vg.cgi>\n";
		print "<input type=hidden name=vg value='$in{'vg'}'>\n";
		print "<b>",&text('vg_rusure', $vg->{'name'}),"</b><p>\n";
		print "<input type=submit name=confirm ",
		      "value='$text{'vg_deleteok'}'>\n";
		print "</center></form>\n";
		}
	&ui_print_footer("", $text{'index_return'});
	}
else {
	&error_setup($text{'vg_err'});
	$in{'name'} =~ /^[A-Za-z0-9\.\-\_]+$/ || &error($text{'vg_ename'});
	if (!$in{'vg'}) {
		# Add the volume group
		$vg = { 'name' => $in{'name'} };
		local $device;
		if ($in{'device'}) {
			$device = $in{'device'};
			}
		else {
			-r $in{'other'} || &error($text{'pv_eother'});
			$device = $in{'other'};
			}
		if (!$in{'pesize_def'}) {
			$in{'pesize'} =~ /^\d+$/ || &error($text{'vg_epesize'});
			$vg->{'pe_size'} = $in{'pesize'};
			}
		$err = &create_volume_group($vg, $device);
		&error("<pre>$err</pre>") if ($err);
		&webmin_log("create", "vg", $in{'name'}, $vg);
		}
	else {
		# Rename the volume group
		if ($vg->{'name'} ne $in{'name'}) {
			$err = &rename_volume_group($vg, $in{'name'});
			&error("<pre>$err</pre>") if ($err);
			$vg->{'name'} = $in{'name'};
			}
		&webmin_log("modify", "vg", $in{'vg'}, $vg);
		}
	&redirect("");
	}

