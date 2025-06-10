#!/usr/local/bin/perl
# Show a QR code based on parameters

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
$main::no_acl_check = 1;
require './webmin-lib.pl';

our (%in, %text, %gconfig, %config);
&ReadParse();
&error_setup($text{'qr_err'});

$in{'str'} || &error($text{'qr_estr'});
my ($img, $mime) = &generate_qr_code($in{'str'}, $in{'size'});
$img || &error($mime);

&PrintHeader(undef, $mime);
print $img;
