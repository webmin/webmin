#!/usr/local/bin/perl
# mon.cgi
# Run the included MON cgi program

require './mon-lib.pl';
&ui_print_header(undef, $text{'status_title'}, "");

if (!-x $config{'mon_cgi'}) {
	print "<p>",&text('status_ecgi', "<tt>$config{'mon_cgi'}</tt>",
			  "../config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
if (&same_file($config{'mon_cgi'}, $0)) {
	print "<p>",&text('status_esame', "<tt>$config{'mon_cgi'}</tt>",
			  "../config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
eval "use Mon::Client";
if ($@) {
	print "<p>",&text('status_eperl', "<tt>Mon::Client</tt>",
		  "../cpan/download.cgi?source=3&cpan=Mon::Client"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

&open_execute_command(CGI, "$config{'mon_cgi'} 2>&1", 1, 1);
while(<CGI>) {
	$body .= $_;
	}
close(CGI);

$body =~ s/^[\000-\177]*<body[^>]*>//i;
$body =~ s/<\/body>[\000-\177]*$//i;
print $body;

&ui_print_footer("", $text{'index_return'});

