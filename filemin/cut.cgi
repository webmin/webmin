#!/usr/local/bin/perl

require './filemin-lib.pl';
&ReadParse();

get_paths();

open(my $fh, ">", &get_paste_buffer_file()) or die "Error: $!";
print $fh "cut\n";
print $fh "$path\n";
#$info = "Copied ".scalar(@list)." files to buffer";

foreach $name (split(/\0/, $in{'name'})) {
    print $fh "$name\n";
}

close($fh);

&redirect("index.cgi?path=".&urlize($path));
