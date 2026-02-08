#!/usr/local/bin/perl
# Show a form for creating a new slice

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our ( %in, %text, $module_name );
&ReadParse();

# Get the disk
my @disks = &list_disks_partitions();
$in{'device'} =~ /^[a-zA-Z0-9_\/.-]+$/
  or &error( $text{'disk_edevice'} || 'Invalid device' );
$in{'device'} !~ /\.\./ or &error( $text{'disk_edevice'} || 'Invalid device' );
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error( $text{'disk_egone'} );

my $url_device = &urlize( $in{'device'} );

&ui_print_header( $disk->{'desc'}, $text{'nslice_title'}, "" );

# Determine scheme for read-only behavior and note
my $base_device = $disk->{'device'};
$base_device =~ s{^/dev/}{};
my $disk_structure = get_disk_structure($base_device);
my $is_gpt =
  (      is_using_gpart()
      && $disk_structure
      && ( $disk_structure->{'scheme'} || '' ) =~ /GPT/i );

# Check if there is any free space on the device
my $has_free_space = 0;
if ( $disk_structure && $disk_structure->{'entries'} ) {
    foreach my $entry ( @{ $disk_structure->{'entries'} } ) {
        if ( $entry->{'type'} eq 'free' && $entry->{'size'} > 0 ) {
            $has_free_space = 1;
            last;
        }
    }
}

# If no free space, show error and return
if ( !$has_free_space ) {
    print "<p><b>$text{'nslice_enospace'}</b></p>\n";
    &ui_print_footer( "edit_disk.cgi?device=$url_device", $text{'disk_return'} );
    exit;
}

print &ui_form_start( "create_slice.cgi", "post" );
print &ui_hidden( "device", $in{'device'} );
print &ui_table_start( $text{'nslice_header'}, undef, 2 );

# Slice number (first free)
my %used = map { $_->{'number'}, $_ } @{ $disk->{'slices'} };
my $n    = 1;
while ( $used{$n} ) {
    $n++;
}
my $num_field =
  $is_gpt
  ? "<input type='text' name='number' value='"
  . &html_escape($n)
  . "' size='6' readonly> <span style='color:#666;font-style:italic'>"
  . $text{'nslice_autonext'}
  . "</span>"
  : &ui_textbox( "number", $n, 6 );
print &ui_table_row( $text{'nslice_number'}, $num_field );

# Disk size in blocks (prefer GPART total blocks)
my $disk_blocks =
  ( $disk_structure && $disk_structure->{'total_blocks'} )
  ? $disk_structure->{'total_blocks'}
  : ( $disk->{'blocks'} || 0 );
print &ui_table_row( $text{'nslice_diskblocks'}, $disk_blocks );

# Start and end blocks (defaults to last slice+1). Allow prefill from query.
my ( $start, $end ) = ( 2048, $disk_blocks > 0 ? $disk_blocks - 1 : 0 );
foreach my $s ( sort { $a->{'startblock'} <=> $b->{'startblock'} }
    @{ $disk->{'slices'} } )
{
    $start = $s->{'startblock'} + $s->{'blocks'};    # leave 1 block (512B) gap
}
if ( defined $in{'start'} && $in{'start'} =~ /^\d+$/ ) {
    $start = $in{'start'};
}
if ( defined $in{'end'} && $in{'end'} =~ /^\d+$/ ) { $end = $in{'end'}; }
print &ui_table_row( $text{'nslice_start'},
    &ui_textbox( "start", $start, 10 ) );
print &ui_table_row( $text{'nslice_end'}, &ui_textbox( "end", $end, 10 ) );

# Slice type
if ( is_using_gpart() ) {
    my $scheme =
      ( $disk_structure && $disk_structure->{'scheme'} )
      ? $disk_structure->{'scheme'}
      : 'GPT';
    my $default_stype = ( $scheme =~ /GPT/i ) ? 'freebsd-zfs' : 'freebsd';
    print &ui_table_row( $text{'nslice_type'},
        &ui_select( "type", $default_stype, [ list_partition_types($scheme) ] )
    );
}
else {
    print &ui_table_row(
        $text{'nslice_type'},
        &ui_select(
            "type", 'a5',
            [
                sort { $a->[1] cmp $b->[1] }
                map  { [ $_, &fdisk::tag_name($_) ] } &fdisk::list_tags()
            ]
        )
    );
}

# Also create partition? (only for MBR slices with BSD disklabel support)
if ( !$is_gpt ) {
    print &ui_table_row( $text{'slice_add'}, &ui_yesno_radio( "makepart", 1 ) );
}

print &ui_table_end();
print &ui_form_end( [ [ undef, $text{'save'} ] ] );

# Existing slices summary
print &ui_hr();
print &ui_subheading( $text{'nslice_existing_slices_label'} );
print &ui_columns_start(
    [
        $text{'disk_no'},  $text{'disk_type'}, $text{'disk_start'},
        $text{'disk_end'}, $text{'disk_size'}
    ],
    $text{'nslice_existing_header'}
);
foreach
  my $s ( sort { $a->{'number'} <=> $b->{'number'} } @{ $disk->{'slices'} } )
{
    my $stype = get_type_description( $s->{'type'} ) || $s->{'type'};
    my $szb   = bytes_from_blocks( $s->{'device'}, $s->{'blocks'} );
    my $sz    = defined $szb ? safe_nice_size($szb) : '-';
    print &ui_columns_row(
        [
            $s->{'number'},     &html_escape($stype),
            $s->{'startblock'}, $s->{'startblock'} + $s->{'blocks'} - 1,
            $sz,
        ]
    );
}
print &ui_columns_end();

# Existing partitions summary
my @parts_rows;
foreach
  my $s ( sort { $a->{'number'} <=> $b->{'number'} } @{ $disk->{'slices'} } )
{
    next unless @{ $s->{'parts'} || [] };
    foreach my $p ( @{ $s->{'parts'} } ) {
        my $ptype = get_type_description( $p->{'type'} ) || $p->{'type'};
        my $pb    = bytes_from_blocks( $p->{'device'}, $p->{'blocks'} );
        my $psz   = defined $pb ? safe_nice_size($pb) : '-';
        push @parts_rows,
          [
            $s->{'number'},                          uc( $p->{'letter'} ),
            &html_escape($ptype),                    $p->{'startblock'},
            $p->{'startblock'} + $p->{'blocks'} - 1, $psz
          ];
    }
}
if (@parts_rows) {
    print &ui_subheading( $text{'nslice_existing_parts_label'} );
    print &ui_columns_start(
        [
            'Slice',              $text{'slice_letter'}, $text{'slice_type'},
            $text{'slice_start'}, $text{'slice_end'},    $text{'slice_size'}
        ],
        $text{'nslice_existing_parts'}
    );
    foreach my $row (@parts_rows) { print &ui_columns_row($row); }
    print &ui_columns_end();
}

&ui_print_footer( "edit_disk.cgi?device=$url_device", $text{'disk_return'} );
