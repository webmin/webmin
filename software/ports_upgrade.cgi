#!/usr/local/bin/perl
# Update ports snapshot

require './software-lib.pl';
&foreign_require("proc");

&ui_print_unbuffered_header(undef, $text{'ports_upgrade'}, "");

foreach my $cmd ("portsnap fetch",
		 "portsnap update || portsnap extract") {
	print &text('ports_running', "<tt>$cmd</tt>"),"<br>\n";
	print "<pre>";
	($fh, $pid) = &proc::pty_process_exec($cmd);
	while(<$fh>) {
		print &html_escape($_);
		}
	close($fh);
	print "</pre>";
	last if ($?);
	}

&ui_print_footer("", $text{'index_return'});

