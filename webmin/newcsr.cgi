#!/usr/local/bin/perl
# Create a new SSL signing request

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'newcsr_err'});

# Validate inputs and create the CSR
$in{'newfile'} || return $text{'newkey_efile'};
$in{'csrfile'} || return $text{'newcsr_efile'};
$err = &parse_ssl_csr_form(\%in, $in{'newfile'}, $in{'csrfile'});
&error($err) if ($err);

# Tell the user
&ui_print_header(undef, $text{'newcsr_title'}, "");

print "<p>$text{'newkey_ok'}<br>\n";
$key = &read_file_contents($in{'newfile'});
print "<pre>".&html_escape($key)."</pre>";

print "<p>$text{'newcsr_ok'}<br>\n";
$csr = &read_file_contents($in{'csrfile'});
print "<pre>".&html_escape($csr)."</pre>";
print "<p>$text{'newcsr_ok2'}<br>\n";

&ui_print_footer("", $text{'index_return'});

&webmin_log("newcsr", undef, undef, \%in);

