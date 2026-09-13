#!/usr/local/bin/perl
# view.cgi
# Output the contents of a file

require './software-lib.pl';
&ReadParse();
$p = $in{'file'};

# Only show files listed for the selected package.
&is_package_file($in{'package'}, $in{'version'}, $p) ||
	&error($text{'list_enotpackage'});

if (!open(FILE, "<", $p)) {
	print "Content-type: text/plain\n\n";
	print &text('list_eview', $p, $!),"\n";
	exit;
	}
my @st = stat(FILE);

# Try to guess type from filename
if ($p =~ /\.([^\.\/]+)$/) {
	$type = &guess_mime_type($p);
	}
if (!$type) {
	# No idea .. use the 'file' command
	my $out = &backquote_command("file ".quotemeta($p)." 2>/dev/null");
	if ($out =~ /text|script/) {
		$type = "text/plain";
		}
	else {
		$type = "application/octet-stream";
		}
	}

# Dump the file
print "Content-length: $st[7]\n";
print "Content-type: $type\n\n";
my $bs = &get_buffer_size();
while(read(FILE, $buf, $bs)) {
	print $buf;
	}
close(FILE);
