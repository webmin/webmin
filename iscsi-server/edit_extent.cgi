#!/usr/local/bin/perl
# Show a form to edit or create an extent

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text, %in);
my $conf = &get_iscsi_config();
&ReadParse();

# Get the extent, or create a new one
my $extent;
if ($in{'new'}) {
	&ui_print_header(undef, $text{'extent_create'}, "");
	$extent = { 'num' => &find_free_num($conf, 'extent'),
		    'type' => 'extent',
		    'start' => 0 };
	}
else {
	$extent = &find($conf, "extent", $in{'num'});
	$extent || &text('extent_egone', $in{'num'});
	&ui_print_header(undef, $text{'extent_edit'}, "");
	}

# Show editing form
print &ui_form_start("save_extent.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("num", $in{'num'});
print &ui_table_start($text{'extent_header'}, undef, 2);

# Extent name/number
print &ui_table_row($text{'extent_name'},
		    $extent->{'type'}.$extent->{'num'});

# Device to share, starting with disk partitions
my @opts;
my $part_found = 0;
my $sel = &fdisk::partition_select("part", $extent->{'device'}, 0,
				   \$part_found);
push(@opts, [ 'part', $text{'extent_part'}, $sel ]);

# Then add RAID devices
my $rconf = &raid::get_raidtab();
my @ropts;
my $raid_found = 0;
foreach my $c (@$rconf) {
	if ($c->{'active'}) {
		push(@ropts, [ $c->{'value'},
			       &text('extent_md',
				     substr($c->{'value'}, -1)) ]);
		$raid_found = 1 if ($extent->{'device'} eq $c->{'value'});
		}
	}
if (@ropts) {
	push(@opts, [ 'raid', $text{'extent_raid'},
		      &ui_select("raid", $extent->{'device'}, \@ropts) ]);
	}

# Then add LVM logical volumes
my @vgs = sort { $a->{'name'} cmp $b->{'name'} } &lvm::list_volume_groups();
my @lvs;
foreach my $v (@vgs) {
	push(@lvs, sort { $a->{'name'} cmp $b->{'name'} }
			&lvm::list_logical_volumes($v->{'name'}));
	}
my @lopts;
my $lvm_found = 0;
foreach my $l (@lvs) {
	push(@lopts, [ $l->{'device'},
		       &text('extent_lv', $l->{'vg'}, $l->{'name'}) ]);
	$lvm_found = 1 if (&same_file($extent->{'device'}, $l->{'device'}));
	}
if (@lopts) {
	push(@opts, [ 'lvm', $text{'extent_lvm'},
		      &ui_select("lvm", $extent->{'device'}, \@lopts) ]);
	}

# Then add other file mode
my $mode = $part_found ? 'part' :
	   $raid_found ? 'raid' :
	   $lvm_found ? 'lvm' : 'other';
push(@opts, [ 'other', $text{'extent_other'},
	      &ui_textbox("other",
			  $mode eq 'other' ? $extent->{'device'} : "", 50).
	      " ".&file_chooser_button("other") ]);

print &ui_table_row($text{'extent_device'},
	&ui_radio_table("mode", $mode, \@opts));

# Byte offset for start
print &ui_table_row($text{'extent_start'},
	&ui_bytesbox("start", $extent->{'start'}));

# Byte size to share
print &ui_table_row($text{'extent_size'},
	&ui_radio("size_def",
		  $in{'new'} ? 1 :
		  &get_device_size($extent->{'device'}, $mode) ==
		    $extent->{'size'} ? 1 : 0,
		  [ [ 1, $text{'extent_size_def1'} ],
		    [ 0, $text{'extent_size_def0'} ] ])." ".
	&ui_bytesbox("size", $extent->{'size'}));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_extents.cgi", $text{'extents_return'});
