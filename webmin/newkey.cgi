#!/usr/local/bin/perl
# newkey.cgi
# Create a new SSL key

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'newkey_err'});

# Validate inputs and create the key
$in{'newfile'} || return $text{'newkey_efile'};
$err = &parse_ssl_key_form(\%in, $in{'newfile'});
&error($err) if ($err);

# Tell the user
&ui_print_header(undef, $text{'newkey_title'}, "");
print "<p>$text{'newkey_ok'}<br>\n";
$key = &read_file_contents($in{'newfile'});
print "<pre>".&html_escape($key)."</pre>";
&ui_print_footer("", $text{'index_return'});

# Configure webmin to use the new file
if ($in{'usenew'}) {
	&lock_file($ENV{'MINISERV_CONFIG'});
	&get_miniserv_config(\%miniserv);
	$miniserv{'keyfile'} = $in{'newfile'};
	delete($miniserv{'certfile'});
	&put_miniserv_config(\%miniserv);
	&unlock_file($ENV{'MINISERV_CONFIG'});
	&restart_miniserv(1);
	&webmin_log("newkey", undef, undef, \%in);
	}

