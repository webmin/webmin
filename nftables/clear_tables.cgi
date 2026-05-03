#!/usr/bin/perl
# clear_tables.cgi
# Remove all clearable tables from the active nftables ruleset

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'clear_all_err'});
assert_acl('clear');

my ($tables, $err) = get_active_nftables_save();
error(text('active_failed', $err)) if ($err);

my @clearable =
    grep { !table_is_externally_managed($_) && check_table_acl($_) } @$tables;
@clearable || error($text{'clear_all_enone'});

if ($in{'confirm'}) {
	foreach my $table (@clearable) {
		$err = delete_active_table($table);
		error(text('clear_failed', $err)) if ($err);
		webmin_log("clear", "table", $table->{'name'},
			{'family' => $table->{'family'}});
		}
	redirect("active.cgi");
	return;
	}

ui_print_header(undef, $text{'clear_all_title'}, "");
print "<center>\n";
print ui_form_start("clear_tables.cgi");
print text('clear_all_confirm', scalar(@clearable)), "<p>\n";
print ui_form_end([["confirm", $text{'active_clear_all'}]]);
print "</center>\n";
ui_print_footer("active.cgi", $text{'active_return'});
