#!/usr/local/bin/perl
# edit_assign.cgi
# Edit an existing mail user assigment

require './qmail-lib.pl';
&ReadParse();
@assigns = &list_assigns();
$a = $assigns[$in{'idx'}];

&ui_print_header(undef, $text{'sform_edit'}, "");
&assign_form($a);
&ui_print_footer("list_assigns.cgi", $text{'assigns_return'});

