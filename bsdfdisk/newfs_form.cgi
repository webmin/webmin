#!/usr/local/bin/perl
# Show a form to create a filesystem on a partition

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our ( %in, %text, $module_name );
&ReadParse();

# Get the disk and slice
# Validate input parameters to prevent command injection
$in{'device'} =~ /^[a-zA-Z0-9_\/.-]+$/ or &error("Invalid device name");
$in{'device'} !~ /\.\./                or &error("Invalid device name");
$in{'slice'} =~ /^\d+$/   or &error("Invalid slice number")     if $in{'slice'};
$in{'part'}  =~ /^[a-z]$/ or &error("Invalid partition letter") if $in{'part'};
my @disks = &list_disks_partitions();
my ($disk) = grep { $_->{'device'} eq $in{'device'} } @disks;
$disk || &error( $text{'disk_egone'} );
my ($slice) = grep { $_->{'number'} eq $in{'slice'} } @{ $disk->{'slices'} };
$slice || &error( $text{'slice_egone'} );
my $object;

if ( $in{'part'} ne '' ) {
    $in{'part'} =~ /^[a-z]$/ or &error("Invalid partition letter");
    my ($part) = grep { $_->{'letter'} eq $in{'part'} } @{ $slice->{'parts'} };
    $part || &error( $text{'part_egone'} );
    $object = $part;
}
else {
    $object = $slice;
}

