#!/usr/local/bin/perl
# Delete a slice, after asking for confirmation

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
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error( $text{'disk_egone'} );
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{ $disk->{'slices'} };
$slice || &error( $text{'slice_egone'} );

&ui_print_header( $slice->{'desc'}, $text{'dslice_title'}, "" );

if ( $in{'confirm'} ) {

    # Delete it
    print &text( 'dslice_deleting', &html_escape( $slice->{'desc'} ) ), "<p>\n";
    my $err = &delete_slice( $disk, $slice );
    if ($err) {
        print &text( 'dslice_failed', &html_escape($err) ), "<p>\n";
    }
    else {
        print $text{'dslice_done'}, "<p>\n";
        &webmin_log( "delete", "slice", $slice->{'device'}, $slice );
    }
}
else {
    # Ask first
    my @warn;
    my @st = &fdisk::device_status( $slice->{'device'} );
    if (@st) {
        push( @warn, &fdisk::device_status_link(@st) );
    }
    foreach my $p ( @{ $slice->{'parts'} } ) {
        my @st = &fdisk::device_status( $p->{'device'} );
        if (@st) {
            push( @warn, &fdisk::device_status_link(@st) );
        }
    }
    print &ui_confirmation_form(
        "delete_slice.cgi",
        &text(
            'dslice_rusure',
            "<tt>" . &html_escape( $slice->{'device'} ) . "</tt>"
        ),
        [ [ "device",  $in{'device'} ], [ "slice", $in{'slice'} ] ],
        [ [ "confirm", $text{'dslice_confirm'} ] ],
        undef,
        @warn
        ? &text( 'dslice_warn', join( " ", @warn ) )
        : undef
    );
}

my $url_device = &urlize( $in{'device'} );
&ui_print_footer( "edit_disk.cgi?device=$url_device", $text{'disk_return'} );
