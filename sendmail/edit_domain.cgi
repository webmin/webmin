#!/usr/local/bin/perl
# edit_domain.cgi
# Edit an existing domain

require './sendmail-lib.pl';
require './domain-lib.pl';
&ReadParse();
$access{'domains'} || &error($text{'dform_ecannot'});
$conf = &get_sendmailcf();
@doms = &list_domains(&domains_file($conf));

&ui_print_header(undef, $text{'dform_edit'}, "");
&domain_form($doms[$in{'num'}]);
&ui_print_footer("list_domains.cgi", $text{'domains_return'},
	"", $text{'index_return'});

