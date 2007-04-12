#!/usr/local/bin/perl
# edit_generic.cgi
# Edit an existing generic

require './sendmail-lib.pl';
require './generics-lib.pl';
&ReadParse();
$conf = &get_sendmailcf();
@gens = &list_generics(&generics_file($conf));
&can_edit_generic($gens[$in{'num'}]) ||
	&error($text{'gform_ecannot'});

&ui_print_header(undef, $text{'gform_edit'}, "");
&generic_form($gens[$in{'num'}]);
&ui_print_footer("list_generics.cgi", $text{'generics_return'},
	"", $text{'index_return'});
