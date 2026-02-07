#!/usr/local/bin/perl
# Change the type of a slice

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our ( %in, %text, $module_name );
&ReadParse();
&error_setup( $text{'slice_err'} );

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

# Apply changes
my $oldslice = {%$slice};
$in{'type'} =~ /^[a-zA-Z0-9._-]+$/
  or &error( $text{'nslice_etype'} || 'Invalid slice type' );
$slice->{'type'}   = $in{'type'};
$slice->{'active'} = $in{'active'} if ( defined $in{'active'} );

# Apply active flag for MBR disks via gpart set/unset when it changed
my $base = $disk->{'device'};
$base =~ s{^/dev/}{};
my $ds = get_disk_structure($base);
if ( is_using_gpart() && $ds && $ds->{'scheme'} && $ds->{'scheme'} !~ /GPT/i ) {
    my $idx = _safe_uint( slice_number($slice) );
    &error( $text{'slice_egone'} ) unless defined $idx;
    if (   defined $oldslice->{'active'}
        && defined $slice->{'active'}
        && $oldslice->{'active'} != $slice->{'active'} )
    {
        my $cmd =
          $slice->{'active'}
          ? "gpart set -a active -i $idx " . quote_path($base)
          : "gpart unset -a active -i $idx " . quote_path($base);
        my $out = backquote_command("$cmd 2>&1");
        if ( $? != 0 ) {
            &error( "Failed to change active flag: " . &html_escape($out) );
        }
    }
}

my $err = &modify_slice( $disk, $oldslice, $slice );
&error( &html_escape($err) ) if ($err);

&webmin_log( "modify", "slice", $slice->{'device'}, $slice );
my $url_device = &urlize( $in{'device'} );
&redirect("edit_disk.cgi?device=$url_device");
