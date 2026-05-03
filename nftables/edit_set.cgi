#!/usr/bin/perl
# edit_set.cgi
# Display a form for creating or editing a set

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
assert_acl('sets');

my @tables = get_nftables_save();
my $table = $tables[$in{'table'}];
$table || error($text{'set_notable'});
assert_table_acl($table);

my $set = { };
my $set_name = "";
my $is_new = $in{'new'} ? 1 : 0;

if ($is_new) {
    ui_print_header(undef, $text{'set_title_new'}, "");
}
else {
    $set_name = $in{'set'};
    $set = $table->{'sets'}->{$set_name};
    $set || error($text{'set_noset'});
    ui_print_header(undef, $text{'set_title_edit'}, "");
}

my $elements_text = set_elements_text($set);
my @type_opts = (
    [ "", $text{'set_type_select'} ],
    [ "ipv4_addr", "ipv4_addr" ],
    [ "ipv6_addr", "ipv6_addr" ],
    [ "ether_addr", "ether_addr" ],
    [ "inet_proto", "inet_proto" ],
    [ "inet_service", "inet_service" ],
    [ "mark", "mark" ],
);
my %type_seen = map { $_->[0] => 1 } @type_opts;
if ($set->{'type'} && !$type_seen{$set->{'type'}}) {
    push(@type_opts, [ $set->{'type'}, $set->{'type'} ]);
}
my @flag_opts = (
    [ "constant", "constant" ],
    [ "dynamic", "dynamic" ],
    [ "interval", "interval" ],
    [ "timeout", "timeout" ],
);
my @flags_sel;
my $flags_sel;
if ($set->{'flags'}) {
    @flags_sel = split(/\s+|,\s*/, $set->{'flags'});
    @flags_sel = grep { $_ ne '' } @flags_sel;
    my %flag_seen = map { $_->[0] => 1 } @flag_opts;
    foreach my $f (@flags_sel) {
        push(@flag_opts, [ $f, $f ]) if (!$flag_seen{$f}++);
    }
}
$flags_sel = @flags_sel ? \@flags_sel : undef;

print ui_form_start("save_set.cgi");
print ui_hidden("table", $in{'table'});
print ui_hidden("new", $is_new);
print ui_hidden("set", $set_name) if (!$is_new);

print ui_table_start($text{'set_header'}, "width=100%", 2);

my $name_tags = $is_new ? undef : "readonly";
print ui_table_row(hlink($text{'set_name'}, "set_name"),
    ui_textbox("set_name", $set_name, 30, 0, undef, $name_tags));

print ui_table_row(hlink($text{'set_type'}, "set_type"),
    ui_select("set_type", $set->{'type'}, \@type_opts, 1, 0, 1));

print ui_table_row(hlink($text{'set_flags'}, "set_flags"),
    ui_select("set_flags", $flags_sel, \@flag_opts, 5, 1, 1));

my $elem_field = ui_textarea("set_elements", $elements_text, 6, 60);
$elem_field .= "<br>".ui_note($text{'set_elements_desc'}, 0);
print ui_table_hr();
print ui_table_row(hlink($text{'set_elements'}, "set_elements"),
    $elem_field, undef, undef, undef, 1);

print ui_table_end();

print ui_form_end([ [ undef, $text{$is_new ? 'create' : 'save'} ] ]);
ui_print_footer("index.cgi?table=$in{'table'}&view=sets", $text{'index_return'});
