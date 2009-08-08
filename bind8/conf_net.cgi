#!/usr/local/bin/perl
# Display global networking options

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'net_ecannot'});
&ui_print_header(undef, $text{'net_title'}, "",
		 undef, undef, undef, undef, &restart_links());

&ReadParse();
$conf = &get_config();
$options = &find("options", $conf);
$mems = $options->{'members'};

# Start of form
print &ui_form_start("save_net.cgi", "post");
print &ui_table_start($text{'net_header'}, "width=100%", 4);

# Ports and addresses to listen on
@listen = &find("listen-on", $mems);
$ltable = &ui_radio("listen_def", @listen ? 0 : 1,
		    [ [ 1, $text{'default'} ],
		      [ 0, $text{'net_below'} ] ])."<br>\n";

@table = ( );
push(@listen, { });
for($i=0; $i<@listen; $i++) {
	$port = $listen[$i]->{'value'} eq 'port' ?
                        $listen[$i]->{'values'}->[1] : undef;
	@vals = map { $_->{'name'} } @{$listen[$i]->{'members'}};
	push(@table, [
		&ui_radio("pdef_$i", $port ? 0 : 1,
		  [ [ 1, $text{'default'} ],
		    [ 0, &ui_textbox("port_$i", $port, 5) ] ]),
		&ui_textbox("addrs_$i", join(" ", @vals), 50),
		]);
	}
$ltable .= &ui_columns_table(
	[ $text{'net_port'}, $text{'net_addrs'} ],
	undef,
	\@table,
	undef,
	1);

print &ui_table_row($text{'net_listen'}, $ltable, 3);
print &ui_table_hr();

# Source address for queries
$src = &find("query-source", $mems);
$srcstr = join(" ", @{$src->{'values'}});
$sport = $1 if ($srcstr =~ /port\s+(\d+)/i);
$saddr = $1 if ($srcstr =~ /address\s+([0-9\.]+)/i);
print &ui_table_row($text{'net_saddr'},
	&ui_opt_textbox("saddr", $saddr, 15, $text{'default'},
			$text{'net_ip'}));

# Source port
print &ui_table_row($text{'net_sport'},
	&ui_opt_textbox("sport", $sport, 5, $text{'default'},
			$text{'net_port'}));

print &addr_match_input($text{'net_topol'}, 'topology', $mems, 1);
print &addr_match_input($text{'net_recur'}, 'allow-recursion', $mems, 1);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


