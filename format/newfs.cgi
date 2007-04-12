#!/usr/local/bin/perl
# newfs.cgi
# Create a new filesystem 

require './format-lib.pl';
$access{'view'} && &error($text{'ecannot'});
&ReadParse();
&can_edit_disk($in{'dev'}) || &error($text{'newfs_ecannot'});
&error_setup($text{'newfs_err'});
$cmd = "newfs";
$cmd .= &opt_check("ufs_a", '\d+', "-a");
$cmd .= &opt_check("ufs_b", '\d+', "-b");
$cmd .= &opt_check("ufs_c", '\d+', "-c");
$cmd .= &opt_check("ufs_d", '\d+', "-d");
$cmd .= &opt_check("ufs_f", '\d+', "-f");
$cmd .= &opt_check("ufs_i", '\d+', "-i");
$cmd .= &opt_check("ufs_m", '\d+', "-m");
$cmd .= &opt_check("ufs_n", '\d+', "-n");
$cmd .= $in{ufs_o} ? " -o $in{ufs_o}" : "";
$cmd .= &opt_check("ufs_r", '\d+', "-r");
$cmd .= &opt_check("ufs_s", '\d+', "-s");
$cmd .= &opt_check("ufs_t", '\d+', "-t");
$cmd .= &opt_check("ufs_cb", '\d+', "-C");
$in{dev} =~ s/dsk/rdsk/g;
$cmd .= " $in{dev}";

&ui_print_header(undef, $text{'newfs_title'}, "");

print &text('newfs_exec', "<tt>$cmd</tt>"),"<p>\n";
print "<pre>\n";
open(MKFS, "$cmd 2>&1 </dev/null |");
while(<MKFS>) { print; }
close(MKFS);
print "</pre>\n";
if ($?) { print "$text{'newfs_failed'} <p>\n"; }
else { print "$text{'newfs_ok'} <p>\n"; }

&ui_print_footer("", $text{'index_return'});

