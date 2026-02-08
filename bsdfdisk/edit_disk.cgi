#!/usr/local/bin/perl
# Show details of a disk, and slices on it
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our ( %in, %text, $module_name );
&ReadParse();
my $extwidth = 100;

# Get the disk
my @disks = &list_disks_partitions();

# Validate input parameters
$in{'device'} =~ /^[a-zA-Z0-9_\/.-]+$/ or &error( $text{'disk_edevice'} );
$in{'device'} !~ /\.\./                or &error( $text{'disk_edevice'} );
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error( $text{'disk_egone'} );

# Cache commonly used values
my $device     = $disk->{'device'};
my $device_url = &urlize($device);
my $desc       = $disk->{'desc'};

# Prefer total blocks from gpart header when available
my $base_device = $disk->{'device'};
$base_device =~ s{^/dev/}{};
my $disk_structure = &get_disk_structure($base_device);
my $disk_blocks =
  ( $disk_structure && $disk_structure->{'total_blocks'} )
  ? $disk_structure->{'total_blocks'}
  : ( $disk->{'blocks'} || 1000000 );

# Precompute a scale factor for extent image widths
my $scale = $extwidth / ( $disk_blocks || 1 );
&ui_print_header( $disk->{'desc'}, $text{'disk_title'}, "" );

# Debug toggle bar
print
  "<div class='debug-toggle' style='margin-bottom: 15px; text-align: right;'>";
if ( $in{'debug'} ) {
    print
"<a href='edit_disk.cgi?device=$device_url' class='btn btn-default'><i class='fa fa-bug'></i> $text{'disk_hide_debug'}</a>";
}
else {
    print
"<a href='edit_disk.cgi?device=$device_url&debug=1' class='btn btn-default'><i class='fa fa-bug'></i> $text{'disk_show_debug'}</a>";
}
print "</div>";

# Get detailed disk information from geom and disk structure from gpart show (cache disk_structure entries)
my $geom_info = &get_detailed_disk_info($device);
my $entries   = $disk_structure
  && $disk_structure->{'entries'} ? $disk_structure->{'entries'} : [];
print &ui_table_start( $text{'disk_details'}, "width=100%", 2 );

# Prefer mediasize (bytes) for accurate size; fallback to stat-based size
my $disk_bytes =
  ( $disk_structure && $disk_structure->{'mediasize'} )
  ? $disk_structure->{'mediasize'}
  : $disk->{'size'};
print &ui_table_row( $text{'disk_dsize'}, &safe_nice_size($disk_bytes) );
if ( $disk->{'model'} ) {
    print &ui_table_row( $text{'disk_model'},
        &html_escape( $disk->{'model'} ) );
}
print &ui_table_row( $text{'disk_device'},
    "<tt>" . &html_escape( $disk->{'device'} ) . "</tt>" );

# Get disk scheme
print &ui_table_row( $text{'disk_scheme'},
      $disk_structure
    ? &html_escape( $disk_structure->{'scheme'} )
    : $text{'disk_unknown'} );

# GEOM details
if ($geom_info) {
    print &ui_table_hr();
    print &ui_table_row( $text{'disk_geom_header'},
        "<b>$text{'disk_geom_details'}</b>", 2 );
    if ( $geom_info->{'mediasize'} ) {
        print &ui_table_row( $text{'disk_mediasize'},
            $geom_info->{'mediasize'} );
    }
    if ( $geom_info->{'sectorsize'} ) {
        print &ui_table_row( $text{'disk_sectorsize'},
            $geom_info->{'sectorsize'} . " " . $text{'disk_bytes'} );
    }
    if ( $geom_info->{'stripesize'} ) {
        print &ui_table_row( $text{'disk_stripesize'},
            $geom_info->{'stripesize'} . " " . $text{'disk_bytes'} );
    }
    if ( $geom_info->{'stripeoffset'} ) {
        print &ui_table_row( $text{'disk_stripeoffset'},
            $geom_info->{'stripeoffset'} . " " . $text{'disk_bytes'} );
    }
    if ( $geom_info->{'mode'} ) {
        print &ui_table_row( $text{'disk_mode'},
            &html_escape( $geom_info->{'mode'} ) );
    }
    if ( $geom_info->{'rotationrate'} ) {
        if ( $geom_info->{'rotationrate'} eq "0" ) {
            print &ui_table_row( $text{'disk_rotationrate'},
                $text{'disk_ssd'} );
        }
        else {
            print &ui_table_row( $text{'disk_rotationrate'},
                $geom_info->{'rotationrate'} . " " . $text{'disk_rpm'} );
        }
    }
    if ( $geom_info->{'ident'} ) {
        print &ui_table_row( $text{'disk_ident'},
            &html_escape( $geom_info->{'ident'} ) );
    }
    if ( $geom_info->{'lunid'} ) {
        print &ui_table_row( $text{'disk_lunid'},
            &html_escape( $geom_info->{'lunid'} ) );
    }
    if ( $geom_info->{'descr'} ) {
        print &ui_table_row( $text{'disk_descr'},
            &html_escape( $geom_info->{'descr'} ) );
    }
}

