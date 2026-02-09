#!/usr/local/bin/perl
use strict;
use warnings;
no warnings 'redefine';
require './bsdfdisk-lib.pl';
our ( %in, %text, $module_name );
ReadParse();
error_setup( $text{'nslice_err'} );

# Get the disk using first() for an early exit on match
my @disks = list_disks_partitions();

# Validate input parameters
$in{'device'} =~ /^[a-zA-Z0-9_\/.-]+$/
  or error( $text{'disk_edevice'} || 'Invalid device' );
$in{'device'} !~ /\.\./ or error( $text{'disk_edevice'} || 'Invalid device' );
my $disk;
foreach my $d (@disks) {
    if ( $d->{'device'} eq $in{'device'} ) {
        $disk = $d;
        last;
    }
}

# Validate device parameter to prevent path traversal and command injection
$disk or error( $text{'disk_egone'} );

# Prefer GPART total blocks for bounds
( my $base_dev = $in{'device'} ) =~ s{^/dev/}{};
my $ds = get_disk_structure($base_dev);
my $disk_blocks =
  ( $ds && $ds->{'total_blocks'} )
  ? $ds->{'total_blocks'}
  : ( $disk->{'blocks'} || 0 );

# Validate inputs, starting with slice number
my $slice = {};
$in{'number'} =~ /^\d+$/ or error( $text{'nslice_enumber'} );

# Check for clash using first() with a loop exiting on first match
my $clash;
foreach my $s ( @{ $disk->{'slices'} } ) {
    if ( $s->{'number'} == $in{'number'} ) {
        $clash = $s;
        last;
    }
}
$slice->{'number'} = $in{'number'};

# Start and end blocks
$in{'start'} =~ /^\d+$/ or error( $text{'nslice_estart'} );
$in{'end'}   =~ /^\d+$/ or error( $text{'nslice_eend'} );
( $in{'start'} < $in{'end'} ) or error( $text{'nslice_erange'} );

# total_blocks is the block *after* the last valid block, so end must be < total_blocks
( $in{'end'} < $disk_blocks )
  or error( text( 'nslice_emax', $disk_blocks - 1 ) );

# Ensure the new slice does not overlap existing slices
foreach my $s ( @{ $disk->{'slices'} } ) {
    my $s_start = $s->{'startblock'};
    my $s_end   = $s->{'startblock'} + $s->{'blocks'} - 1;
    if ( !( $in{'end'} < $s_start || $in{'start'} > $s_end ) ) {
        error( "Requested slice range overlaps with existing slice #"
              . $s->{'number'} );
    }
}

$slice->{'startblock'} = $in{'start'};
$slice->{'blocks'}     = $in{'end'} - $in{'start'} + 1;

# Slice type
$in{'type'} =~ /^[a-zA-Z0-9_-]+$/ or error( $text{'nslice_etype'} );
length( $in{'type'} ) <= 20       or error( $text{'nslice_etype'} );
$slice->{'type'} = $in{'type'};

# Do the creation
ui_print_header( $disk->{'desc'}, $text{'nslice_title'}, "" );
print text( 'nslice_creating', $in{'number'}, &html_escape( $disk->{'desc'} ) ),
  "<p>\n";
my $err = create_slice( $disk, $slice );
if ($err) {
    print text( 'nslice_failed', &html_escape($err) ), "<p>\n";
}
else {
    print text('nslice_done'), "<p>\n";

   # Auto-label the new partition provider with its name if scheme is GPT or BSD
    my $base = $disk->{'device'};
    $base =~ s{^/dev/}{};
    my $ds = get_disk_structure($base);
    if ( $ds && $ds->{'scheme'} ) {

        # Determine provider and label text
        my $label_text = slice_name($slice);    # e.g., da8s2 or da0p2
        if ( $ds->{'scheme'} =~ /GPT/i ) {
            my $idx = $slice->{'number'};
            if ($idx) {
                my $cmd2 =
                    "gpart modify -i $idx -l "
                  . quote_path($label_text) . " "
                  . quote_path($base);
                my $out2 = backquote_command("$cmd2 2>&1");

                # If it fails, ignore silently
            }
        }
        else {
     # On MBR, if BSD label exists we can set label once created; ignore for now
        }
    }
}
if ( !$err && $in{'makepart'} ) {

    # Also create a partition (initialize slice label)
    my $part_err = initialize_slice( $disk, $slice );
    if ($part_err) {
        print text( 'nslice_pfailed', &html_escape($part_err) ), "<p>\n";
    }
    else {
        print text('nslice_pdone'), "<p>\n";
    }
}
if ( !$err ) {

    # Auto-label GPT partitions with their device name (e.g., da8p2)
    my $base = $disk->{'device'};
    $base =~ s{^/dev/}{};
    my $ds = get_disk_structure($base);
    if ( $ds && $ds->{'scheme'} && $ds->{'scheme'} =~ /GPT/i ) {
        my $slice_devname = $slice->{'device'};
        $slice_devname =~ s{^/dev/}{};    # e.g., da8p2
        my $idx = $slice->{'number'};
        if ( $idx && $slice_devname ) {
            my $label_cmd =
                "gpart modify -i $idx -l "
              . quote_path($slice_devname) . " "
              . quote_path($base) . " 2>&1";
            my $label_out = backquote_command($label_cmd);

            # Ignore errors - labeling is optional
        }
    }
    webmin_log( "create", "slice", $slice->{'device'}, $slice );
}
my $url_device = &urlize( $in{'device'} );
ui_print_footer( "edit_disk.cgi?device=$url_device", $text{'disk_return'} );
