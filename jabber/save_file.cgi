#!/usr/local/bin/perl
# save_file.cgi
# Save the jabber config file, with verification

require './jabber-lib.pl';
&ReadParseMime();
&error_setup($text{'file_err'});

# Write to a temp file and check it
$temp = &transname();
$in{'file'} =~ s/\r//g;
open(TEMP, ">$temp");
print TEMP $in{'file'};
close(TEMP);
local $xml = new XML::Parser('Style' => 'Tree');
eval { $xml->parsefile($temp); };
unlink($temp);
if ($@) {
	$err = $@;
	$err =~ s/\s+at\s+(\S+)\s+line\s+(\d+)$//;
	&error($err);
	}

# Write to the real file
&open_tempfile(FILE, ">$config{'jabber_config'}");
&print_tempfile(FILE, $in{'file'});
&close_tempfile(FILE);
&redirect("");