# If this device is part of a ZFS pool, offer dataset creation instead
my $zdev = get_zfs_device_info($object);
if ($zdev) {
    &ui_print_header( $object->{'desc'}, $text{'newfs_title'}, "" );

    # Parent pool summary (best effort)
    my $parent   = $zdev->{'pool'};
    my $parent_q = quote_path($parent);
    my $zlist    = &backquote_command(
        "zfs list -H -o name,used,avail,refer,mountpoint $parent_q 2>/dev/null"
    );
    if ($zlist) {
        chomp($zlist);
        my @cols = split( /\t/, $zlist );
        if ( @cols >= 5 ) {
            print "<b>$text{'newfs_zfs_parent'}</b>\n";
            print ui_columns_start(
                [
                    $text{'newfs_zfs_fs'},    $text{'newfs_zfs_used'},
                    $text{'newfs_zfs_avail'}, $text{'newfs_zfs_refer'},
                    $text{'newfs_zfs_mount'}
                ]
            );
            print ui_columns_row( [ map { html_escape($_) } @cols[ 0 .. 4 ] ] );
            print ui_columns_end();
            print "<br/>\n";
        }
    }

    # Existing filesystems under this pool
    my $zlist_fs = &backquote_command(
"zfs list -H -r -t filesystem -o name,used,avail,refer,mountpoint $parent_q 2>/dev/null"
    );
    if ($zlist_fs) {
        my @lines = split( /\n/, $zlist_fs );
        if ( @lines && $lines[0] =~ /^\Q$parent\E(\t|$)/ ) {
            shift @lines;
        }
        if (@lines) {
            print "<b>$text{'newfs_zfs_existing'}</b>\n";
            print ui_columns_start(
                [
                    $text{'newfs_zfs_fs'},    $text{'newfs_zfs_used'},
                    $text{'newfs_zfs_avail'}, $text{'newfs_zfs_refer'},
                    $text{'newfs_zfs_mount'}
                ]
            );
            foreach my $ln (@lines) {
                my @cols = split( /\t/, $ln );
                next unless @cols >= 5;
                print ui_columns_row(
                    [ map { html_escape($_) } @cols[ 0 .. 4 ] ] );
            }
            print ui_columns_end();
            print "<br/>\n";
        }
    }

    # Existing volumes under this pool
    my $zlist_vol = &backquote_command(
"zfs list -H -r -t volume -o name,used,avail,refer,volsize $parent_q 2>/dev/null"
    );
    if ($zlist_vol) {
        my @lines = split( /\n/, $zlist_vol );
        if ( @lines && $lines[0] =~ /^\Q$parent\E(\t|$)/ ) {
            shift @lines;
        }
        if (@lines) {
            print "<b>$text{'newfs_zvol_existing'}</b>\n";
            print ui_columns_start(
                [
                    $text{'newfs_zvol_vol'},  $text{'newfs_zfs_used'},
                    $text{'newfs_zfs_avail'}, $text{'newfs_zfs_refer'},
                    $text{'newfs_zvol_volsize'}
                ]
            );
            foreach my $ln (@lines) {
                my @cols = split( /\t/, $ln );
                next unless @cols >= 5;
                print ui_columns_row(
                    [ map { html_escape($_) } @cols[ 0 .. 4 ] ] );
            }
            print ui_columns_end();
            print "<br/>\n";
        }
    }

    my %fs_descriptions = (
        'recordsize' => {
            '128K' => '128K (General/Default)',
            '1M'   => '1M (Media/Large files)',
            '4M'   => '4M',
            '16K'  => '16K (Database)',
            '4K'   => '4K (VM)'
        },
        'compression' => {
            'lz4'  => 'lz4 (Recommended)',
            'off'  => 'off (None)',
            'gzip' => 'gzip (High compression)'
        },
        'atime' => {
            'off' => 'off (Performance)',
            'on'  => 'on (Record access time)'
        },
        'sync' => {
            'disabled' => 'disabled (Performance)',
            'standard' => 'standard (Safety)',
            'always'   => 'always (Maximum Safety)'
        },
        'acltype' => {
            'nfsv4'    => 'nfsv4 (ZFS Default)',
            'posixacl' => 'posixacl (Linux Default)'
        },
        'aclinherit' => {
            'passthrough' => 'passthrough (SMB Recommended)',
            'restricted'  => 'restricted (ZFS Default)'
        },
        'aclmode' => {
            'passthrough' => 'passthrough (SMB Recommended)',
            'discard'     => 'discard (ZFS Default)'
        }
    );
    my @fs_order = (
        'recordsize', 'compression', 'atime',   'sync',
        'exec',       'canmount',    'acltype', 'aclinherit',
        'aclmode',    'xattr'
    );
    my %fs_defaults = (
        'recordsize'  => '128K',
        'compression' => 'lz4',
        'atime'       => 'off',
        'sync'        => 'default',
        'acltype'     => 'nfsv4',
        'aclinherit'  => 'passthrough',
        'aclmode'     => 'passthrough',
        'canmount'    => 'on',
        'exec'        => 'on',
        'xattr'       => 'sa',
    );
    my %fs_opts = (
        'recordsize' =>
          '512, 1K, 2K, 4K, 8K, 16K, 32K, 64K, 128K, 256K, 512K, 1M',
        'compression' => 'on, off, lz4, gzip',
        'atime'       => 'on, off',
        'sync'        => 'standard, always, disabled',
        'exec'        => 'on, off',
        'canmount'    => 'on, off, noauto',
        'acltype'     => 'nfsv4, posixacl',
        'aclinherit'  =>
          'discard, noallow, restricted, passthrough, passthrough-x',
        'aclmode' => 'discard, groupmask, passthrough',
        'xattr'   => 'on, off, sa',
    );
    my %acl_tooltips = (
        'acltype'    => $text{'newfs_zfs_acltype_desc'},
        'aclinherit' => $text{'newfs_zfs_aclinherit_desc'},
        'aclmode'    => $text{'newfs_zfs_aclmode_desc'},
    );

    my $base_url =
        "newfs_form.cgi?device="
      . urlize( $in{'device'} )
      . "&slice=$in{'slice'}";
    $base_url .= "&part=$in{'part'}" if ( $in{'part'} ne '' );
    my @tabs = (
        [ "zfs",  $text{'newfs_zfs_tab_fs'},  $base_url . "&mode=zfs" ],
        [ "zvol", $text{'newfs_zfs_tab_vol'}, $base_url . "&mode=zvol" ],
    );
    print &ui_tabs_start( \@tabs, "mode", $in{'mode'} || $tabs[0]->[0], 1 );
    print &ui_tabs_start_tab( "mode", "zfs" );

    print &ui_form_start( "zfs_create.cgi", "post", undef,
        "onsubmit='return validateFsForm(this)'" );
    print &ui_hidden( "device", $in{'device'} );
    print &ui_hidden( "slice",  $in{'slice'} );
    print &ui_hidden( "part",   $in{'part'} );
    print &ui_hidden( "parent", $parent );

    print &ui_table_start( $text{'newfs_zfs_header'}, 'width=100%', 2 );
    print &ui_table_row( $text{'newfs_zfs_name'},
        html_escape($parent) . "/" . &ui_textbox( "zfs", undef, 24 ) );
    print &ui_table_row( $text{'newfs_zfs_mountpoint'},
            &ui_filebox( 'mountpoint', '', 25, undef, undef, 1 ) . " ("
          . $text{'newfs_zfs_mount_blank'}
          . ")" );
    print &ui_table_end();

    print &ui_table_start( $text{'newfs_zfs_opts'}, "width=100%", undef );
    foreach my $key (@fs_order) {
        my @options;
        push( @options, [ 'default', 'default' ] );
        foreach my $opt ( split( ", ", $fs_opts{$key} ) ) {
            my $label = $fs_descriptions{$key}{$opt} || $opt;
            push( @options, [ $opt, $label ] );
        }
        my $default_val = $fs_defaults{$key} || 'default';
        my $help =
          $acl_tooltips{$key}
          ? "<br><small><i>$acl_tooltips{$key}</i></small>"
          : "";
        my $selected = defined( $in{$key} ) ? $in{$key} : $default_val;
        print ui_table_row( $key . ': ',
            ui_select( $key, $selected, \@options, 1, 0, 1 ) . $help );
    }
    my $add_inherit_default =
      defined( $in{'add_inherit'} ) ? $in{'add_inherit'} : 1;
    print ui_table_row(
        $text{'newfs_zfs_aclflags'},
        ui_checkbox(
            'add_inherit',                    1,
            $text{'newfs_zfs_aclflags_desc'}, $add_inherit_default
        )
    );
    print &ui_table_end();
    print &ui_form_end( [ [ undef, $text{'create'} ] ] );

    print &ui_tabs_end_tab( "mode", "zfs" );

    # ZVOL tab
    print &ui_tabs_start_tab( "mode", "zvol" );
    my %zvol_defaults = (
        'volblocksize'   => '16K',
        'compression'    => 'lz4',
        'sync'           => 'default',
        'logbias'        => 'latency',
        'primarycache'   => 'all',
        'secondarycache' => 'all',
    );
    my %zvol_opts = (
        'volblocksize'   => '512, 1K, 2K, 4K, 8K, 16K, 32K, 64K, 128K',
        'compression'    => 'on, off, lz4, gzip',
        'sync'           => 'standard, always, disabled',
        'logbias'        => 'latency, throughput',
        'primarycache'   => 'all, metadata, none',
        'secondarycache' => 'all, metadata, none',
    );
    my %zvol_desc = (
        'volblocksize' => {
            '512' => '512B',
            '1K'  => '1K',
            '2K'  => '2K',
            '4K'  => '4K (Swap)',
            '8K'  => '8K (Databases)',
            '16K' => '16K (VM/Default)',
            '64K' => '64K (Backups)',
        },
        'logbias' => {
            'latency'    => 'latency (databases, NFS sync)',
            'throughput' => 'throughput (VM, media/backups)',
        },
        'primarycache' => {
            'all'      => 'all (filesystems)',
            'metadata' => 'metadata (VM, iSCSI)',
            'none'     => 'none (Swap)',
        },
        'secondarycache' => {
            'all'      => 'all (general filesystems)',
            'metadata' => 'metadata (VM, databases)',
            'none'     => 'none (media)',
        },
    );

    print &ui_form_start( "zvol_create.cgi", "post", undef,
        "onsubmit='return validateZvolForm(this)'" );
    print &ui_hidden( "device", $in{'device'} );
    print &ui_hidden( "slice",  $in{'slice'} );
    print &ui_hidden( "part",   $in{'part'} );
    print &ui_hidden( "parent", $parent );
    print &ui_table_start( $text{'newfs_zvol_header'}, 'width=100%', 2 );
    print &ui_table_row( $text{'newfs_zvol_name'},
        html_escape($parent) . "/" . &ui_textbox( "zvol", undef, 24 ) );
    print &ui_table_row(
        $text{'newfs_zvol_size'},
        &ui_textbox(
            'size', undef, 20, undef, undef, "oninput='updateRefres()'"
        )
    );
    print &ui_table_end();

    print &ui_table_start( $text{'newfs_zvol_opts'}, "width=100%", undef );
    foreach my $key (
        qw(volblocksize compression sync logbias primarycache secondarycache))
    {
        my @options;
        push( @options, [ 'default', 'default' ] );
        foreach my $opt ( split( ", ", $zvol_opts{$key} ) ) {
            my $label = $zvol_desc{$key}{$opt} || $opt;
            push( @options, [ $opt, $label ] );
        }
        my $default_val = $zvol_defaults{$key} || 'default';
        my $selected    = defined( $in{$key} ) ? $in{$key} : $default_val;
        print ui_table_row( $key . ': ',
            ui_select( $key, $selected, \@options, 1, 0, 1 ) );
    }
    my $sparse_default = defined( $in{'sparse'} ) ? $in{'sparse'} : 1;
    print ui_table_row( $text{'newfs_zvol_sparse'},
            ui_yesno_radio( 'sparse', $sparse_default )
          . " <small>"
          . $text{'newfs_zvol_sparse_desc'}
          . "</small>" );
    print ui_table_row( $text{'newfs_zvol_refreservation'},
        ui_textbox( 'refreservation', 'none', 20 )
          . "<span id='refres_label'></span>" );
    print &ui_table_end();
    print &ui_form_end( [ [ undef, $text{'create'} ] ] );
    print &ui_tabs_end_tab( "mode", "zvol" );

    print &ui_tabs_end(1);

    print <<'EOF';
<script type="text/javascript">
function validateFsForm(form) {
	var name = form.zfs.value;
	var nameRegex = /^[a-zA-Z0-9_\-.:]+$/;
	if (!name || !nameRegex.test(name)) {
		alert("Invalid Name. Please use alphanumeric characters, -, _, ., or :");
		return false;
	}
	return true;
}
function validateZvolForm(form) {
	var name = form.zvol.value;
	var nameRegex = /^[a-zA-Z0-9_\-.:]+$/;
	if (!name || !nameRegex.test(name)) {
		alert("Invalid Name. Please use alphanumeric characters, -, _, ., or :");
		return false;
	}
	if (name.indexOf("/") !== -1 || name.indexOf("@") !== -1 || name.indexOf("#") !== -1) {
		alert("Invalid Name. Do not include '/', '@' or '#'.");
		return false;
	}
	if (name.charAt(0) === "-" || name.charAt(0) === ".") {
		alert("Invalid Name. It cannot start with '-' or '.'.");
		return false;
	}
	if (name.indexOf("..") !== -1) {
		alert("Invalid Name. It cannot contain '..'.");
		return false;
	}
	var size = form.size.value;
	var regex = /^\d+(\.\d+)?[KMGTP]?$/i;
	if (!size || !regex.test(size) || parseFloat(size) <= 0) {
		alert("Invalid size format. Please use format like 10G, 500M, etc.");
		return false;
	}
	var ref = form.refreservation.value;
	if (ref && ref.toLowerCase() !== "none") {
		if (!regex.test(ref) || parseFloat(ref) <= 0) {
			alert("Invalid refreservation format. Please use format like 10G, 500M, etc.");
			return false;
		}
		// Compare sizes when possible
		function toBytes(v) {
			var m = v.match(/^(\d+(?:\.\d+)?)([KMGTP]?)$/i);
			if (!m) return null;
			var n = parseFloat(m[1]);
			var u = (m[2] || "").toUpperCase();
			var mult = 1;
			if (u === "K") mult = 1024;
			else if (u === "M") mult = 1024*1024;
			else if (u === "G") mult = 1024*1024*1024;
			else if (u === "T") mult = 1024*1024*1024*1024;
			else if (u === "P") mult = 1024*1024*1024*1024*1024;
			return n * mult;
		}
		var sizeB = toBytes(size);
		var refB = toBytes(ref);
		if (sizeB && refB && refB > sizeB) {
			alert("Refreservation cannot be larger than the volume size.");
			return false;
		}
	}
	return true;
}
function updateRefres() {
	var sparseList = document.getElementsByName("sparse");
	var refres = document.getElementsByName("refreservation")[0];
	var size = document.getElementsByName("size")[0];
	var label = document.getElementById("refres_label");
	if (!sparseList || sparseList.length === 0 || !refres || !size || !label) return;
	var sparseOn = false;
	for (var i = 0; i < sparseList.length; i++) {
		if (sparseList[i].checked && sparseList[i].value === "1") {
			sparseOn = true;
		}
	}
	if (sparseOn) {
		refres.disabled = false;
		var sVal = size.value ? size.value : "Size";
		label.innerHTML = " (" + sVal + " max, default: none)";
	} else {
		refres.disabled = true;
		label.innerHTML = " (" + "Volume is thick provisioned)";
	}
}
function bindSparseRadios() {
	var sparseList = document.getElementsByName("sparse");
	if (!sparseList) return;
	for (var i = 0; i < sparseList.length; i++) {
		sparseList[i].onclick = updateRefres;
	}
}
window.onload = function() { updateRefres(); bindSparseRadios(); };
</script>
EOF

    if ( $in{'part'} ne '' ) {
        &ui_print_footer(
            "edit_part.cgi?device=$in{'device'}&"
              . "slice=$in{'slice'}&part=$in{'part'}",
            $text{'part_return'}
        );
    }
    else {
        &ui_print_footer(
            "edit_slice.cgi?device=$in{'device'}&" . "slice=$in{'slice'}",
            $text{'slice_return'} );
    }
    exit;
}

