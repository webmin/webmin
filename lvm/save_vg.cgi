#!/usr/local/bin/perl
# save_vg.cgi
# Create, update or delete a volume group

require './lvm-lib.pl';
&ReadParse();

if ($in{'vg'}) {
	($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
	$vg || &error($text{'vg_egone'});
	}

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
		print "<center>\n";
		print &ui_form_start("save_vg.cgi");
		print &ui_hidden("vg", $in{'vg'});
		print "<b>",&text('vg_rusure', $vg->{'name'}),"</b><p>\n";
		print &ui_form_end([ [ 'confirm', $text{'vg_deleteok'} ] ]);
		print "</center>\n";
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
	&redirect("index.cgi?mode=vgs");
	}

