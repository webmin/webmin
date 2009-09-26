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
&is_under_directory($odir, $full) || &error($text{'view_efile'});

# Show index page
if (-d $full && -r "$full/index.html") {
	$full = "$full/index.html";
	}

# Display file contents
if ($full =~ /\.(html|htm)$/i && !$config{'naked'}) {
	open(FILE, $full) || &error($text{'view_eopen'}." : $full");
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
elsif (-d $full) {
	# Show directory listing
	&ui_print_header(undef, $text{'view_title'}, "");
	print "<ul>\n";
	opendir(DIR, $full);
	foreach $f (sort { lc($a) cmp lc($b) } readdir(DIR)) {
		next if ($f eq "." || $f eq "..");
		print "<li><a href='$f/'>$f</a>\n";
		}
	closedir(DIR);
	print "</ul>\n";
	&ui_print_footer("", $text{'index_return'});
	}
else {
	# Show RAW file contents
	open(FILE, $full) || &error($text{'view_eopen'}." : $full");
	print "Content-type: ",&guess_mime_type($full, "text/plain"),"\n";
	print "\n";
	while(read(FILE, $buf, 1024)) {
		print $buf;
		}
	close(FILE);
	}

