#!/usr/bin/perl
# flush.cgi
# Flush the active nftables ruleset

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'flush_err'});

if ($in{'confirm'}) {
    my $err = flush_ruleset();
    error(text('flush_failed', $err)) if ($err);
    webmin_log("flush", "ruleset");
    redirect("index.cgi");
}

ui_print_header(undef, $text{'flush_title'}, "", "intro", 1, 1);
print ui_form_start("flush.cgi");
print "<center><b>$text{'flush_confirm'}</b><p>\n";
print ui_submit($text{'flush_ok'}, "confirm");
print "</center>\n";
print ui_form_end();
ui_print_footer("index.cgi", $text{'index_return'});
