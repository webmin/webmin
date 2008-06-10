#!/usr/local/bin/perl
# cachemgr.cgi
# Run the squid cachemgr.cgi program

require './squid-lib.pl';
$access{'cms'} || &error($text{'cach_ecannot'});
($mgr) = glob($config{'cachemgr_path'});
&same_file($0, $mgr) && &error($text{'cach_esame'});
if (&has_command($mgr)) {
	$| = 1;
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		# Deal with POST data
		&read_fully(STDIN, \$post, $ENV{'CONTENT_LENGTH'});
		$temp = &transname();
		open(TEMP, ">$temp");
		print TEMP $post;
		close(TEMP);
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

