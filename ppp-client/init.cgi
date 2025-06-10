#!/usr/local/bin/perl
# init.cgi
# Run wvdialconf to find connected modems

require './ppp-client-lib.pl';
&foreign_require("proc", "proc-lib.pl");
&ui_print_unbuffered_header(undef, $text{'init_title'}, "");

$cmd = "$config{'wvdialconf'} $config{'file'}";
print "<p><b>",&text('init_cmd', "<tt>$cmd</tt>"),"</b><br>\n";
print "<pre>";
&proc::safe_process_exec_logged($cmd, 0, 0, STDOUT, undef, 1);
print "</pre>\n";
print "<b>$text{'init_done'}</b><p>\n";

# Re-check the config
$conf = &get_config();
@modems = map { &device_name($_) } grep { $_ }
	      map { $_->{'values'}->{'modem'} } @$conf;
print "<b>";
if (@modems > 1) {
	local $lst = shift(@modems);
	print &text('init_modems', join(", ", @modems), $lst);
	}
elsif (@modems == 1) {
	print &text('init_modem', $modems[0]);
	}
else {
	print $text{'init_none'};
	}
print "</b><p>\n";

&webmin_log("init");
&ui_print_footer("", $text{'index_return'});

