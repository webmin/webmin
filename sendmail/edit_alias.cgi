#!/usr/local/bin/perl
# edit_alias.cgi
# Edit an existing sendmail alias

require './sendmail-lib.pl';
require './aliases-lib.pl';
&ReadParse();
$conf = &get_sendmailcf();
@aliases = &list_aliases(&aliases_file($conf));
$a = $aliases[$in{'num'}];
&can_edit_alias($a) || &error($text{'aform_ecannot'});

&ui_print_header(undef, $text{'aform_edit'}, "", "edit_alias");
&alias_form($a);
&ui_print_footer("list_aliases.cgi", $text{'aliases_return'},
	"", $text{'index_return'});

