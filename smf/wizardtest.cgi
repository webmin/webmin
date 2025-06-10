#!/usr/local/bin/perl

require './smf-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("smf", "man", "doc", "howto"));

# wizard-specific info here!
$wizard = "page= wizardtest.cgi  , min =1,max=1;finish=done.cgi;";
&wizard_header($wizard, "wizardtest.cgi", "heading", "description here",
	"images/smf.gif");
&wizard_input("wizardtest.cgi", "Enter name here", "name", 60, ".+",
	"Must be non-null!");
@bool = ("true", "false");
&wizard_select("wizardtest.cgi", "Enabled?", "enabled", \@bool,
	".+", "Must be non-null!");
&wizard_textarea("wizardtest.cgi", "Enter info here", "area", 10, 40, ".*",
	"");
&wizard_footer($wizard, "wizardtest.cgi");

# end wizard-specific info
&ui_print_footer("/", $text{'index'});

