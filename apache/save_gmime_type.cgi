#!/usr/local/bin/perl
# save_gmime_type.cgi
# Add or change a MIME type

require './apache-lib.pl';
&ReadParse();
$access{'global'}==1 || &error($text{'mime_ecannot'});

&error_setup($text{'mime_err'});
if ($in{'type'} !~ /^(\S+)\/(\S+)$/) {
	&error(&text('mime_etype', $in{'type'}));
	}

&lock_file($in{'file'});
open(MIME, $in{'file'});
@mime = <MIME>;
close(MIME);
$line = "$in{'type'} ".join(" ", split(/\s+/, $in{'exts'}))."\n";
if ($in{'line'}) {
	$mime[$in{'line'}] = $line;
	}
else {
	push(@mime, $line);
	}
&open_tempfile(MIME, "> $in{'file'}");
&print_tempfile(MIME, @mime);
&close_tempfile(MIME);
&unlock_file($in{'file'});
&webmin_log("mime", $in{'line'} ? 'modify' : 'create', $in{'type'}, \%in);
&redirect("edit_global.cgi?type=6");

