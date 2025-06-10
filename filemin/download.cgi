#!/usr/local/bin/perl

require './filemin-lib.pl';

use File::Basename;
use Cwd 'abs_path';

&ReadParse();

get_paths();

my $file = &resolve_links(&simplify_path($cwd.'/'.$in{'file'}));
my $error = 1;
for $allowed_path (@allowed_paths) {
	if (&is_under_directory($allowed_path, $file)) {
		$error = 0;
		}
	}
$error && &error(&text('notallowed', &html_escape($file),
		   &html_escape(join(" , ", @allowed_paths))));
my $size = -s "$file";
(my $name, my $dir, my $ext) = fileparse($file, qr/\.[^.]*/);
print "Content-Type: application/x-download\n";
print "Content-Disposition: attachment; filename=\"$name$ext\"\n";
print "Content-Length: $size\n\n";
open (FILE, "< $file") or die "can't open $file: $!";
binmode FILE;
local $/ = \&get_buffer_size_binary();
while (<FILE>) {
    print $_;
}
close FILE;