# Default: UFS newfs form
&ui_print_header( $object->{'desc'}, $text{'newfs_title'}, "" );

my $confirm_msg = $text{'confirm_overwrite'}
  || 'You will destroy/overwrite existing data structures. Continue?';
my $confirm_js = $confirm_msg;
$confirm_js =~ s/\\/\\\\/g;
$confirm_js =~ s/'/\\'/g;
$confirm_js =~ s/\r?\n/\\n/g;
print &ui_form_start( "newfs.cgi", "post", undef,
    "onsubmit=\"return confirm('$confirm_js')\"" );
print &ui_hidden( "device", $in{'device'} );
print &ui_hidden( "slice",  $in{'slice'} );
print &ui_hidden( "part",   $in{'part'} );
print &ui_table_start( $text{'newfs_header'}, undef, 2 );

print &ui_table_row( $text{'part_device'}, "<tt>$object->{'device'}</tt>" );

print &ui_table_row( $text{'newfs_free'},
    &ui_opt_textbox( "free", undef, 4, $text{'newfs_deffree'} ) . "%" );

print &ui_table_row( $text{'newfs_trim'}, &ui_yesno_radio( "trim", 0 ) );

print &ui_table_row( $text{'newfs_label'},
    &ui_opt_textbox( "label", undef, 20, $text{'newfs_none'} ) );

print &ui_table_end();
print &ui_form_end( [ [ undef, $text{'save'} ] ] );

if ( $in{'part'} ne '' ) {
    &ui_print_footer(
        "edit_part.cgi?device=$in{'device'}&"
          . "slice=$in{'slice'}&part=$in{'part'}",
        $text{'part_return'}
    );
}
else {
    &ui_print_footer(
        "edit_slice.cgi?device=$in{'device'}&" . "slice=$in{'slice'}",
        $text{'slice_return'} );
}
