#!/usr/local/bin/perl
# Run the included monshow program

require './mon-lib.pl';
&ui_print_header(undef, $text{'show_title'}, "");

if (!-x $config{'monshow'}) {
	print "<p>",&text('show_ecgi', "<tt>$config{'monshow'}</tt>",
			  "../config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

&open_execute_command(CGI, "$config{'monshow'} 2>&1", 1, 1);
while(<CGI>) {
	$body .= $_;
	}
close(CGI);

$body =~ s/^[\000-\177]*<body[^>]*>//i;
$body =~ s/<\/body>[\000-\177]*$//i;
print $body;

&ui_print_footer("", $text{'index_return'});

