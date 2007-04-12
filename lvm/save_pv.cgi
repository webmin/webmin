#!/usr/local/bin/perl
# save_pv.cgi
# Create, modify or delete a physical volume

require './lvm-lib.pl';
&ReadParse();

($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
($pv) = grep { $_->{'name'} eq $in{'pv'} } &list_physical_volumes($in{'vg'})
	if ($in{'pv'});

if ($in{'confirm'}) {
	# Delete the logical volume
	&error_setup($text{'pv_err2'});
	$err = &delete_physical_volume($pv);
	&error("<pre>$err</pre>") if ($err);
	&webmin_log("delete", "pv", $in{'pv'}, $pv);
	&redirect("");
	}
elsif ($in{'delete'}) {
	# Ask the user if he is sure
	&ui_print_header(undef, $text{'pv_delete'}, "");
	print "<center><form action=save_pv.cgi>\n";
	print "<input type=hidden name=vg value='$in{'vg'}'>\n";
	print "<input type=hidden name=pv value='$in{'pv'}'>\n";
	print "<b>",&text('pv_rusure',
			  "<tt>$pv->{'device'}</tt>"),"</b><p>\n";
	print "<input type=submit name=confirm ",
	      "value='$text{'pv_deleteok'}'>\n";
	print "</center></form>\n";
	&ui_print_footer("", $text{'index_return'});
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
		$err = &create_physical_volume($pv);
		&error("<pre>$err</pre>") if ($err);
		}

	# Change the volume
	if ($pv->{'alloc'} ne $in{'alloc'}) {
		$pv->{'alloc'} = $in{'alloc'};
		$err = &change_physical_volume($pv);
		&error("<pre>$err</pre>") if ($err);
		}

	&webmin_log($in{'pv'} ? "modify" : "create", "pv", $pv->{'device'},$pv);
	&redirect("");
	}

