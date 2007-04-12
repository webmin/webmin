#!/usr/local/bin/perl
# edit_virtuser.cgi
# Edit an existing virtuser

require './sendmail-lib.pl';
require './virtusers-lib.pl';
&ReadParse();
$conf = &get_sendmailcf();
@virts = &list_virtusers(&virtusers_file($conf));
&can_edit_virtuser($virts[$in{'num'}]) ||
	&error($text{'vform_ecannot'});

&ui_print_header(undef, $text{'vform_edit'}, "");
&virtuser_form($virts[$in{'num'}]);
&ui_print_footer("list_virtusers.cgi", $text{'virtusers_return'},
	"", $text{'index_return'});

