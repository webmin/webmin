#!/usr/local/bin/perl
# Force log rotate

require './logrotate-lib.pl';

&ui_print_header(undef, $text{'force_title'}, "");

# Save this CGI from being killed by the rotation of Webmin's own logs
$SIG{'TERM'} = 'IGNORE';

print $text{'force_doing'},"\n";
&clean_environment();
my (undef, undef, $files) = &get_config($config{'logrotate_conf'});
my @configs = ($config{'logrotate_conf'}, &get_add_file_configs($files));
my $configs = join(" ", map { &quote_path($_) } @configs);
$out = &backquote_logged("$config{'logrotate'} -f $configs 2>&1");
&reset_environment();
if ($out) {
	print "<pre>$out</pre>";
	}
else {
	print "<br>";
	}
if ($? && $out) {
	print $text{'force_failed'},"<br>\n";
	}
else {
	print $text{'force_done'},"<br>\n";
	}

&webmin_log("force");
&ui_print_footer("", $text{'index_return'});

