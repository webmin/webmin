#!/usr/local/bin/perl
# edit_pv.cgi
# Display a form for editing or creating a physical volume

require './lvm-lib.pl';
&ReadParse();
($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
$vg || &error($text{'vg_egone'});

$vgdesc = &text('pv_vg', $vg->{'name'});
if ($in{'pv'}) {
	@pvs = &list_physical_volumes($in{'vg'});
	($pv) = grep { $_->{'name'} eq $in{'pv'} } @pvs;
	$pv || &error($text{'pv_egone'});
	&ui_print_header($vgdesc, $text{'pv_edit'}, "");
	}
else {
	&ui_print_header($vgdesc, $text{'pv_create'}, "");
	$pv = { 'alloc' => 'y' };
	}

print &ui_form_start("save_pv.cgi");
print &ui_hidden("vg", $in{'vg'});
print &ui_hidden("pv", $in{'pv'});
print &ui_table_start($text{'pv_header'}, "width=100%", 4);

# Device file
if ($in{'pv'}) {
	print &ui_table_row($text{'pv_device'},
		&mount::device_name($pv->{'device'}), 3);
	}
else {
	print &ui_table_row($text{'pv_device'}, &device_input(), 3);
	}

# Enabled for allocation
print &ui_table_row($text{'pv_alloc'},
	&ui_radio('alloc', $pv->{'alloc'}, [ [ 'y', $text{'yes'} ],
					     [ 'n', $text{'no'} ] ]));

if ($in{'pv'}) {
	# Details of existing PV
	print &ui_table_row($text{'pv_size'},
		&nice_size($pv->{'size'}*1024));

	print &ui_table_row($text{'pv_petotal'},
		&text('lv_petotals', $pv->{'pe_alloc'}, $pv->{'pe_total'}));

	print &ui_table_row($text{'pv_pesize'},
		&nice_size($pv->{'pe_size'}*1024));

	print &ui_table_row($text{'pv_petotal2'},
		&text('lv_petotals', &nice_size($pv->{'pe_alloc'}*$pv->{'pe_size'}*1024), &nice_size($pv->{'pe_total'}*$pv->{'pe_size'}*1024)));

	# Used by logical volumes
	@lvinfo = &get_physical_volume_usage($pv);
	if (@lvinfo) {
		@lvs = &list_logical_volumes($in{'vg'});
		foreach $l (@lvinfo) {
			($lv) = grep { $_->{'name'} eq $l->[0] } @lvs;
			$nice = &nice_size($l->[1]*$pv->{'pe_size'}*1024);
			if ($lv) {
				push(@lvlist,
				  "<a href='edit_lv.cgi?vg=$in{'vg'}&".
				  "lv=$lv->{'name'}'>$lv->{'name'}</a> ".$nice);
				}
			else {
				push(@lvlist, $l->[0]." ".$nice);
				}
			}
		print &ui_table_row($text{'pv_lvs'},
			&ui_grid_table(\@lvlist, 4), 3);
		}
	}
else {
	# Force creation?
	print &ui_table_row($text{'pv_force'},
		&ui_yesno_radio('force', 0), 3);
	}

print &ui_table_end();
if ($in{'pv'}) {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'resize', $text{'pv_resize'} ],
			     @pvs > 1 ? ( [ 'delete', $text{'pv_delete2'} ] )
				      : ( ) ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'pv_create2'} ] ]);
	}

&ui_print_footer("index.cgi?mode=pvs", $text{'index_return'});

