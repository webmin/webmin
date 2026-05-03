#!/usr/bin/perl
# clear_table.cgi
# Remove one table from the active nftables ruleset

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'clear_err'});
assert_acl('clear');

my ($tables, $err) = get_active_nftables_save();
error(text('active_failed', $err)) if ($err);

my $table;
foreach my $t (@$tables) {
	if ($t->{'family'} eq $in{'family'} && $t->{'name'} eq $in{'name'}) {
		$table = $t;
		last;
		}
	}
$table || error($text{'active_table_notable'});
assert_table_acl($table);

if ($in{'confirm'}) {
	$err = delete_active_table($table);
	error(text('clear_failed', $err)) if ($err);
	webmin_log("clear", "table", $table->{'name'},
		   { 'family' => $table->{'family'} });
	redirect("active.cgi");
	return;
	}

ui_print_header(undef, $text{'clear_title'}, "");
print "<center>\n";
print ui_form_start("clear_table.cgi");
print ui_hidden("family", $table->{'family'});
print ui_hidden("name", $table->{'name'});
print text('clear_confirm',
	   "<tt>".html_escape(nft_table_spec($table))."</tt>"),"<p>\n";
print ui_form_end([ [ "confirm", $text{'active_clear'} ] ]);
print "</center>\n";
ui_print_footer("active.cgi", $text{'active_return'});
