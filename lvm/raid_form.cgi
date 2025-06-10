#!/usr/local/bin/perl
# Display a form for creating a new RAID logical volume

require './lvm-lib.pl';
&ReadParse();
($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
$vg || &error($text{'vg_egone'});

$vgdesc = &text('lv_vg', $vg->{'name'});
&ui_print_header($vgdesc, $text{'raid_title'}, "");

print $text{'raid_desc'},"<p>\n";

print &ui_form_start("raid_create.cgi", "post");
print &ui_hidden("vg", $in{'vg'});
print &ui_table_start($text{'raid_header'}, undef, 2);

# LV name
print &ui_table_row($text{'lv_name'},
		    &ui_textbox("name", $lv->{'name'}, 30));

# LV size
@pvopts = map { $_->{'name'} }
	      &list_physical_volumes($in{'vg'});
print &ui_table_row($text{'lv_size'},
	&ui_radio_table("size_mode", 0,
	  [ [ 0, $text{'lv_size0'},
	      &ui_bytesbox("size", $show_size * 1024, 8) ],
	    [ 1, $text{'lv_size1'},
	      &ui_textbox("vgsize", undef, 4)."%" ],
	    [ 2, $text{'lv_size2'},
	      &ui_textbox("freesize", undef, 4)."%" ],
	    [ 3, $text{'lv_size3'},
	      &text('lv_size3a',
		&ui_textbox("pvsize", undef, 4)."%",
		&ui_select("pvof", undef, \@pvopts)) ],
	  ]), 3);

# RAID type
print &ui_table_row($text{'raid_type'},
	&ui_radio_table("raid_mode", 'raid0',
		[ [ 'raid0', $text{'raid_mode0'},
		    &ui_textbox('raid_stripe0', 2, 5) ],
		  [ 'raid1', $text{'raid_mode1'},
		    &ui_textbox('raid_mirror1', 1, 5) ],
		  [ 'raid4', $text{'raid_mode4'},
		    &ui_textbox('raid_stripe4', 2, 5) ],
		  [ 'raid5', $text{'raid_mode5'},
		    &ui_textbox('raid_stripe5', 2, 5) ],
		  [ 'raid6', $text{'raid_mode6'},
		    &ui_textbox('raid_stripe6', 2, 5) ],
		  [ 'raid10', $text{'raid_mode10'},
		    &ui_textbox('raid_stripe10', 2, 5) ] ]));

# Permissions
print &ui_table_row($text{'lv_perm'},
	&ui_radio("perm", 'rw',
		  [ [ 'rw', $text{'lv_permrw'} ],
		    [ 'r', $text{'lv_permr'} ] ]));

# Allocation method
print &ui_table_row($text{'lv_alloc'},
	&ui_radio("alloc", 'n',
		  [ [ 'y', $text{'lv_allocy'} ],
		    [ 'n', $text{'lv_allocn'} ] ]));

# Readahead sectors
print &ui_table_row($text{'lv_readahead'},
	&ui_select("readahead", $lv->{'readahead'},
		   [ [ "auto", "Auto" ], [ 0, "None" ],
		     map { [ $_, $_."" ] }
			 map { 2**$_ } ( 7 .. 16) ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'raid_ok'} ] ]);

&ui_print_footer("index.cgi?mode=lvs", $text{'index_return'});
