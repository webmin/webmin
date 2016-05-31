#!/usr/local/bin/perl
# conf_servers.cgi
# Display options for other DNS servers
use strict;
use warnings;
# Globals
our (%access, %text);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'servers_ecannot'});
&ui_print_header(undef, $text{'servers_title'}, "",
		 undef, undef, undef, undef, &restart_links());

my $conf = &get_config();
my @servers = ( &find("server", $conf), { } );
my @keys = &find("key", $conf);

print &ui_form_start("save_servers.cgi", "post");
print &ui_columns_start([ $text{'servers_ip'},
			  $text{'servers_bogus'},
			  $text{'servers_format'},
			  $text{'servers_trans'},
			  @keys ? ( $text{'servers_keys'} ) : ( ) ], 100);
for(my $i=0; $i<@servers; $i++) {
	my $s = $servers[$i];
	my @cols = ( );
	push(@cols, &ui_textbox("ip_$i", $s->{'value'}, 30));

	my $bogus = &find_value("bogus", $s->{'members'});
	push(@cols, &ui_radio("bogus_$i", lc($bogus) eq 'yes' ? 1 : 0,
			      [ [ 1, $text{'yes'} ],
				[ 0, $text{'no'} ] ]));

	my $format = &find_value("transfer-format", $s->{'members'});
	push(@cols, &ui_radio("format_$i", lc($format),
			      [ [ 'one-answer', $text{'servers_one'} ],
				[ 'many-answers', $text{'servers_many'} ],
				[ '', $text{'default'} ] ]));

	my $trans = &find_value("transfers", $s->{'members'});
	push(@cols, &ui_textbox("trans_$i", $trans, 8));

	if (@keys) {
		my %haskey;
		my $keys = &find("keys", $s->{'members'});
		foreach my $k (@{$keys->{'members'}}) {
			$haskey{$k->{'name'}}++;
			}
		my $cbs = "";
		foreach my $k (@keys) {
			my $v = $k->{'value'};
			$cbs .= &ui_checkbox("keys_$i", $v, $v, $haskey{$v}).
				"\n";
			}
		push(@cols, $cbs);
		}
	print &ui_columns_row(\@cols);
	}
print &ui_columns_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

