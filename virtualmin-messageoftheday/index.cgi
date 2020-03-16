#!/usr/local/bin/perl

require './virtualmin-messageoftheday-lib.pl';
&ui_print_header(undef, $text{'index_header'}, "", undef, 1, 1);

open(FILE, "<".$config{'path'});
while(<FILE>) {
	$motd .= $_;
	}
close(FILE);

if ($motd !~ /\S/) {
	print "<b>",&text('index_none', "<tt>$config{'path'}</tt>"),
	      "</b><p>\n";
	}
elsif ($config{'html'}) {
	$motd =~ s/^[\000-\377]*<BODY.*>//i;
	$motd =~ s/<\/BODY>[\000-\377]*$//i;
	print $motd;
	}
else {
	print "<pre>$motd</pre>\n";
	}

print "<hr>\n";



&ui_print_footer("/", $text{'index'});

