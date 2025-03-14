#!/usr/local/bin/perl
# Check the whole BIND config and report problems
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals
our (%access, %text, %config);

require './bind8-lib.pl';
&ReadParse();
$access{'defaults'} || &error($text{'ncheck_ecannot'});

&ui_print_header(undef, $text{'ncheck_title'}, "",
		 undef, undef, undef, undef, &restart_links());

my $file = &make_chroot($config{'named_conf'});
my @errs = &check_bind_config();
if (@errs) {
	# Show list of errors
	print "<b>",&text('ncheck_errs', "<tt>$file</tt>"),"</b><p>\n";
	print "<ul>\n";
	foreach my $e (@errs) {
		print "<li>".&html_escape($e)."</li>\n";
		}
	print "</ul>\n";
	}
else {
	# All OK!
	print "<b>",&text('ncheck_allok', "<tt>$file</tt>"),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

