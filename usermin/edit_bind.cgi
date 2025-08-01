#!/usr/local/bin/perl
# edit_bind.cgi
# Display port / address form

require './usermin-lib.pl';
$access{'bind'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'bind_title'}, "");
&get_usermin_miniserv_config(\%miniserv);

print $text{'bind_desc2'},"<p>\n";

print &ui_form_start("change_bind.cgi", "post");
print &ui_table_start($text{'bind_header'}, undef, 2, [ "width=30%" ]);

# Build list of sockets
my @sockets = &webmin::get_miniserv_sockets(\%miniserv);

# Show table of all bound IPs and ports
my $stable = &ui_columns_start([ $text{'bind_sip'}, $text{'bind_sport'} ]);
my $i = 0;
my @ports;
foreach $s (@sockets, [ undef, "*" ]) {
	# IP address
	my @cols;
	push(@cols, &ui_select("ip_def_$i",
	                       $s->[0] eq "" ? 0 :
	                       $s->[0] eq "*" ? 1 : 2,
	                       [ [ 0, "&nbsp;" ],
	                       [ 1, $text{'bind_sip1'} ],
	                       [ 2, $text{'bind_sip2'} ] ])." ".
	                       &ui_textbox("ip_$i",
				  $s->[0] eq "*" ? undef : $s->[0], 20));

	# Port
	push(@cols, &ui_select("port_def_$i", $s->[1] eq "*" ? 0 : 1,
	          [ $i ? ( [ 0, $text{'bind_sport0'} ] ) : ( ),
	     [ 1, $text{'bind_sport1'} ] ])." ".
	      &ui_textbox("port_$i", $s->[1] eq "*" ? undef : $s->[1],5));
	$stable .= &ui_columns_row(\@cols, [ "nowrap", "nowrap" ]);
	push(@ports, $s->[1]) if ($s->[1] && $s->[1] ne "*");
	$i++;
	}
$stable .= &ui_columns_end();
if (&foreign_check("firewall") || &foreign_check("firewalld")) {
        $stable .= &ui_checkbox("firewall", 1, $text{'bind_firewall'}, 1);
        }
print &ui_table_row($text{'bind_sockets'}, $stable);

# WebSocket based port
print &ui_table_row($text{'bind_websocport'},
    &ui_radio("websocket_base_port_def",
    	$miniserv{"websocket_base_port"} ? 0 : 1,
	[ [ 1, $text{'bind_websocport_none'} ],
	  [ 0, &ui_textbox("websocket_base_port",
	  	$miniserv{"websocket_base_port"}, 6) ] ]));

# Hostname for WebSocket connections
print &ui_table_row($text{'bind_websoc_host'},
    &ui_radio("websocket_host_def",
    	$miniserv{"websocket_host"} ? 0 : 1,
	[ [ 1, $text{'bind_websoc_host_auto'} ],
	  [ 0, &ui_textbox("websocket_host",
	  	$miniserv{"websocket_host"}, 25) ] ]));

# IPv6 enabled?
print &ui_table_row($text{'bind_ipv6'},
	&ui_yesno_radio("ipv6", $miniserv{'ipv6'}));

# Show web server hostname
print &ui_table_row($text{'bind_hostname'},
      &ui_radio("hostname_def", $miniserv{"host"} ? 0 : 1,
      [ [ 1, $text{'bind_auto'} ],
      [ 0, &ui_textbox("hostname", $miniserv{"host"}, 25) ] ]));

print &ui_table_end();
print &ui_hidden("oldports", join(" ", @ports));
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

