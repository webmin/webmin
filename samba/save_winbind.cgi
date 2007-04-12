#!/usr/local/bin/perl
# save_winbind.cgi
# Bind to a domain

require './samba-lib.pl';
%access = &get_module_acl();
$access{'winbind'} || &error($text{'winbind_ecannot'});
&ReadParse();

# Validate inputs and create command
$cmd = "$config{'net'} join";
&error_setup($text{'winbind_err'});
$in{'user'} || &error($text{'winbind_euser'});
$cmd .= " -U ".quotemeta($in{'user'});
if (!$in{'dom_def'}) {
	$in{'dom'} || &error($text{'winbind_edom'});
	$cmd .= " -S ".quotemeta($in{'dom'});
	}

# Run it
&ui_print_header(undef, $text{'winbind_title'}, undef);
print &text('winbind_cmd', "<tt>$cmd</tt>"),"\n";
$temp = &transname();
open(TEMP, ">$temp");
print TEMP $in{'pass'},"\n";
close(TEMP);
$out = `$cmd 2>&1 <$temp`;
unlink($temp);
print "<pre>$out</pre>";
if ($? || $out =~ /error|failed/i) {
	print "$text{'winbind_failed'}<br>\n";
	}
else {
	print "$text{'winbind_ok'}<br>\n";
	}

&ui_print_footer("", $text{'index_sharelist'});

