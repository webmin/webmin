#!/usr/local/bin/perl
# Force log rotate

require './logrotate-lib.pl';

&ui_print_header(undef, $text{'force_title'}, "");

# Save this CGI from being killed by the rotation of Webmin's own logs
$SIG{'TERM'} = 'IGNORE';

print $text{'force_doing'},"\n";
&clean_environment();

# Force the same effective main and drop-in configs selected by the distro
# wrapper, while avoiding duplicate files already reached through includes.
my $main = &get_main_config_file();
my (undef, undef, $files) = &get_config($main);
my @configs = ($main, &get_add_file_configs($files));
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

