#!/usr/local/bin/perl
# edit_virt.cgi
# Edit an existing qmail virt

require './qmail-lib.pl';
&ReadParse();
@virts = &list_virts();
$v = $virts[$in{'idx'}];

&ui_print_header(undef, $text{'vform_edit'}, "");
&virt_form($v);
&ui_print_footer("list_virts.cgi", $text{'virts_return'});

