#!/usr/local/bin/perl
# cachemgr.cgi
# Run the squid cachemgr.cgi program

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config, $module_name);
require './squid-lib.pl';
$access{'cms'} || &error($text{'cach_ecannot'});
my ($mgr) = glob($config{'cachemgr_path'});
&same_file($0, $mgr) && &error($text{'cach_esame'});
if (&has_command($mgr)) {
	$| = 1;
	my $temp;
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		# Deal with POST data
		my $post;
		&read_fully(\*STDIN, \$post, $ENV{'CONTENT_LENGTH'});
		$temp = &transname();
		my $fh = "TEMP";
		&open_tempfile($fh, ">$temp", 0, 1);
		&print_tempfile($fh, $post);
		&close_tempfile($fh);
		open(MGR, "$mgr ".join(" ", @ARGV)." <$temp |");
		}
	else {
		open(MGR, "$mgr ".join(" ", @ARGV)." |");
		}
	while(<MGR>) {
		print;
		}
	close(MGR);
	unlink($temp) if ($temp);
	}
else {
	&ui_print_header(undef, $text{'cach_err'}, "");
	print &text('cach_nfound',$mgr,$module_name);
	print "\n<p>\n";
	}
&ui_print_footer("", $text{'cach_return'});

