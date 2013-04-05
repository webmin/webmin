#!/usr/local/bin/perl
# Show a form to create a filesystem on a partition

use strict;
use warnings;
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();

# Get the disk and slice
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error($text{'disk_egone'});
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{$disk->{'slices'}};
$slice || &error($text{'slice_egone'});
my $object;
if ($in{'part'} ne '') {
	my ($part) = grep { $_->{'letter'} eq $in{'part'} }
			  @{$slice->{'parts'}};
	$part || &error($text{'part_egone'});
	$object = $part;
	}
else {
	$object = $slice;
	}

&ui_print_header($object->{'desc'}, $text{'newfs_title'}, "");

print &ui_form_start("newfs.cgi", "post");
print &ui_hidden("device", $in{'device'});
print &ui_hidden("slice", $in{'slice'});
print &ui_hidden("part", $in{'part'});
print &ui_table_start($text{'newfs_header'}, undef, 2);

print &ui_table_row($text{'part_device'},
	"<tt>$object->{'device'}</tt>");

print &ui_table_row($text{'newfs_free'},
	&ui_opt_textbox("free", undef, 4, $text{'newfs_deffree'})."%");

print &ui_table_row($text{'newfs_trim'},
	&ui_yesno_radio("trim", 0));

print &ui_table_row($text{'newfs_label'},
	&ui_opt_textbox("label", undef, 20, $text{'newfs_none'}));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'newfs_create'} ] ]);

if ($in{'part'} ne '') {
	&ui_print_footer("edit_part.cgi?device=$in{'device'}&".
			   "slice=$in{'slice'}&part=$in{'part'}",
			 $text{'part_return'});
	}
else {
	&ui_print_footer("edit_slice.cgi?device=$in{'device'}&".
			   "slice=$in{'slice'}",
			 $text{'slice_return'});
	}
