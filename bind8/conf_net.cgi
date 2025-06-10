#!/usr/local/bin/perl
# Display global networking options
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals
our (%access, %text); 

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'net_ecannot'});
&ui_print_header(undef, $text{'net_title'}, "",
		 undef, undef, undef, undef, &restart_links());

&ReadParse();
my $conf = &get_config();
my $options = &find("options", $conf);
my $mems = $options->{'members'};

# Start of form
print &ui_form_start("save_net.cgi", "post");
print &ui_table_start($text{'net_header'}, "width=100%", 4);

# Ports and addresses to listen on
my @listen = ( &find("listen-on", $mems),
	       &find("listen-on-v6", $mems) );
my $ltable = &ui_radio("listen_def", @listen ? 0 : 1,
		    [ [ 1, $text{'default'} ],
		      [ 0, $text{'net_below'} ] ])."<br>\n";

my @table = ( );
push(@listen, { });
my @tls = map { $_->{'values'}->[0] } &find("tls", $conf);
for(my $i=0; $i<@listen; $i++) {
	my $l = $listen[$i];
	my $v = $l->{'values'} || [];
	my ($port, $tls);
	for(my $j=0; $j<@$v; $j++) {
		if ($v->[$j] eq "port") {
			$port = $v->[++$j];
			}
		if ($v->[$j] eq "tls") {
			$tls = $v->[++$j];
			}
		}
	my @vals = map { $_->{'name'} } @{$l->{'members'}};
	push(@table, [
		&ui_select("proto_$i",
			   $l->{'name'} eq 'listen-on-v6' ? 'v6' :
			   $l->{'name'} eq 'listen-on' ? 'v4' : '',
			   [ [ '', $text{'net_none'} ],
			     [ 'v4', 'IPv4' ],
			     [ 'v6', 'IPv6' ] ]),
		&ui_radio("pdef_$i", $port ? 0 : 1,
		  [ [ 1, $text{'default'} ],
		    [ 0, &ui_textbox("port_$i", $port, 5) ] ]),
		@tls ? ( &ui_select("tls_$i", $tls, [ '', @tls ]) ) : ( ),
		&ui_textbox("addrs_$i", join(" ", @vals), 50),
		]);
	}
$ltable .= &ui_columns_table(
	[ $text{'net_proto'},
	  $text{'net_port'},
	  @tls ? ( $text{'net_tls'} ) : ( ),
	  $text{'net_addrs'} ],
	undef,
	\@table,
	undef,
	1);

print &ui_table_row($text{'net_listen'}, $ltable, 3);
#print &ui_table_hr();

# Source address for queries
my $src = &find("query-source", $mems);
my $srcstr = $src ? join(" ", @{$src->{'values'}}) : "";
my ($sport, $saddr);
$sport = $1 if ($srcstr =~ /port\s+(\d+)/i);
$saddr = $1 if ($srcstr =~ /address\s+([0-9\.]+)/i);
print &ui_table_row($text{'net_saddr'},
	&ui_opt_textbox("saddr", $saddr, 15, $text{'default'},
			$text{'net_ip'}));

# Source port for queries
print &ui_table_row($text{'net_sport'},
	&ui_opt_textbox("sport", $sport, 5, $text{'default'},
			$text{'net_port'}));

# Source port for transfers (IPv4)
$src = &find("transfer-source", $mems);
$srcstr = $src ? join(" ", @{$src->{'values'}}) : "";
my ($tport, $taddr);
$tport = $1 if ($srcstr =~ /port\s+(\d+)/i);
$taddr = $1 if ($srcstr =~ /^([0-9\.]+|\*)/i);
print &ui_table_row($text{'net_taddr'},
	&ui_radio("taddr_def", $taddr eq "" ? 1 : $taddr eq "*" ? 2 : 0,
		  [ [ 1, $text{'default'} ],
		    [ 2, $text{'net_taddrdef'} ],
		    [ 0, $text{'net_ip'}." ".
		      &ui_textbox("taddr", $taddr eq "*" ? "" : $taddr, 15) ],
		  ]));

# Source port for transfers (IPv4)
print &ui_table_row($text{'net_tport'},
	&ui_opt_textbox("tport", $tport, 5, $text{'default'},
			$text{'net_port'}));

# Source port for transfers (IPv6)
my $src6 = &find("transfer-source-v6", $mems);
my $srcstr6 = $src6 ? join(" ", @{$src6->{'values'}}) : "";
my ($tport6, $taddr6);
$tport6 = $1 if ($srcstr6 =~ /port\s+(\d+)/i);
$taddr6 = $1 if ($srcstr6 =~ /^([0-9a-f:]+|\*)/i);
print &ui_table_row($text{'net_taddr6'},
	&ui_radio("taddr6_def", $taddr6 eq "" ? 1 : $taddr6 eq "*" ? 2 : 0,
		  [ [ 1, $text{'default'} ],
		    [ 2, $text{'net_taddrdef'} ],
		    [ 0, $text{'net_ip'}." ".
		      &ui_textbox("taddr6", $taddr6 eq "*" ? "" : $taddr6, 30) ],
		  ]));

# Source port for transfers (IPv6)
print &ui_table_row($text{'net_tport6'},
	&ui_opt_textbox("tport6", $tport6, 5, $text{'default'},
			$text{'net_port'}));



print &addr_match_input($text{'net_topol'}, 'topology', $mems, 1);
print &addr_match_input($text{'net_recur'}, 'allow-recursion', $mems, 1);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


