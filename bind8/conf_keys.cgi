#!/usr/local/bin/perl
# conf_keys.cgi
# Display options for other DNS servers
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';

require './bind8-lib.pl';
# Globals
our (%access, %text);

$access{'defaults'} || &error($text{'keys_ecannot'});
&ui_print_header(undef, $text{'keys_title'}, "",
		 undef, undef, undef, undef, &restart_links());

my $conf = &get_config();
my @keys = ( &find("key", $conf), { } );

# Build table of keys
my @table = ( );
for(my $i=0; $i<@keys; $i++) {
	my $k = $keys[$i];
	my @algs = ( "hmac-md5" );
	my $alg = &find_value("algorithm", $k->{'members'});
	my $secret = &find_value("secret", $k->{'members'});
	push(@table, [ &ui_textbox("id_$i", $k->{'value'}, 15),
		       &ui_select("alg_$i", $alg, \@algs, 1, 0, $alg ? 1 : 0),
		       &ui_textbox("secret_$i", $secret, 65) ]);
	}

# Show the table
print &ui_form_columns_table(
	"save_keys.cgi",
	[ [ undef, $text{'save'} ] ],
	0,
	undef,
	undef,
	[ $text{'keys_id'}, $text{'keys_alg'}, $text{'keys_secret'} ],
	undef,
	\@table,
	undef,
	1);

&ui_print_footer("", $text{'index_return'});

