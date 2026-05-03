#!/usr/bin/perl
# delete_table.cgi
# Delete an existing nftables table

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'delete_err'});
assert_acl('delete');

my @tables = get_nftables_save();
my $table_idx = $in{'table'};
my $table;
if (defined($in{'table_family'}) && defined($in{'table_name'})) {
    for (my $i = 0; $i <= $#tables; $i++) {
        if ($tables[$i]->{'family'} eq $in{'table_family'} &&
            $tables[$i]->{'name'} eq $in{'table_name'}) {
            $table_idx = $i;
            $table = $tables[$i];
            last;
        }
    }
    $table || error($text{'delete_notable'});
}
else {
    $table = $tables[$table_idx];
}
$table || error($text{'delete_notable'});
assert_table_acl($table);

if ($in{'confirm'}) {
    my $needs_apply = needs_config_restart();
    splice(@tables, $table_idx, 1);
    my $err = delete_table_configuration($table, @tables);
    error(text('delete_failed', $err)) if ($err);
    $err = delete_active_table($table);
    error(text('delete_failed', $err)) if ($err);
    restart_last_restart_time() if (!$needs_apply);
    webmin_log("delete", "table", $table->{'name'},
                { 'family' => $table->{'family'} });
    redirect("index.cgi");
    return;
}

ui_print_header(undef, $text{'delete_title'}, "");
print "<center>\n";
print ui_form_start("delete_table.cgi");
print ui_hidden("table", $table_idx);
print ui_hidden("table_family", $table->{'family'});
print ui_hidden("table_name", $table->{'name'});
print text('delete_confirm',
           "<tt>$table->{'family'} $table->{'name'}</tt>"),"<p>\n";
print ui_form_end([ [ "confirm", $text{'delete'} ] ]);
print "</center>\n";
ui_print_footer("index.cgi?table_family=".urlize($table->{'family'}).
                "&table_name=".urlize($table->{'name'}), $text{'index_return'});
