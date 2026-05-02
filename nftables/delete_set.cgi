#!/usr/bin/perl
# delete_set.cgi
# Delete an existing nftables set

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'delete_set_err'});

my @tables = get_nftables_save();
my $table = $tables[$in{'table'}];
$table || error($text{'set_notable'});

my $set = $table->{'sets'}->{$in{'set'}};
$set || error($text{'set_noset'});

my $refs = count_set_references($table, $in{'set'});

if ($in{'confirm'}) {
    $refs && error(text('delete_set_inuse', $in{'set'}, $refs));

    delete($table->{'sets'}->{$in{'set'}});
    my $err = save_table_configuration($table, @tables);
    error(text('delete_set_failed', $err)) if ($err);
    webmin_log("delete", "set", $in{'set'},
               { 'table' => $table->{'name'}, 'family' => $table->{'family'} });
    redirect("index.cgi?table=$in{'table'}&view=sets");
}

ui_print_header(undef, $text{'delete_set_title'}, "", "intro", 1, 1);
print ui_form_start("delete_set.cgi");
print ui_hidden("table", $in{'table'});
print ui_hidden("set", $in{'set'});
print "<center><b>",
      text('delete_set_confirm',
            "<tt>$in{'set'}</tt>",
            "<tt>$table->{'family'} $table->{'name'}</tt>"),
      "</b>";
if ($refs) {
    print "<br><br>", text('delete_set_inuse', $in{'set'}, $refs);
}
print "<p>\n";
print ui_submit($text{'delete'}, "confirm");
print "</center>\n";
print ui_form_end();
ui_print_footer("index.cgi?table=$in{'table'}&view=sets", $text{'index_return'});
