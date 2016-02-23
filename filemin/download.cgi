#!/usr/bin/perl

require './filemin-lib.pl';
use lib './lib';

use File::Basename;
use Cwd 'abs_path';

&ReadParse();

get_paths();

my $file = $cwd.'/'.$in{'file'};
my $size = -s "$file";
(my $name, my $dir, my $ext) = fileparse($file, qr/\.[^.]*/);
print "Content-Type: application/x-download\n";
print "Content-Disposition: attachment; filename=\"$name$ext\"\n";
print "Content-Length: $size\n\n";
open (FILE, "< $file") or die "can't open $file: $!";
binmode FILE;
local $/ = \102400;
while (<FILE>) {
    print $_;
}
close FILE;
