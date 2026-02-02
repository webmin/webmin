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
$in{'device'} =~ /^[a-zA-Z0-9_\/.-]+$/
  or &error( $text{'disk_edevice'} || 'Invalid device' );
$in{'device'} !~ /\.\./  or &error( $text{'disk_edevice'} || 'Invalid device' );
$in{'slice'}  =~ /^\d+$/ or &error( $text{'slice_egone'} );
$in{'part'}   =~ /^[a-z]$/ or &error( $text{'part_egone'} );
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error( $text{'disk_egone'} );
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{ $disk->{'slices'} };
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
    my $use = &fdisk::device_status_link(@st);
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
        [ [ "confirm", $text{'dslice_confirm'} ] ],
        undef,
        $use ? &text( 'dpart_warn', &html_escape($use) ) : undef
    );
}

&ui_print_footer( "edit_slice.cgi?device=$in{'device'}&slice=$in{'slice'}",
    $text{'slice_return'} );
