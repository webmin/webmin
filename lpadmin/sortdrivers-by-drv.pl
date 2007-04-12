#!/usr/local/bin/perl

open(DRIVERS, "drivers");
@dr = <DRIVERS>;
close(DRIVERS);

@dr = sort { $a =~ /^(\S+)\s+.*/; $x = $1; $b =~ /^(\S+)\s+.*/; $x cmp $1; } @dr;
open(DRIVERS, ">drivers");
print DRIVERS @dr;
close(DRIVERS);

