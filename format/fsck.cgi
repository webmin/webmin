#!/usr/local/bin/perl
# fsck.cgi
# Do the actual checking of a filesystem

require './format-lib.pl';
$access{'view'} && &error($text{'ecannot'});
&ReadParse();
&can_edit_disk($in{'dev'}) || &error($text{'fsck_ecannot'});
&ui_print_header(undef, $text{'fsck_title'}, "");
$in{dev} =~ s/dsk/rdsk/g;
$cmd = "fsck -F ufs $in{mode} $in{dev}";

print &text('fsck_exec', "<tt>$cmd</tt>"),"<p>\n";
print "<pre>\n";
open(FSCK, "$cmd 2>&1 </dev/null |");
while(<FSCK>) { print; }
close(FSCK);
print "</pre>\n";
print "... ",&fsck_error($?/256),"<p>\n";

&ui_print_footer("", $text{'index_return'});

