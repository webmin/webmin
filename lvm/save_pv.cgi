#!/usr/local/bin/perl
# save_pv.cgi
# Create, modify or delete a physical volume

require './lvm-lib.pl';
&ReadParse();

($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
$vg || &error($text{'vg_egone'});
if ($in{'pv'}) {
	($pv) = grep { $_->{'name'} eq $in{'pv'} }
		     &list_physical_volumes($in{'vg'});
	$pv || &error($text{'pv_egone'});
	}

if ($in{'confirm'}) {
	# Delete the physical volume
	&error_setup($text{'pv_err2'});
	$err = &delete_physical_volume($pv);
	&error("<pre>$err</pre>") if ($err);
	&webmin_log("delete", "pv", $in{'pv'}, $pv);
	&redirect("index.cgi?mode=pvs");
	}
elsif ($in{'delete'}) {
	# Ask the user if he is sure
	&ui_print_header(undef, $text{'pv_delete'}, "");
	print "<center>\n";
	print &ui_form_start("save_pv.cgi");
	print &ui_hidden("vg", $in{'vg'});
	print &ui_hidden("pv", $in{'pv'});
	print "<b>",&text('pv_rusure',
			  "<tt>$pv->{'device'}</tt>"),"</b><p>\n";
	print &ui_form_end([ [ 'confirm', $text{'pv_deleteok'} ] ]);
	print "</center>\n";
	&ui_print_footer("index.cgi?mode=pvs", $text{'index_return2'});
	}
elsif ($in{'resize'}) {
	# Scale up to match device
	&error_setup($text{'pv_err3'});
	$err = &resize_physical_volume($pv);
	&error("<pre>$err</pre>") if ($err);
	&webmin_log("resize", "pv", $in{'pv'}, $pv);
	&redirect("index.cgi?mode=pvs");
	}
else {
	&error_setup($text{'pv_err'});
	if (!$in{'pv'}) {
		# Add the physical volume
		$pv = { 'vg' => $in{'vg'},
			'alloc' => 'y' };
		if ($in{'device'}) {
			$pv->{'device'} = $in{'device'};
			}
		else {
			-r $in{'other'} || &error($text{'pv_eother'});
			$pv->{'device'} = $in{'other'};
			}
		$err = &create_physical_volume($pv, $in{'force'});
		&error("<pre>$err</pre>") if ($err);
		}

	# Change the volume
	if ($pv->{'alloc'} ne $in{'alloc'}) {
		$pv->{'alloc'} = $in{'alloc'};
		$err = &change_physical_volume($pv);
		&error("<pre>$err</pre>") if ($err);
		}

	&webmin_log($in{'pv'} ? "modify" : "create", "pv", $pv->{'device'},$pv);
	&redirect("index.cgi?mode=pvs");
	}

