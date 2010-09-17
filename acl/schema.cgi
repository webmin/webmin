#!/usr/local/bin/perl
# Just display the Webmin LDAP schema

require './acl-lib.pl';
$access{'pass'} || &error($text{'sql_ecannot'});

&ui_print_unbuffered_header(undef, $text{'schema_title'}, "");

print $text{'schema_desc'},"<p>\n";
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef,
	"<pre>".&html_escape(&read_file_contents("webmin.schema"))."</pre>", 2);
print &ui_table_end();
print &text('schema_download', 'webmin.schema'),"<p>\n";

&ui_print_footer("", $text{'index_return'});

