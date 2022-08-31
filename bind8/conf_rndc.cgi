#!/usr/local/bin/perl
# Show a form for setting up RNDC
# XXX should check if already working!
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals
our (%access, %text, %config);
our $module_name;

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'rndc_ecannot'});
&ui_print_header(undef, $text{'rndc_title'}, "",
		 undef, undef, undef, undef, &restart_links());

print $text{'rndc_desc'},"<p>\n";

# Check for rndc-confgen program
if (!&has_command($config{'rndcconf_cmd'})) {
	&ui_print_endpage(&text('rndc_ecmd', "<tt>$config{'rndcconf_cmd'}</tt>",
				"../config.cgi?$module_name"));
	}

# Check if already working
my $out;
&execute_command($config{'rndc_cmd'}.
		 ($config{'rndc_conf'} ? " -c $config{'rndc_conf'}" : "").
		 " status", undef, \$out);
if (!$? && $out !~ /failed/) {
	print "<b>",$text{'rndc_desc2'},"</b><p>\n";
	}

# Show form
print &ui_form_start("save_rndc.cgi", "post");
my $ex = -s $config{'rndc_conf'};
print &text($ex ? 'rndc_rusure' : 'rndc_rusure2',
	    "<tt>$config{'rndc_conf'}</tt>"),"<br>\n";
print &ui_submit($text{'rndc_ok'});
print &ui_form_end();

&ui_print_footer("", $text{'index_return'});

