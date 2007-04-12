#!/usr/local/bin/perl
# edit_mailer.cgi
# Edit an existing mailer

require './sendmail-lib.pl';
require './mailers-lib.pl';
&ReadParse();
$access{'mailers'} || &error($text{'mform_ecannot'});
$conf = &get_sendmailcf();
@virts = &list_mailers(&mailers_file($conf));

&ui_print_header(undef, $text{'mform_edit'}, "");
&mailer_form($virts[$in{'num'}]);
&ui_print_footer("list_mailers.cgi", $text{'mailers_return'},
	"", $text{'index_return'});
