#!/usr/local/bin/perl
# Force log rotate

require './logrotate-lib.pl';

&ui_print_header(undef, $text{'force_title'}, "");

# Save this CGI from being killed by the rotation of Webmin's own logs
$SIG{'TERM'} = 'IGNORE';

print $text{'force_doing'},"\n";
&clean_environment();
$out = &backquote_logged("$config{'logrotate'} -f $config{'logrotate_conf'} 2>&1");
&reset_environment();
print "<pre>$out</pre>";
if ($?) {
	print $text{'force_failed'},"<br>\n";
	}
else {
	print $text{'force_done'},"<br>\n";
	}

&webmin_log("force");
&ui_print_footer("", $text{'index_return'});

