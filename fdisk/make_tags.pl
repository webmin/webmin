#!/usr/bin/perl

while(<STDIN>) {
	s/\s/ /g;
	$list .= $_;
	}

while($list =~ /^\s*([a-z0-9]{1,2})\s+(.{15})(.*)$/) {
	$code = $1; $name = $2; $list = $3;
	$name =~ s/\s+$//;
	print "'$code' => '$name',\n";
	}