# Advanced information (cylinders, blocks)
print &ui_table_hr();
print &ui_table_row( $text{'disk_advanced_header'},
    "<b>$text{'disk_advanced_details'}</b>", 2 );
if ( $disk->{'cylinders'} ) {
    print &ui_table_row( $text{'disk_cylinders'}, $disk->{'cylinders'} );
}
print &ui_table_row( $text{'disk_blocks'}, $disk->{'blocks'} );
print &ui_table_end();

# Debug: print raw outputs if debug mode is enabled
if ( $in{'debug'} ) {
    print "<div class='debug-section'>";

    # Debug: gpart show output
    my $cmd = "gpart show -l " . &quote_path($base_device) . " 2>&1";
    my $out = &backquote_command($cmd);
    print "<div class='panel panel-default'>";
    print
"<div class='panel-heading'><h3 class='panel-title'>$text{'disk_debug_gpart'}</h3></div>";
    print "<div class='panel-body'>";
    print "<pre>Command: "
      . &html_escape($cmd)
      . "\nOutput:\n"
      . &html_escape($out)
      . "\n</pre>";
    print "</div></div>";

    # Debug: disk structure
    print "<div class='panel panel-default'>";
    print
"<div class='panel-heading'><h3 class='panel-title'>$text{'disk_debug_structure'}</h3></div>";
    print "<div class='panel-body'>";
    print "<pre>Disk Structure:\n";
    foreach my $key ( sort keys %$disk_structure ) {
        if ( $key eq 'entries' ) {
            print "entries: [\n";
            foreach my $entry ( @{ $disk_structure->{'entries'} } ) {
                print "  {\n";
                foreach my $k ( sort keys %$entry ) {
                    print "    $k: " . &html_escape( $entry->{$k} ) . "\n";
                }
                print "  },\n";
            }
            print "]\n";
        }
        else {
            print "$key: " . &html_escape( $disk_structure->{$key} ) . "\n";
        }
    }
    print "</pre>";
    print "</div></div>";

    # Debug: Raw GEOM output
    print "<div class='panel panel-default'>";
    print
"<div class='panel-heading'><h3 class='panel-title'>$text{'disk_debug_geom'}</h3></div>";
    print "<div class='panel-body'>";
    print "<pre>Raw GEOM output:\n";
    print &html_escape(
        &backquote_command(
            "geom disk list " . &quote_path($device) . " 2>/dev/null"
        )
    );
    print "</pre>";
    print "</div></div>";
    print "</div>";
}

# Build partition details from disk_structure (no separate gpart list call)
my %part_details = ();
if ( $disk_structure && $disk_structure->{'partitions'} ) {
    %part_details = %{ $disk_structure->{'partitions'} };
}

# Ensure we have names/labels for any entries missing from partitions map
if ( $disk_structure && $disk_structure->{'entries'} ) {
    foreach my $entry ( @{ $disk_structure->{'entries'} } ) {
        next unless ( $entry->{'type'} eq 'partition' && $entry->{'index'} );
        my $part_num = $entry->{'index'};
        $part_details{$part_num} ||= {};
        $part_details{$part_num}->{'name'} ||=
          $base_device
          . ( ( $disk_structure->{'scheme'} eq 'GPT' )
            ? "p$part_num"
            : "s$part_num" );
        if ( $entry->{'label'} && $entry->{'label'} ne '(null)' ) {
            $part_details{$part_num}->{'label'} ||= $entry->{'label'};
        }
        $part_details{$part_num}->{'type'} ||=
          $entry->{'part_type'} || 'unknown';
    }
}

# Build ZFS devices cache
my ( $zfs_pools, $zfs_devices ) = &build_zfs_devices_cache();

# Debug ZFS pools if debug mode is enabled
if ( $in{'debug'} ) {
    print "<div class='debug-section'>";
    print "<div class='panel panel-default'>";
    print
"<div class='panel-heading'><h3 class='panel-title'>$text{'disk_debug_zfs'}</h3></div>";
    print "<div class='panel-body'>";
    print "<pre>";
    my $cmd = "zpool status 2>&1";
    my $out = &backquote_command($cmd);
    print "Command: "
      . &html_escape($cmd)
      . "\nOutput:\n"
      . &html_escape($out) . "\n";
    print "</pre>";
    print "</div></div>";
    print "</div>";
}

