#!/usr/bin/perl
# delete_chain.cgi
# Delete an existing nftables chain

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'delete_chain_err'});

my @tables = get_nftables_save();
my $table = $tables[$in{'table'}];
$table || error($text{'chain_notable'});

my $chain = $table->{'chains'}->{$in{'chain'}};
$chain || error($text{'chain_nochain'});

my @refs = grep {
    ($_->{'jump'} && $_->{'jump'} eq $in{'chain'}) ||
    ($_->{'goto'} && $_->{'goto'} eq $in{'chain'})
} @{$table->{'rules'}};

if ($in{'confirm'}) {
    @refs && error(text('delete_chain_inuse', $in{'chain'}, scalar(@refs)));

    @{$table->{'rules'}} = grep { $_->{'chain'} ne $in{'chain'} } @{$table->{'rules'}};
    delete($table->{'chains'}->{$in{'chain'}});

    my $err = save_table_configuration($table, @tables);
    error(text('delete_chain_failed', $err)) if ($err);
    webmin_log("delete", "chain", $in{'chain'},
                { 'table' => $table->{'name'}, 'family' => $table->{'family'} });
    redirect("index.cgi?table=$in{'table'}");
}

ui_print_header(undef, $text{'delete_chain_title'}, "", "intro", 1, 1);
print ui_form_start("delete_chain.cgi");
print ui_hidden("table", $in{'table'});
print ui_hidden("chain", $in{'chain'});
print "<center><b>",
      text('delete_chain_confirm',
            "<tt>$in{'chain'}</tt>",
            "<tt>$table->{'family'} $table->{'name'}</tt>"),
      "</b>";
if (@refs) {
    print "<br><br>", text('delete_chain_inuse', $in{'chain'}, scalar(@refs));
}
print "<p>\n";
print ui_submit($text{'delete'}, "confirm");
print "</center>\n";
print ui_form_end();
ui_print_footer("index.cgi?table=$in{'table'}", $text{'index_return'});

