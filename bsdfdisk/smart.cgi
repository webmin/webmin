#!/usr/local/bin/perl
# Show SMART status for a given device
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our ( %in, %text, $module_name );
&ReadParse();

# Validate device param
$in{'device'} =~ /^[a-zA-Z0-9_\/.-]+$/
  or &error( $text{'disk_edevice'} || 'Invalid device' );
$in{'device'} !~ /\.\./ or &error( $text{'disk_edevice'} || 'Invalid device' );

# Check smartctl availability
&has_command('smartctl')
  or &error( $text{'index_ecmd'}
    ? &text( 'index_ecmd', 'smartctl' )
    : 'smartctl not available' );

my $device   = $in{'device'};
my $dev_html = &html_escape($device);

&ui_print_header( $dev_html, $text{'disk_smart'} || 'SMART Status', "" );

print "<div class='panel panel-default'>\n";
print
"<div class='panel-heading'><h3 class='panel-title'>SMART status for <tt>$dev_html</tt></h3></div>\n";
print "<div class='panel-body'>\n";

sub _smartctl_needs_type {
    my ($out) = @_;
    return ( $out =~ /Please specify device type with the -d option/i
          || $out =~ /Unknown USB bridge/i );
}

sub _smartctl_no_smart {
    my ($out) = @_;
    return ( $out =~ /Read Device Identity failed/i
          || $out =~ /unsupported scsi opcode/i
          || $out =~ /Device does not support SMART/i
          || $out =~ /SMART support is:\s*Unavailable/i
          || $out =~ /mandatory SMART command failed/i );
}

my $cmd      = "smartctl -a " . &quote_path($device) . " 2>&1";
my $out      = &backquote_command($cmd);
my $used_cmd = $cmd;
my $note;

# If smartctl requests a device type or indicates SMART unsupported, try common USB bridge options
if ( _smartctl_needs_type($out) || _smartctl_no_smart($out) ) {
    my @types =
      qw(sat,auto sat scsi auto usbjmicron usbprolific usbcypress usbsunplus);
    my $best_out = $out;
    my $best_cmd = $cmd;
    foreach my $t (@types) {
        my $try_cmd = "smartctl -a -d $t " . &quote_path($device) . " 2>&1";
        my $try_out = &backquote_command($try_cmd);

        # If it still needs a type, keep trying
        if ( _smartctl_needs_type($try_out) ) {
            $best_out = $try_out;
            $best_cmd = $try_cmd;
            next;
        }

        # If SMART commands fail, try permissive once
        if ( _smartctl_no_smart($try_out) ) {
            my $perm_cmd = "smartctl -a -T permissive -d $t "
              . &quote_path($device) . " 2>&1";
            my $perm_out = &backquote_command($perm_cmd);
            if (   !_smartctl_needs_type($perm_out)
                && !_smartctl_no_smart($perm_out) )
            {
                $out      = $perm_out;
                $used_cmd = $perm_cmd;
                last;
            }
            $best_out = $perm_out;
            $best_cmd = $perm_cmd;
            next;
        }

        # Success
        $out      = $try_out;
        $used_cmd = $try_cmd;
        last;
    }
    if ( $used_cmd eq $cmd ) {
        $out      = $best_out;
        $used_cmd = $best_cmd;
        if ( _smartctl_no_smart($out) ) {
            $note = "SMART may not be supported by this USB device or bridge.";
        }
    }
}

if ($note) {
    print "<div class='alert alert-warning'>$note</div>\n";
}
print "<pre>" . &html_escape("Command: $used_cmd\n\n$out") . "</pre>\n";
print "</div></div>\n";

&ui_print_footer( "edit_disk.cgi?device=" . &urlize($device),
    $text{'disk_return'} );
