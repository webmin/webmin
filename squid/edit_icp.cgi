#!/usr/local/bin/perl
# edit_icp.cgi
# A form for editing options for communication with other caches

require './squid-lib.pl';
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&ui_print_header(undef, $text{'eicp_header'}, "", "edit_icp", 0, 0, 0, &restart_button());
$conf = &get_config();
$cache_host = $squid_version >= 2 ? "cache_peer" : "cache_host";

@ch = &find_config($cache_host, $conf);
@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   "<a href='edit_cache_host.cgi?new=1'>$text{'eicp_aac'}</a>" );
if (@ch) {
	#print &ui_subheading($text{'eicp_opcs'});
	$mid = int((@ch+1)/2);
	print &ui_form_start("delete_icps.cgi", "post");
	print &ui_links_row(\@links);
	print "<table width=100%><tr> <td width=50% valign=top>\n";
	&cache_table(0, $mid-1);
	print "</td><td width=50% valign=top>\n";
	if ($mid < @ch) { &cache_table($mid, $#ch); }
	print "</td> </tr></table>\n";
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'eicp_delete'} ] ]);
	}
else {
	print "<b>$text{'eicp_nocd'}</b>.<p>\n";
	print &ui_links_row([ $links[2] ]);
	}

print &ui_hr();
print "<form action=save_icp.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'eicp_cso'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($squid_version < 2) {
	print "<tr>\n";
	print &list_input($text{'eicp_fdfd'}, "local_domain", $conf);
	print &address_input($text{'eicp_fdfi'}, "local_ip", $conf);
	print "</tr>\n";

	print "<tr>\n";
	print &list_input($text{'eicp_dif'}, "inside_firewall", $conf);
	print &address_input($text{'eicp_iif'}, "firewall_ip", $conf);
	print "</tr>\n";
	}

print "<tr>\n";
print &list_input($text{'eicp_dfuc'}, "hierarchy_stoplist",
		  $conf, 1, $text{'default'});
print "</tr>\n";

if ($squid_version < 2) {
	print "<tr>\n";
	print &choice_input($text{'eicp_bpfsp'},
			    "single_parent_bypass",
			    $conf, "off", $text{'yes'}, "on", $text{'no'}, "off");
	print &choice_input($text{'eicp_ssip'}, "source_ping", $conf, "off",
			    $text{'yes'}, "on", $text{'no'}, "off");
	print "</tr>\n";

	print "<tr>\n";
	print &opt_input($text{'eicp_crt'}, "neighbor_timeout", $conf,
			 $text{'default'}, 4, $text{'eicp_secs'});
	print "</tr>\n";
	}
else {
	print "<tr>\n";
	print &opt_input($text{'eicp_iqt'}, "icp_query_timeout", $conf,
			 $text{'default'}, 8, "ms");
	print &opt_input($text{'eicp_mit'}, "mcast_icp_query_timeout",
			 $conf, $text{'default'}, 8, "ms");
	print "</tr>\n";

	print "<tr>\n";
	print &opt_input($text{'eicp_dpt'}, "dead_peer_timeout", $conf,
			 $text{'default'}, 8, $text{'eicp_secs'});
	print "</tr>\n";
	}

if ($squid_version >= 2.3) {
	# Display always/never_direct options
	print "<tr> <td colspan=4><hr></td> </tr>\n";

	print "<tr> <td colspan=2 valign=top width=50%>\n";
	@always = &find_config("always_direct", $conf);
	if (@always) {
		print "<b>$text{'eicp_always'}</b><p>\n";
		print "<table border>\n";
		print "<tr $tb><td width=10%><b>$text{'eacl_act'}</b></td>\n";
		print "<td><b>$text{'eacl_acls1'}</b></td>\n";
		print "<td width=10%><b>$text{'eacl_move'}</b></td> </tr>\n";
		$hc = 0;
		foreach $h (@always) {
			@v = @{$h->{'values'}};
			if ($v[0] eq "allow") {
				$v[0] = $text{'eacl_allow'};
			} else {
				$v[0] = $text{'eacl_deny'};
			}
			print "<tr $cb>\n";
			print "<td><a href=\"always.cgi?index=$h->{'index'}\">",
			      "$v[0]</a></td>\n";
			print "<td>",&html_escape(join(' ', @v[1..$#v])),
			      "</td>\n";
			print "<td>\n";
			if ($hc != @always-1) {
				print "<a href=\"move_always.cgi?$hc+1\">",
				      "<img src=images/down.gif border=0></a>";
				}
			else { print "<img src=images/gap.gif>"; }
			if ($hc != 0) {
				print "<a href=\"move_always.cgi?$hc+-1\">",
				      "<img src=images/up.gif border=0></a>";
				}
			print "</td></tr>\n";
			$hc++;
			}
		print "</table>\n";
		}
	else {
		print "<b>$text{'eicp_noalways'}</b><p>\n";
		}
	print "<a href=always.cgi?new=1>$text{'eicp_addalways'}</a>\n";

	print "</td> <td colspan=2 valign=top width=50%>\n";
	@never = &find_config("never_direct", $conf);
	if (@never) {
		print "<b>$text{'eicp_never'}</b><p>\n";
		print "<table border>\n";
		print "<tr $tb><td width=10%><b>$text{'eacl_act'}</b></td>\n";
		print "<td><b>$text{'eacl_acls1'}</b></td>\n";
		print "<td width=10%><b>$text{'eacl_move'}</b></td> </tr>\n";
		$hc = 0;
		foreach $h (@never) {
			@v = @{$h->{'values'}};
			if ($v[0] eq "allow") {
				$v[0] = $text{'eacl_allow'};
			} else {
				$v[0] = $text{'eacl_deny'};
			}
			print "<tr $cb>\n";
			print "<td><a href=\"never.cgi?index=$h->{'index'}\">",
			      "$v[0]</a></td>\n";
			print "<td>",&html_escape(join(' ', @v[1..$#v])),
			      "</td>\n";
			print "<td>\n";
			if ($hc != @never-1) {
				print "<a href=\"move_never.cgi?$hc+1\">",
				      "<img src=images/down.gif border=0></a>";
				}
			else { print "<img src=images/gap.gif>"; }
			if ($hc != 0) {
				print "<a href=\"move_never.cgi?$hc+-1\">",
				      "<img src=images/up.gif border=0></a>";
				}
			print "</td></tr>\n";
			$hc++;
			}
		print "</table>\n";
		}
	else {
		print "<b>$text{'eicp_nonever'}</b><p>\n";
		}
	print "<a href=never.cgi?new=1>$text{'eicp_addnever'}</a>\n";
	print "</td> </tr>\n";
	}

print "</table></td></tr></table>\n";
print "<input type=submit value=$text{'buttsave'}></form>\n";

&ui_print_footer("", $text{'eicp_return'});

# cache_table(start, end)
sub cache_table
{
local @tds = ( "width=5" );
print &ui_columns_start([ "",
			  $text{'eicp_thost'},
			  $text{'eicp_ttype'},
			  $text{'eicp_tpport'},
			  $text{'eicp_tiport'} ], 100, 0, \@tds);
for($i=$_[0]; $i<=$_[1]; $i++) {
	@chv = @{$ch[$i]->{'values'}};
	print &ui_checked_columns_row([
		"<a href=\"edit_cache_host.cgi?num=$i\">".
	        &html_escape($chv[0])."</a>",
		&html_escape($chv[1]),
		&html_escape($chv[2]),
		&html_escape($chv[3])
		], \@tds, "d", $i);
	}
print &ui_columns_end();
}

