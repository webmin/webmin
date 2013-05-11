#!/usr/local/bin/perl
# conf_servers.cgi
# Display options for other DNS servers

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'servers_ecannot'});
&ui_print_header(undef, $text{'servers_title'}, "",
		 undef, undef, undef, undef, &restart_links());

$conf = &get_config();
@servers = ( &find("server", $conf), { } );
@keys = &find("key", $conf);

print &ui_form_start("save_servers.cgi", "post");
print &ui_columns_start([ $text{'servers_ip'},
			  $text{'servers_bogus'},
			  $text{'servers_format'},
			  $text{'servers_trans'},
			  @keys ? ( $text{'servers_keys'} ) : ( ) ], 100);
for($i=0; $i<@servers; $i++) {
	$s = $servers[$i];
	@cols = ( );
	push(@cols, &ui_textbox("ip_$i", $s->{'value'}, 30));

	$bogus = &find_value("bogus", $s->{'members'});
	push(@cols, &ui_radio("bogus_$i", lc($bogus) eq 'yes' ? 1 : 0,
			      [ [ 1, $text{'yes'} ],
				[ 0, $text{'no'} ] ]));

	$format = &find_value("transfer-format", $s->{'members'});
	push(@cols, &ui_radio("format_$i", lc($format),
			      [ [ 'one-answer', $text{'servers_one'} ],
				[ 'many-answers', $text{'servers_many'} ],
				[ '', $text{'default'} ] ]));

	$trans = &find_value("transfers", $s->{'members'});
	push(@cols, &ui_textbox("trans_$i", $trans, 8));

	if (@keys) {
		local %haskey;
		$keys = &find("keys", $s->{'members'});
		foreach $k (@{$keys->{'members'}}) {
			$haskey{$k->{'name'}}++;
			}
		$cbs = "";
		foreach $k (@keys) {
			local $v = $k->{'value'};
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

