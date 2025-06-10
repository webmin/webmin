#!/usr/local/bin/perl
# mkfs.cgi
# Create a new linux filesystem

require './raid-lib.pl';
&foreign_require("proc");

&ReadParse();
&error_setup($text{'mkfs_err'});
$conf = &get_raidtab();
$raid = $conf->[$in{'idx'}];
$cmd = &fdisk::mkfs_parse($in{'fs'}, $raid->{'value'});

$lvl = &find_value('raid-level', $raid->{'members'});
$chunk = &find_value('chunk-size', $raid->{'members'});
if ($lvl >= 4 && $in{'fs'} =~ /^ext\d+$/) {
	$bs = $in{'ext2_b_def'} ? 4096 : $in{'ext2_b'};
	}

&ui_print_unbuffered_header(undef, $text{'mkfs_title'}, "");
print &text('mkfs_exec', "<tt>$cmd</tt>"),"<p>\n";
print "<pre>\n";
&proc::safe_process_exec_logged($cmd, 0, 0, STDOUT, undef, 1);
print "</pre>\n";

if ($?) { print "<b>$text{'mkfs_failed'}</b> <p>\n"; }
else { print "$text{'mkfs_ok'} <p>\n"; }

$config{'lasttype_'.$raid->{'value'}} = $in{'fs'};
&save_module_config();
&webmin_log("mkfs", undef, $raid->{'value'}, \%in);

&ui_print_footer("", $text{'index_return'});

