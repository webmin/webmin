#!/usr/local/bin/perl
# edit_stunnel.cgi
# Edit or create an SSL tunnel run from inetd

require './stunnel-lib.pl';
&ReadParse();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "");
	$st = { 'active' => 1 };
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "");
	@stunnels = &list_stunnels();
	$st = $stunnels[$in{'idx'}];
	}

print &ui_form_start("save_stunnel.cgi", "post");
print &ui_hidden("new",$in{'new'});
print &ui_hidden("idx",$in{'idx'});
print &ui_table_start($text{'edit_header1'}, "width=80%", 4);
print &ui_columns_row([
            "<b>$text{'edit_name'}</b>&nbsp;",
            &ui_textbox("name", $st->{'name'}, 15),
            "&nbsp;<b>$text{'edit_port'}</b>&nbsp;",
            &ui_textbox("port", $st->{'port'}, 6)
        ]);
print &ui_columns_row([
            "<b>$text{'edit_active'}</b>",
            &ui_oneradio("active","1", $text{'yes'}, ($st->{'active'} ? 1 : 0) ).
            "&nbsp;".&ui_oneradio("active","0", $text{'no'}, ($st->{'active'} ? 0 : 1) ),
            "<b>$text{'edit_type'}</b>",
            ( !$in{'new'} ? "<tt>$st->{'type'}</tt>" : 
                ( $has_inetd && $has_xinetd ? &ui_select("type", undef,[["xinetd","xinetd","selected"],["inetd","inetd",""]]) : "") )
        ]);
print ui_table_end();
print "<br>";

if ($in{'new'}) {
	$ptymode = 'l';
	}
elsif (&get_stunnel_version() >= 4) {
	# Parse new-style stunnel configuration file
	if ($st->{'args'} =~ /^(\S+)\s+(\S+)/) {
		$cfile = $2;
		@conf = &get_stunnel_config($cfile);
		($conf) = grep { !$_->{'name'} } @conf;
		if ($cmd = $conf->{'values'}->{'exec'}) {
			$args = $conf->{'values'}->{'execargs'};
			$ptymode = $conf->{'values'}->{'pty'} eq 'yes' ? "L"
								       : "l";
			}
		else {
			$rport = $conf->{'values'}->{'connect'};
			if ($rport =~ /^(\S+):(\d+)/) {
				$rhost = $1;
				$rport = $2;
				}
			}
		$pem = $conf->{'values'}->{'cert'};
		$cmode = $conf->{'values'}->{'client'} =~ /yes/i;
		$tcpw = $conf->{'values'}->{'service'};
		$iface = $conf->{'values'}->{'local'};
		}
	}
else {
	# Parse old-style stunnel parameters
	if ($st->{'args'} =~ s/\s*-([lL])\s+(\S+)\s+--\s+(.*)// ||
	    $st->{'args'} =~ s/\s*-([lL])\s+(\S+)//) {
		$ptymode = $1;
		$cmd = $2;
		$args = $3;
		}
	if ($st->{'args'} =~ s/\s*-r\s+((\S+):)?(\d+)//) {
		$rhost = $2;
		$rport = $3;
		}
	if ($st->{'args'} =~ s/\s*-p\s+(\S+)//) {
		$pem = $1;
		}
	if ($st->{'args'} =~ s/\s*-c//) {
		$cmode = 1;
		}
	if ($st->{'args'} =~ s/\s*-N\s+(\S+)//) {
		$tcpw = $1;
		}
	if ($st->{'args'} =~ s/\s*-I\s+(\S+)//) {
		$iface = $1;
		}
	}

print &ui_table_start($text{'edit_header2'}, "width=80%", 5);
print &ui_columns_row([
            &ui_oneradio("mode","0", $text{'edit_mode0'}, ($ptymode eq 'l' ? 1 : 0) ),
            "<b>$text{'edit_cmd'}</b>", &ui_textbox("cmd0", ( $ptymode eq 'l' ? $cmd : "" ), 20),
            "<b>$text{'edit_args'}</b>", &ui_textbox("args0", ( $ptymode eq 'l' ? $args : "" ), 20)
        ]);