# Debug: Print partition details mapping if debug enabled
if ( $in{'debug'} ) {
    print "<div class='debug-section'>";
    print "<div class='panel panel-default'>";
    print
"<div class='panel-heading'><h3 class='panel-title'>$text{'disk_debug_part_details'}</h3></div>";
    print "<div class='panel-body'>";
    print "<pre>Partition Details Mapping:\n";
    foreach my $pnum ( sort { $a <=> $b } keys %part_details ) {
        print "  $pnum: {\n";
        foreach my $k ( sort keys %{ $part_details{$pnum} } ) {
            print "    $k: "
              . &html_escape( $part_details{$pnum}->{$k} ) . "\n";
        }
        print "  },\n";
    }
    print "</pre>";
    print "</div></div>";
    print "</div>";
}

# Get sector size
my $sectorsize =
  $disk_structure->{'sectorsize'} || &get_disk_sectorsize($device) || 512;
my $sectorsize_text = $sectorsize ? "$sectorsize" : "512";

# Show partitions table
my @links =
  (     "<a href='slice_form.cgi?device=$device_url&amp;new=1'>"
      . $text{'disk_add'}
      . "</a>" );
if (@$entries) {
    print &ui_links_row( \@links );
    print &ui_columns_start(
        [
            $text{'disk_no'},           # Row number
            $text{'disk_partno'},       # Part. No.
            $text{'disk_partname'},     # Part. Name
            $text{'disk_partlabel'},    # Part. Label
            $text{'disk_subpart'},      # Sub-part.
            $text{'disk_extent'},       # Extent
            $text{'disk_start'},        # Startblock
            $text{'disk_end'},          # Endblock
            $text{'disk_size'},         # Size
            $text{'disk_format'},       # Format type
            $text{'disk_use'},          # Used by
            $text{'disk_role'},         # Role Type
        ]
    );
    my $row_number = 1;
    foreach my $entry (@$entries) {
        my @cols = ();
        push( @cols, $row_number++ );
        if ( $entry->{'type'} eq 'free' ) {
            my $start = $entry->{'start'};
            my $end   = $entry->{'start'} + $entry->{'size'} - 1;
            my $create_url =
              "slice_form.cgi?device=$device_url&new=1&start=$start&end=$end";
            push( @cols,
                    "<a href='$create_url' style='color: green;'>"
                  . $text{'disk_free'}
                  . "</a>" );
            push( @cols, "-" );
            push( @cols, "-" );
            push( @cols, "-" );
            my $ext = "";
            $ext .= sprintf "<img src='images/gap.gif' height='10' width='%d'>",
              $scale * ( $entry->{'start'} - 1 );
            $ext .=
              sprintf
"<img src='images/gap.gif' height='10' width='%d' style='background-color: #8f8;'>",
              $scale * ( $entry->{'size'} );
            $ext .= sprintf "<img src='images/gap.gif' height='10' width='%d'>",
              $scale * ( $disk_blocks - $entry->{'start'} - $entry->{'size'} );
            push( @cols, $ext );
            push( @cols, $start );
            push( @cols, $end );
            push( @cols, $entry->{'size_human'} );
            push( @cols, $text{'disk_free_space'} );
            push( @cols, $text{'disk_available'} );
            push( @cols, "-" );
        }
        else {
            my $part_num = $entry->{'index'};
            my $ext      = "";
            $ext .= sprintf "<img src='images/gap.gif' height='10' width='%d'>",
              $scale * ( $entry->{'start'} - 1 );
            $ext .= sprintf "<img src='images/use.gif' height='10' width='%d'>",
              $scale * ( $entry->{'size'} );
            $ext .= sprintf "<img src='images/gap.gif' height='10' width='%d'>",
              $scale * ( $disk_blocks - $entry->{'start'} - $entry->{'size'} );
            my $url = "edit_slice.cgi?device=$device_url&amp;slice="
              . &urlize($part_num);
            push( @cols, "<a href='$url'>" . &html_escape($part_num) . "</a>" );

            my $part_info = $part_details{$part_num};
            my $part_name = $part_info ? $part_info->{'name'} : "-";
            push( @cols, &html_escape($part_name) );
            my $part_label =
                $part_info
              ? $part_info->{'label'}
              : ( $entry->{'label'} eq "(null)" ? "-" : $entry->{'label'} );
            push( @cols, &html_escape($part_label) );

            # Find sub-partitions if available
            my ($slice) =
              grep { $_->{'number'} eq $part_num } @{ $disk->{'slices'} || [] };
            my $sub_part_info =
              ( $slice && scalar( @{ $slice->{'parts'} || [] } ) > 0 )
              ? join( ", ", map { $_->{'letter'} } @{ $slice->{'parts'} } )
              : "-";
            push( @cols, &html_escape($sub_part_info) );

            push( @cols, $ext );
            push( @cols, $entry->{'start'} );
            push( @cols, $entry->{'start'} + $entry->{'size'} - 1 );
            push( @cols, $entry->{'size_human'} );

            # Classify format/use/role via library helper
            my ( $format_type, $usage, $role ) = classify_partition_row(
                base_device     => $base_device,
                scheme          => ( $disk_structure->{'scheme'} || '' ),
                part_num        => $part_num,
                part_name       => $part_name,
                part_label      => $part_label,
                entry_part_type => (
                    $part_info ? $part_info->{'type'} : $entry->{'part_type'}
                ),
                entry_rawtype =>
                  ( $part_info ? $part_info->{'rawtype'} : undef ),
                size_human  => $entry->{'size_human'},
                size_blocks => $entry->{'size'},
                zfs_devices => $zfs_devices,
            );
            push( @cols, &html_escape( $format_type || '-' ) );
            push( @cols, &html_escape( $usage       || $text{'part_nouse'} ) );
            push( @cols, &html_escape( $role        || '-' ) );
        }
        print &ui_columns_row( \@cols );
    }
    print &ui_columns_end();
}
else {
    if ( @{ $disk->{'slices'} || [] } ) {
        print &ui_links_row( \@links );
        print &ui_columns_start(
            [
                $text{'disk_no'},     $text{'disk_type'},
                $text{'disk_extent'}, $text{'disk_start'},
                $text{'disk_end'},    $text{'disk_use'},
            ]
        );
        foreach my $s ( @{ $disk->{'slices'} } ) {
            my @cols = ();
            my $ext  = "";
            $ext .= sprintf "<img src='images/gap.gif' height='10' width='%d'>",
              $scale * ( $s->{'startblock'} - 1 );
            $ext .= sprintf "<img src='images/%s.gif' height='10' width='%d'>",
              ( $s->{'extended'} ? "ext" : "use" ),
              $scale * ( $s->{'blocks'} );
            $ext .= sprintf "<img src='images/gap.gif' height='10' width='%d'>",
              $scale * ( $disk_blocks - $s->{'startblock'} - $s->{'blocks'} );
            my $url = "edit_slice.cgi?device=$device_url&amp;slice="
              . &urlize( $s->{'number'} );
            push( @cols,
                "<a href='$url'>" . &html_escape( $s->{'number'} ) . "</a>" );
            push( @cols,
                &get_type_description( $s->{'type'} ) || $s->{'type'} );
            push( @cols, $ext );
            push( @cols, $s->{'startblock'} );
            push( @cols, $s->{'startblock'} + $s->{'blocks'} - 1 );
            my @st  = &fdisk::device_status( $s->{'device'} );
            my $use = &fdisk::device_status_link(@st);
            push( @cols, &html_escape( $use || $text{'part_nouse'} ) );
            print &ui_columns_row( \@cols );
        }
        print &ui_columns_end();
    }
    else {
        print "<p>$text{'disk_none'}</p>\n";
    }
}
print &ui_links_row( \@links );

