#!/usr/local/bin/perl
# tunefs.cgi
# You can tune a filesystem, but you can't tuna fish

require './format-lib.pl';
$access{'view'} && &error($text{'ecannot'});
&ReadParse();
&can_edit_disk($in{'dev'}) || &error($text{'tunefs_ecannot'});
&error_setup($text{'tunefs_err'});

$cmd = "tunefs";
$cmd .= &opt_check("tunefs_a", '\d+', "-a");
$cmd .= &opt_check("tunefs_d", '\d+', "-d");
$cmd .= &opt_check("tunefs_e", '\d+', "-e");
$cmd .= &opt_check("tunefs_m", '\d+', "-m");
$cmd .= $in{tunefs_o} ? " -o $in{tunefs_o}" : "";
$in{dev} =~ s/dsk/rdsk/g;
$cmd .= " $in{dev}";

&ui_print_header(undef, $text{'tunefs_title'}, "");

print &text('tunefs_exec', "<tt>$cmd</tt>"),"<p>\n";
print "<pre>\n";
open(TUNEFS, "$cmd 2>&1 </dev/null |");
while(<TUNEFS>) { print; }
close(TUNEFS);
print "</pre>\n";
if ($?) { print "$text{'tunefs_failed'}<p>\n"; }
else { print "$text{'tunefs_ok'}<p>\n"; }

&ui_print_footer("", $text{'index_return'});

