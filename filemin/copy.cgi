#!/usr/local/bin/perl

require './filemin-lib.pl';
&ReadParse();

get_paths();

my @names = split(/\0/, $in{'name'});
foreach $name (@names) {
	&validate_filename_path($name);
	}

open(my $fh, ">", &get_paste_buffer_file()) or die "Error: $!";
print $fh "copy\n";
print $fh "$path\n";
#$info = "Copied ".scalar(@list)." files to buffer";

foreach $name (@names) {
	print $fh "$name\n";
	}

close($fh);

&redirect("index.cgi?path=".&urlize($path));
