#!/usr/local/bin/perl
# Delete a partition, after asking for confirmation

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our ( %in, %text, $module_name );
&ReadParse();

# Get the disk and slice
my @disks = &list_disks_partitions();
# Validate inputs
($in{'device'} =~ /^[a-zA-Z0-9_\/.-]+$/ && $in{'device'} !~ /\.\./)
  or &error( $text{'disk_edevice'} || 'Invalid device' );
$in{'slice'}  =~ /^\d+$/ or &error( $text{'slice_egone'} );
$in{'part'}   =~ /^[a-z]$/ or &error( $text{'part_egone'} );
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error( $text{'disk_egone'} );
my $in_slice_num = int($in{'slice'});
my ($slice) = grep { int($_->{'number'}) == $in_slice_num } @{ $disk->{'slices'} };
$slice || &error( $text{'slice_egone'} );
my ($part) = grep { $_->{'letter'} eq $in{'part'} } @{ $slice->{'parts'} };
$part || &error( $text{'part_egone'} );

&ui_print_header( $part->{'desc'}, $text{'dpart_title'}, "" );

if ( $in{'confirm'} ) {

    # Delete it
    print &text( 'dpart_deleting', &html_escape( $part->{'desc'} ) ), "<p>\n";
    my $err = &delete_partition( $disk, $slice, $part );
    if ($err) {
        print &text( 'dpart_failed', &html_escape($err) ), "<p>\n";
    }
    else {
        print $text{'dpart_done'}, "<p>\n";
        &webmin_log( "delete", "part", $part->{'device'}, $part );
    }
}
else {
    # Ask first
    my @st  = &fdisk::device_status( $part->{'device'} );
    my $use = &fdisk::device_status_link(@st); # returns safe HTML link(s); ensure upstream sanitization
    print &ui_confirmation_form(
        "delete_part.cgi",
        &text(
            'dpart_rusure',
            "<tt>" . &html_escape( $part->{'device'} ) . "</tt>"
        ),
        [
            [ "device", $in{'device'} ],
            [ "slice",  $in{'slice'} ],
            [ "part",   $in{'part'} ]
        ],
        # Use partition-specific confirmation text key if available
        [ [ "confirm", $text{'dpart_confirm'} || $text{'dslice_confirm'} ] ],
        undef,
        $use ? &text( 'dpart_warn', $use ) : undef
    );
}

my $url_device = &urlize( $in{'device'} );
my $url_slice  = &urlize( $in{'slice'} );
&ui_print_footer( "edit_slice.cgi?device=$url_device&slice=$url_slice",
    $text{'slice_return'} );
