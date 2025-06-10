#!/usr/local/bin/perl
# edit_access.cgi
# Edit an existing access rule

require './sendmail-lib.pl';
require './access-lib.pl';
&ReadParse();
$access{'access'} || &error($text{'sform_ecannot'});
$conf = &get_sendmailcf();
@accs = &list_access(&access_file($conf));
&can_edit_access($accs[$in{'num'}]) ||
	&error($text{'sform_ecannot'});

&ui_print_header(undef, $text{'sform_edit'}, "");
&access_form($accs[$in{'num'}]);
&ui_print_footer("list_access.cgi", $text{'access_return'},
	"", $text{'index_return'});

