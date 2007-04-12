#!/usr/local/bin/perl
# root.cgi
# Return information about the root directory

require './file-lib.pl';
print "Content-type: text/plain\n\n";
&go_chroot();
print &file_info_line("/"),"\n";
