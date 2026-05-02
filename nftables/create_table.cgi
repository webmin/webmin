#!/usr/bin/perl
# create_table.cgi
# Create a new nftables table

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'create_err'});

my @families = qw(ip ip6 inet arp bridge netdev);
my %family_ok = map { $_ => 1 } @families;

if ($in{'create'}) {
    my $name = $in{'name'};
    my $family = $in{'family'};

    $name =~ /^\w[\w-]*$/ || error($text{'create_ename'});
    $family_ok{$family} || error($text{'create_efamily'});

    my @tables = get_nftables_save();
    foreach my $t (@tables) {
        if ($t->{'name'} eq $name && $t->{'family'} eq $family) {
            error($text{'create_edup'});
        }
    }
    my ($active, $active_err) = get_active_nftables_save();
    if (!$active_err) {
        foreach my $t (@$active) {
            if ($t->{'name'} eq $name && $t->{'family'} eq $family &&
                table_is_externally_managed($t)) {
                error(text('create_eexternal', nft_table_spec($t)));
            }
        }
    }

    my $table = { 'name' => $name,
                  'family' => $family,
                  'rules' => [],
                  'chains' => {},
                  'sets' => {} };
    push(@tables, $table);
    my $err = create_table_configuration($table, @tables);
    error(text('create_failed', $err)) if ($err);
    webmin_log("create", "table", $name, { 'family' => $family });

    redirect("index.cgi?table_family=".urlize($family).
             "&table_name=".urlize($name));
}

ui_print_header(undef, $text{'create_title'}, "", "intro", 1, 1);
print ui_form_start("create_table.cgi");
print ui_hidden("create", 1);

print ui_table_start($text{'create_header'}, "width=100%", 2);
print ui_table_row($text{'create_family'},
    ui_select("family", $in{'family'} || "inet",
        [ map { [ $_, $_ ] } @families ]));
print ui_table_row($text{'create_name'},
    ui_textbox("name", $in{'name'}, 20));
print ui_table_end();

print ui_form_end([ [ undef, $text{'create_ok'} ] ]);
ui_print_footer("index.cgi", $text{'index_return'});
