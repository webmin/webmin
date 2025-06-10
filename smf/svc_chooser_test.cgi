#!/usr/local/bin/perl

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("smf", "man", "doc", "howto"));

print "<form action=\"svc_chooser_test.cgi\">\n";
$form = 0;
$name = "test";
print "<input size=80 name=\"$name\" value=\"\">\n";
print_svc_chooser("$name", $form, "Choose Service FMRI", "both", "0");
$name = "test2";
print "<input size=80 name=\"$name\" value=\"\">\n";
print "<input type=button onClick='ifield = document.forms[$form].$name; chooser= window.open(\"svc_chooser.cgi?type=both&add=1\", \"chooser\", \"toolbar=no,menubar=no,scrollbar=no,width=400,height=300\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";

&ui_print_footer("/", $text{'index'});