print &ui_columns_row([
            &ui_oneradio("mode","1", $text{'edit_mode1'}, ($ptymode eq 'L' ? 1 : 0) ),
            "<b>$text{'edit_cmd'}</b>", &ui_textbox("cmd1", ( $ptymode eq 'L' ? $cmd : "" ), 20),
            "<b>$text{'edit_args'}</b>", &ui_textbox("args1", ( $ptymode eq 'L' ? $args : "" ), 20)
        ]);
print &ui_columns_row([
            &ui_oneradio("mode","2", $text{'edit_mode2'}, ($rport ? 1 : 0) ),
            "<b>$text{'edit_rhost'}</b>", &ui_textbox("rhost", ( !$rport ? "" : ( $rhost ? $rhost : "localhost" ) ), 20),
            "<b>$text{'edit_rport'}</b>", &ui_textbox("rport", $rport, 6)
        ]);
print ui_table_end();
print "<br>";

$haspem = $config{'pem_path'} && -r $config{'pem_path'};
print &ui_table_start($text{'edit_header3'}, "width=80%", 2);
if ($in{'new'}) {
    print &ui_columns_row([
                "<b>$text{'edit_pem'}</b>",
                &ui_oneradio("pmode","0", $text{'edit_pem0'})."&nbsp;".
                &ui_oneradio("pmode","1", $text{'edit_pem1'}, ( $haspem ? 0 : 1) )."&nbsp;".
                &ui_oneradio("pmode","2", $text{'edit_pem2'}, ( $haspem ? 1 : 0) )."&nbsp;".
                &ui_filebox("pem", ( $haspem ? $config{'pem_path'} : "" ), 25)
            ]);
} else {
	local $pmode = $pem eq $webmin_pem ? 1 : $pem ? 2 : 0;
    print &ui_columns_row([
                "<b>$text{'edit_pem'}</b>",
                &ui_oneradio("pmode","0", $text{'edit_pem0'}, ( $pmode == 0 ? 1 : 0 ) )."&nbsp;".
                &ui_oneradio("pmode","1", $text{'edit_pem1'}, ( $pmode == 1 ? 1 : 0 ) )."&nbsp;".
                &ui_oneradio("pmode","2", $text{'edit_pem2'}, ( $pmode == 2 ? 1 : 0) )."&nbsp;".
                &ui_filebox("pem", ( $pmode == 2 ? $pem : "" ), 25)
            ]);
}
print &ui_columns_row([
            "<b>$text{'edit_tcpw'}</b>",
            &ui_oneradio("tcpw_def","1", $text{'edit_auto'}, ( $tcpw ? 0 : 1 ) )."&nbsp;".
            &ui_oneradio("tcpw_def","0", undef, ( $tcpw ? 1 : 0 ) )."&nbsp;".
            &ui_textbox("tcpw", $tcpw, 25)
        ]);
print &ui_columns_row([
            "<b>$text{'edit_cmode'}</b>",
            &ui_oneradio("cmode","0", $text{'edit_cmode0'}, ( $cmode ? 0 : 1 ) )."&nbsp;".
            &ui_oneradio("cmode","1", $text{'edit_cmode1'}, ( $cmode ? 1 : 0 ) )
        ]);
print &ui_columns_row([
            "<b>$text{'edit_iface'}</b>",
            &ui_oneradio("iface_def","1", $text{'edit_auto'}, ( $iface ? 0 : 1 ) )."&nbsp;".
            &ui_oneradio("iface_def","0", undef, ( $iface ? 1 : 0 ) )."&nbsp;".
            &ui_textbox("iface", $iface, 25)
        ]);
print ui_table_end();

print &ui_hidden("args",$st->{'args'});
print "<br>";
if ($in{'new'}) {
    print &ui_submit($text{'create'});
} else {
    print &ui_submit($text{'save'})."&nbsp;".&ui_submit($text{'delete'},"delete");
}
print &ui_form_end();

&ui_print_footer("", $text{'index_return'});

