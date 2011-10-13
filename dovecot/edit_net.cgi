#!/usr/local/bin/perl
# Show networking options

require './dovecot-lib.pl';
&ui_print_header(undef, $text{'net_title'}, "");
$conf = &get_config();

print &ui_form_start("save_net.cgi", "post");
print &ui_table_start($text{'net_header'}, "width=100%", 4);

# Mail protocols
@supported_protocols = &get_supported_protocols();
@protos = split(/\s+/, &find_value("protocols", $conf));
print &ui_table_row($text{'net_protocols'},
	    &ui_select("protocols", \@protos,
		[ map { [ $_, $text{'net_'.$_} ] } @supported_protocols ],
		scalar(@supported_protocols), 1, 1));

# SSL supported?
$sslopt = &find("ssl_disable", $conf, 2) ? "ssl_disable" : "ssl";
$dis = &find_value($sslopt, $conf);
if ($sslopt eq "ssl") {
	@opts = ( [ "yes", $text{'yes'} ], [ "no", $text{'no'} ] );
	}
else {
	@opts = ( [ "no", $text{'yes'} ], [ "yes", $text{'no'} ] );
	}
print &ui_table_row($text{'net_ssl_disable'},
	    &ui_radio($sslopt, $dis,
		      [ @opts,
			[ "", &getdef($sslopt, \@opts) ] ]));

@listens = &find("imap_listen", $conf, 2) ?
		("imap_listen", "pop3_listen", "imaps_listen", "pop3s_listen") :
		("listen", "ssl_listen");
foreach $l (@listens) {
	$listen = &find_value($l, $conf);
	$mode = !$listen ? 0 :
	        $listen eq "[::]" ? 1 :
	        $listen eq "*" ? 2 : 3,
	print &ui_table_row($text{'net_'.$l},
		&ui_radio($l."_mode", $mode,
			  [ [ 0, $text{'net_listen0'} ],
			    [ 1, $text{'net_listen1'} ],
			    [ 2, $text{'net_listen2'} ],
			    [ 3, $text{'net_listen3'} ] ])."\n".
		&ui_textbox($l, $mode == 3 ? $listen : "", 20), 3);
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

