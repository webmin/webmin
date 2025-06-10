#!/usr/local/bin/perl
# Perform some action

require './smart-status-lib.pl';
&ReadParse();
$mode = $in{'short'} ? "short" :
	$in{'ext'} ? "ext" : "data";
&ui_print_header(undef, $text{$mode.'_title'}, "");

@drives = &list_smart_disks_partitions();
($d) = grep { $_->{'device'} eq $in{'drive'} &&
	      $_->{'subdisk'} == $in{'subdisk'} } @drives;
print &text($mode."_doing", $d->{'desc'}),"\n";
if ($mode eq "short") {
	($ok, $out) = &short_test($in{'drive'}, $d);
	}
elsif ($mode eq "ext") {
	($ok, $out) = &ext_test($in{'drive'}, $d);
	}
elsif ($mode eq "data") {
	($ok, $out) = &data_test($in{'drive'}, $d);
	}
print "<pre>$out</pre>\n";
if ($ok) {
	print $text{$mode."_ok"},"<p>\n";
	}
else {
	print $text{$mode."_failed"},"<p>\n";
	}

&ui_print_footer("index.cgi?drive=$in{'drive'}", $text{'index_return'});
