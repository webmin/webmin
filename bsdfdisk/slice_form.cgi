#!/usr/local/bin/perl
# Show a form for creating a new slice

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();

# Get the disk
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});

&ui_print_header($disk->{'desc'}, $text{'nslice_title'}, "");

print &ui_form_start("create_slice.cgi", "post");
print &ui_hidden("device", $in{'device'});
print &ui_table_start($text{'nslice_header'}, undef, 2);

# Slice number (first free)
my %used = map { $_->{'number'}, $_ } @{$disk->{'slices'}};
my $n = 1;
while($used{$n}) {
	$n++;
	}
print &ui_table_row($text{'nslice_number'},
	&ui_textbox("number", $n, 6));

# Disk size in blocks
print &ui_table_row($text{'nslice_diskblocks'},
	$disk->{'blocks'});

# Start and end blocks (defaults to last slice+1)
my ($start, $end) = (63, $disk->{'blocks'});
foreach my $s (sort { $a->{'startblock'} cmp $b->{'startblock'} }
		    @{$disk->{'slices'}}) {
	$start = $s->{'startblock'} + $s->{'blocks'} + 1;
	}
print &ui_table_row($text{'nslice_start'},
	&ui_textbox("start", $start, 10));
print &ui_table_row($text{'nslice_end'},
	&ui_textbox("end", $end, 10));

# Slice type
print &ui_table_row($text{'nslice_type'},
	&ui_select("type", 'a5',
	   [ sort { $a->[1] cmp $b->[1] }
		  map { [ $_, &fdisk::tag_name($_) ] }
		      &fdisk::list_tags() ]));

# Also create partition?
print &ui_table_row($text{'nslice_makepart'},
	&ui_yesno_radio("makepart", 1));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("edit_disk.cgi?device=$in{'device'}",
		 $text{'disk_return'});
