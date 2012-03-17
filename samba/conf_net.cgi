#!/usr/local/bin/perl
# conf_net.cgi
# Display Unix networking options

require './samba-lib.pl';

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcn'}") unless $access{'conf_net'};

&ui_print_header(undef, $text{'net_title'}, "");

&get_share("global");

print &ui_form_start("save_net.cgi", "post");
print &ui_table_start($text{'net_title'}, undef, 2);

print &ui_table_row($text{'net_idle'},
	&ui_opt_textbox("dead_time", &getval("deadtime"), 5,
		$text{'config_never'})." ".$text{'config_mins'});

print &ui_table_row($text{'net_trustlist'},
	&ui_opt_textbox("hosts_equiv", &getval("hosts equiv"), 40,
			$text{'config_none'})." ".
	&file_chooser_button("hosts_equiv", 0));

$ifaces = &getval("interfaces");
$itable = &ui_columns_start([ $text{'net_interface'}, $text{'net_netmask'} ]);
@iflist = split(/\s+/, $ifaces);
$len = @iflist ? @iflist+1 : 2;
for($i=0; $i<$len; $i++) {
	my ($ip, $nm);
	if ($iflist[$i] =~ /^([0-9\.]+)\/([0-9]+)$/) {
		$ip = $1;
		for($j=0; $j<$2; $j++) { $pw += 2**(31-$j); }
		$nm = sprintf "%u.%u.%u.%u",
				($pw>>24)&0xff, ($pw>>16)&0xff,
				($pw>>8)&0xff, ($pw)&0xff;
		}
	elsif ($iflist[$i] =~ /^([0-9\.]+)\/([0-9\.]+)$/) {
		$ip = $1;
		$nm = $2;
		}
	elsif ($iflist[$i] =~ /^(\S+)$/) {
		$ip = $1;
		$nm = "";
		}
	$itable .= &ui_columns_row([
		&ui_textbox("interface_ip$i", $ip, 15),
		&ui_textbox("interface_nm$i", $nm, 15),
		]);
	}
$itable .= &ui_columns_end();
print &ui_table_row($text{'net_netinterface'},
	&ui_radio("interfaces_def", $ifaces ? 0 : 1,
		  [ [ 1, $text{'net_auto'} ],
		    [ 0, $text{'net_uselist'} ] ])."<br>\n".
	$itable);

print &ui_table_row($text{'net_keepalive'},
	&ui_opt_textbox("keepalive", &getval("keepalive"), 5,
			$text{'net_notsend'})." ".$text{'config_secs'});

print &ui_table_row($text{'net_maxpacket'},
	&ui_opt_textbox("max_xmit", &getval("max xmit"), 5,
			$text{'default'})." ".$text{'config_bytes'});

print &ui_table_row($text{'net_listen'},
	&ui_opt_textbox("socket_address", &getval("socket address"), 15,
			$text{'config_all'}, $text{'net_ip'}));

foreach (split(/\s+/, &getval("socket options"))) {
	if (/^([A-Z\_]+)=(.*)/) { $sopts{$1} = $2; }
	else { $sopts{$_} = ""; }
	}
@grid = ( );
for($i=0; $i<@sock_opts; $i++) {
	$sock_opts[$i] =~ /^([A-Z\_]+)(.*)$/;
	$f = &ui_checkbox("$1", 1, "$1", defined($sopts{$1}));
	if ($2 eq "*") {
		$f .= " ".&ui_textbox("${1}_val", $sopts{$1}, 5);
		}
	push(@grid, $f);
	print "</td>\n";
	}
print &ui_table_row($text{'net_socket'},
	&ui_grid_table(\@grid, 2));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_sharelist'});

