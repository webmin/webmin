#!/usr/local/bin/perl
# view_log.cgi
# Display the report for some log file

require './sarg-lib.pl';
&ReadParse();

$file = $ENV{'PATH_INFO'} || "/index.html";
$file =~ /\.\./ || $file =~ /\<|\>|\||\0/ && &error($text{'view_efile'});

$conf = &get_config();
$odir = &find_value("output_dir", $conf);
$odir ||= &find_value("output_dir", $conf, 1);
$odir || &error($text{'view_eodir'});
$full = "$odir$file";
open(FILE, $full) || &error($text{'view_eopen'}." : $full");

# Display file contents
if ($full =~ /\.(html|htm)$/i && !$config{'naked'}) {
	while(read(FILE, $buf, 1024)) {
		$data .= $buf;
		}
	close(FILE);
	if ($data =~ /<TITLE>(.*)<\/TITLE>/i) {
		$title = $1;
		}
	$data =~ s/^[\000-\377]*<BODY[^>]*>//i;
	$data =~ s/<\/BODY>[\000-\377]*$//i;

	&ui_print_header(undef, $title || $text{'view_title'}, "");
	print "<div id=sarg-report>\n";
	print $data;
	print "</div>\n";
	&ui_print_footer("", $text{'index_return'});
	}
else {
	print "Content-type: ",$full =~ /\.png$/i ? "image/png" :
			       $full =~ /\.gif$/i ? "image/gif" :
			       $full =~ /\.(jpg|jpeg)$/i ? "image/jpeg" :
			       $full =~ /\.(html|htm)$/i ? "text/html" :
							   "text/plain","\n";
	print "\n";
	while(read(FILE, $buf, 1024)) {
		print $buf;
		}
	close(FILE);
	}

