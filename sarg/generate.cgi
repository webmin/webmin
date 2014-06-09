#!/usr/local/bin/perl
# Immediately generate the report

require './sarg-lib.pl';
&ReadParse();
&error_setup($text{'gen_err'});
if (!$in{'range_def'}) {
	$in{'rfrom'} =~ /^\d+$/ || &error($text{'gen_efrom'});
	$in{'rto'} =~ /^\d+$/ || &error($text{'gen_eto'});
	}

$theme_no_table++;
$| = 1;
&ui_print_header(undef, $text{'gen_title'}, "");

$conf = &get_config();
$sfile = &find_value("access_log", $conf);
print "<b>",&text('gen_header', "<tt>$sfile</tt>"),"</b><br>\n";
print "<pre>";
$rv = &generate_report(STDOUT, 1, $in{'clear'},
		       $in{'range_def'} ? ( ) : ( $in{'rfrom'}, $in{'rto'} ) );
print "</pre>\n";

$odir = &find_value("output_dir", $conf);
$odir ||= &find_value("output_dir", $conf, 1);
if ($rv && -r "$odir/index.html") {
	print "<b>$text{'gen_done'}</b><p>\n";
	print &ui_link("view.cgi/index.html","$text{'gen_view'}")."<p>\n";
	}
elsif ($rv) {
	print "<b>$text{'gen_nothing'}</b><p>\n";
	}
else {
	print "<b>$text{'gen_failed'}</b><p>\n";
	}

&webmin_log("generate");
&ui_print_footer("", $text{'index_return'});

