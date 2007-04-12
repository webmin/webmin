#!/usr/local/bin/perl
# allmanual_save.cgi
# Save an entire config file

require './proftpd-lib.pl';
&ReadParseMime();

$conf = &get_config();
@files = &unique(map { $_->{'file'} } @$conf);
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});

$temp = &transname();
system("cp ".quotemeta($in{'file'})." $temp");
$in{'data'} =~ s/\r//g;
&open_lock_tempfile(FILE, ">$in{'file'}");
&print_tempfile(FILE, $in{'data'});
&close_tempfile(FILE);
if ($config{'test_manual'}) {
	$err = &test_config();
	if ($err) {
		system("mv $temp ".quotemeta($in{'file'}));
		&error(&text('manual_etest', "<pre>$err</pre>"));
		}
	}
unlink($temp);
&redirect("");

