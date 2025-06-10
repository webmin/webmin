#!/usr/local/bin/perl
# edit_alias.cgi
# Edit an existing qmail alias

require './qmail-lib.pl';
&ReadParse();
$a = &get_alias($in{'name'});

&ui_print_header(undef, $text{'aform_edit'}, "");
&alias_form($a);
&ui_print_footer("list_aliases.cgi", $text{'aliases_return'});

