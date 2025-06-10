#!/usr/local/bin/perl
# Show the log file, with searching

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './minecraft-lib.pl';
our (%in, %text, %config);
my $logfile = &get_minecraft_log_file();
&ReadParse();

$in{'lines'} = undef if ($in{'lines'} !~ /^\d+$/);
$in{'lines'} ||= 20;

&ui_print_header(undef, $text{'logs_title'}, "");

# Search form
print &ui_form_start("view_logs.cgi");
print "<b>$text{'logs_lines'}</b> ",
      &ui_textbox("lines", $in{'lines'}, 5)." ".
      "<b>$text{'logs_matching'}</b> ",
      &ui_textbox("search", $in{'search'}, 20)." ".
      &ui_submit($text{'logs_ok'})."<br>\n";
print &ui_form_end()."<p>\n";

# Results
my $cmd;
if ($in{'search'}) {
	$cmd = "grep ".quotemeta($in{'search'})." ".quotemeta($logfile)." | ".
	       "tail -".quotemeta($in{'lines'});
	}
else {
	$cmd = "tail -".quotemeta($in{'lines'})." ".quotemeta($logfile);
	}
print "<pre>";
my $fh = "OUT";
&open_execute_command($fh, $cmd, 1, 1);
while(<$fh>) {
	print &html_escape($_);
	}
close($fh);
print "</pre>";

&ui_print_footer("", $text{'index_return'});
