#!/usr/local/bin/perl
# allmanual_save.cgi
# Save an entire config file

require './apache-lib.pl';
&ReadParseMime();
$access{'types'} eq '*' && $access{'virts'} eq '*' ||
	&error($text{'manual_ecannot'});

$conf = &get_config();
@files = &unique(map { $_->{'file'} } @$conf);
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});

$temp = &transname();
&execute_command("cp ".quotemeta($in{'file'})." $temp");
$in{'data'} =~ s/\r//g;
&lock_file($in{'file'});
&open_tempfile(FILE, ">$in{'file'}");
&print_tempfile(FILE, $in{'data'});
&close_tempfile(FILE);
&unlock_file($in{'file'});
if ($config{'test_manual'}) {
	$err = &test_config();
	if ($err) {
		&execute_command("mv $temp '$in{'file'}'");
		&error(&text('manual_etest', "<pre>$err</pre>"));
		}
	}
unlink($temp);
&format_config_file($in{'file'});
&webmin_log("manual", undef, undef, { 'file' => $in{'file'} });
&redirect("index.cgi?mode=global");

