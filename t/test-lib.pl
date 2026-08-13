# Common helpers for Webmin tests.

use strict;
use warnings;

# write_text(file, contents)
# Writes a text fixture and fails the test immediately on an I/O error
sub write_text
{
my ($file, $text) = @_;
open(my $fh, ">", $file) or die "open $file: $!";
print $fh $text;
close($fh) or die "close $file: $!";
}

# read_text(file)
# Returns the complete contents of a text fixture
sub read_text
{
my ($file) = @_;
open(my $fh, "<", $file) or die "open $file: $!";
local $/;
my $text = <$fh>;
close($fh) or die "close $file: $!";
return $text;
}

1;
