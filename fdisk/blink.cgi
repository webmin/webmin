#!/usr/bin/perl
# blink.cgi

require './fdisk-lib.pl';
&ReadParse();
@dlist = &list_disks_partitions();
$d = $dlist[$in{'disk'}];
&can_edit_disk($d->{'device'}) ||
	&error($text{'edit_ecannot'});

&ui_print_header($d->{'desc'}, $text{'blink_title'}, "");

print "<p>$text{ 'blink_desc' }<p>\n";

&identify_disk($d);

print "<br><br><a href=index.cgi>$text{blink_back}</a><br><br>\n";
