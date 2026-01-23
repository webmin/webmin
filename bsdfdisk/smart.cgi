#!/usr/local/bin/perl
# Show SMART status for a given device
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './bsdfdisk-lib.pl';
our (%in, %text, $module_name);
&ReadParse();

# Validate device param
$in{'device'} =~ /^[a-zA-Z0-9_\/.-]+$/ or &error($text{'disk_edevice'} || 'Invalid device');
$in{'device'} !~ /\.\./ or &error($text{'disk_edevice'} || 'Invalid device');

# Check smartctl availability
&has_command('smartctl') or &error($text{'index_ecmd'} ? &text('index_ecmd','smartctl') : 'smartctl not available');

my $device = $in{'device'};
my $dev_html = &html_escape($device);

&ui_print_header($dev_html, $text{'disk_smart'} || 'SMART Status', "");

print "<div class='panel panel-default'>\n";
print "<div class='panel-heading'><h3 class='panel-title'>SMART status for <tt>$dev_html</tt></h3></div>\n";
print "<div class='panel-body'>\n";
my $cmd = "smartctl -a " . &quote_path($device) . " 2>&1";
my $out = &backquote_command($cmd);
print "<pre>" . &html_escape("Command: $cmd\n\n$out") . "</pre>\n";
print "</div></div>\n";

&ui_print_footer("edit_disk.cgi?device=".&urlize($device), $text{'disk_return'});
