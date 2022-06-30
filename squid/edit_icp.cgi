#!/usr/local/bin/perl
# edit_icp.cgi
# A form for editing options for communication with other caches

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&ui_print_header(undef, $text{'eicp_header'}, "", "edit_icp", 0, 0, 0, &restart_button());
my $conf = &get_config();
my $cache_host = $squid_version >= 2 ? "cache_peer" : "cache_host";

my @ch = &find_config($cache_host, $conf);
my @links = ( &select_all_link("d"),
	      &select_invert_link("d"),
	      &ui_link("edit_cache_host.cgi?new=1", $text{'eicp_aac'}) );
if (@ch) {
	my $mid = int((@ch+1)/2);
	print &ui_form_start("delete_icps.cgi", "post");
	print &ui_links_row(\@links);
	print &cache_table(0, $#ch, \@ch);
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'eicp_delete'} ] ]);
	}
else {
	print "<b>$text{'eicp_nocd'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

print &ui_hr();

print &ui_form_start("save_icp.cgi", "post");
print &ui_table_start($text{'eicp_cso'}, "width=100%", 4);

if ($squid_version < 2) {
	print &list_input($text{'eicp_fdfd'}, "local_domain", $conf);
	print &address_input($text{'eicp_fdfi'}, "local_ip", $conf);

	print &list_input($text{'eicp_dif'}, "inside_firewall", $conf);
	print &address_input($text{'eicp_iif'}, "firewall_ip", $conf);
	}

print &list_input($text{'eicp_dfuc'}, "hierarchy_stoplist",
		  $conf, 1, $text{'default'});

if ($squid_version < 2) {
	print &choice_input($text{'eicp_bpfsp'},
			    "single_parent_bypass",
			    $conf, "off", $text{'yes'}, "on", $text{'no'}, "off");
	print &choice_input($text{'eicp_ssip'}, "source_ping", $conf, "off",
			    $text{'yes'}, "on", $text{'no'}, "off");

	print &opt_input($text{'eicp_crt'}, "neighbor_timeout", $conf,
			 $text{'default'}, 4, $text{'eicp_secs'});
	}
else {
	print &opt_input($text{'eicp_iqt'}, "icp_query_timeout", $conf,
			 $text{'default'}, 8, "ms");
	print &opt_input($text{'eicp_mit'}, "mcast_icp_query_timeout",
			 $conf, $text{'default'}, 8, "ms");

	print &opt_input($text{'eicp_dpt'}, "dead_peer_timeout", $conf,
			 $text{'default'}, 8, $text{'eicp_secs'});
	}

if ($squid_version >= 2.3) {
	# Display always/never_direct options
	print &ui_hr();

	my @always = &find_config("always_direct", $conf);
	my @tds = ( "width=10%", undef, "width=10%" );
	my $table;
	if (@always) {
		$table = &ui_columns_start([ $text{'eacl_act'},
					     $text{'eacl_acls1'},
					     $text{'eacl_move'} ], undef, 0,
					   \@tds);
		my $hc = 0;
		foreach my $h (@always) {
			my @v = @{$h->{'values'}};
			if ($v[0] eq "allow") {
				$v[0] = $text{'eacl_allow'};
				}
			else {
				$v[0] = $text{'eacl_deny'};
				}
			my @moves;
			if ($hc != @always-1) {
				push(@moves, &ui_link(
					"move_always.cgi?$hc+1",
					"<img src=images/down.gif border=0>"));
				}
			else {
				push(@moves, "<img src=images/gap.gif>");
				}
			if ($hc != 0) {
				push(@moves, &ui_link(
					"move_always.cgi?$hc+-1",
					"<img src=images/up.gif border=0>"));
				}
			$table .= &ui_columns_row([
			    &ui_link("always.cgi?index=$h->{'index'}", $v[0]),
			    &html_escape(join(' ', @v[1..$#v])),
			    join("", @moves),
			    ]);
			$hc++;
			}
		$table .= &ui_columns_end();
		}
	else {
		$table = "<b>$text{'eicp_noalways'}</b><p>\n";
		}
	$table .= &ui_links_row([ &ui_link("always.cgi?new=1",
					   $text{'eicp_addalways'}) ]);
	print &ui_table_row($text{'eicp_always'}, $table, 3);

	my @never = &find_config("never_direct", $conf);
	if (@never) {
		$table = &ui_columns_start([ $text{'eacl_act'},
					     $text{'eacl_acls1'},
					     $text{'eacl_move'} ], undef, 0,
					   \@tds);
		my $hc = 0;
		foreach my $h (@never) {
			my @v = @{$h->{'values'}};
			if ($v[0] eq "allow") {
				$v[0] = $text{'eacl_allow'};
				}
			else {
				$v[0] = $text{'eacl_deny'};
				}
			my @moves;
			if ($hc != @never-1) {
				push(@moves, &ui_link(
					"move_never.cgi?$hc+1",
					"<img src=images/down.gif border=0>"));
				}
			else {
				push(@moves, "<img src=images/gap.gif>");
				}
			if ($hc != 0) {
				push(@moves, &ui_link(
					"move_never.cgi?$hc+-1",
					"<img src=images/up.gif border=0>"));
				}
			$table .= &ui_columns_row([
			    &ui_link("never.cgi?index=$h->{'index'}", $v[0]),
			    &html_escape(join(' ', @v[1..$#v])),
			    join("", @moves),
			    ]);
			$hc++;
			}
		$table .= &ui_columns_end();
		}
	else {
		$table = "<b>$text{'eicp_nonever'}</b><p>\n";
		}
	$table .= &ui_links_row([ &ui_link("never.cgi?new=1",
					   $text{'eicp_addnever'}) ]);
	print &ui_table_row($text{'eicp_never'}, $table, 3);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'buttsave'} ] ]);

&ui_print_footer("", $text{'eicp_return'});

# cache_table(start, end, &caches)
sub cache_table
{
my ($start, $end, $ch) = @_;
my @tds = ( "width=5" );
my $rv = &ui_columns_start([ "",
			     $text{'eicp_thost'},
			     $text{'eicp_ttype'},
			     $text{'eicp_tpport'},
			     $text{'eicp_tiport'} ], 100, 0, \@tds);
for(my $i=$start; $i<=$end; $i++) {
	my @chv = @{$ch->[$i]->{'values'}};
	$rv .= &ui_checked_columns_row([
		&ui_link("edit_cache_host.cgi?num=$i",
			 &html_escape($chv[0])),
		&html_escape($chv[1]),
		&html_escape($chv[2]),
		&html_escape($chv[3])
		], \@tds, "d", $i);
	}
$rv .= &ui_columns_end();
return $rv;
}

