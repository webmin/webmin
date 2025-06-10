#!/usr/local/bin/perl
# view.cgi
# Output the contents of a file

require './software-lib.pl';
$p = $ENV{'PATH_INFO'};

# Try to guess type from filename
if ($p =~ /\.([^\.\/]+)$/) {
	$ext = lc($1);
	&get_miniserv_config(\%miniserv);
	open(MIME, "<$miniserv{'mimetypes'}");
	while(<MIME>) {
		s/#.*//g;
		if (/(\S+)\s+(.*)/) {
			foreach $e (split(/\s+/, $2)) {
				if ($ext eq $e) {
					$type = $1;
					last;
					}
				}
			}
		}
	close(MIME);
	}
if (!$type) {
	# No idea .. use the 'file' command
	if (`file "$p"` =~ /text|script/) {
		$type = "text/plain";
		}
	else {
		$type = "application/octet-stream";
		}
	}

# Dump the file
if (!open(FILE, "<$p")) {
	print "Content-type: text/plain\n\n";
	print &text('list_eview', $p, $!),"\n";
	}
else {
	@st = stat($p);
	print "Content-length: $st[7]\n";
	print "Content-type: $type\n\n";
	my $bs = &get_buffer_size();
	while(read(FILE, $buf, $bs)) {
		print $buf;
		}
	close(FILE);
	}