# Show SMART status link if available
if ( &has_command("smartctl") ) {
    print &ui_hr();
    print &ui_buttons_start();
    print &ui_buttons_row( "smart.cgi", $text{'disk_smart'},
        $text{'disk_smartdesc'}, &ui_hidden( "device", $device ) );
    print &ui_buttons_end();
}

# Debug: ZFS cache detail
if ( $in{'debug'} ) {
    print "<div class='debug-section'>";
    print "<div class='panel panel-default'>";
    print
"<div class='panel-heading'><h3 class='panel-title'>$text{'disk_debug_zfs_cache'}</h3></div>";
    print "<div class='panel-body'>";
    print "<pre>Pools: " . join( ", ", keys %$zfs_pools ) . "\n\nDevices:\n";
    foreach my $device_id ( sort keys %$zfs_devices ) {
        next if $device_id =~ /^_debug_/;
        my $device_info = $zfs_devices->{$device_id};
        print
"$device_id => Pool: $device_info->{'pool'}, Type: $device_info->{'vdev_type'}, Mirrored: "
          . ( $device_info->{'is_mirrored'} ? "Yes" : "No" )
          . ", RAIDZ: "
          . ( $device_info->{'is_raidz'}
            ? "Yes (Level: $device_info->{'raidz_level'})"
            : "No" )
          . ", Single: "
          . ( $device_info->{'is_single'} ? "Yes" : "No" )
          . ", Striped: "
          . ( $device_info->{'is_striped'} ? "Yes" : "No" ) . "\n";
    }
    print "</pre>";
    print "</div></div>";
    print "</div>";
}
&ui_print_footer( "", $text{'disk_return'} );
