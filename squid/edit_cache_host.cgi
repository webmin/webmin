#!/usr/local/bin/perl
# edit_cache_host.cgi
# Display a form for editing or creating a cache_host line

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&ReadParse();
my $conf = &get_config();
my $cache_host = $squid_version >= 2 ? "cache_peer" : "cache_host";

my (%opts, @ch);
if ($in{'new'}) {
	&ui_print_header(undef, $text{'ech_header'}, "", undef, 0, 0, 0,
			 &restart_button());
	}
else {
	&ui_print_header(undef, $text{'ech_header1'}, "", undef, 0, 0, 0,
			 &restart_button());
	my @chl = &find_config($cache_host, $conf);
	@ch = @{$chl[$in{'num'}]->{'values'}};
	for(my $i=4; $i<@ch; $i++) {
		if ($ch[$i] =~ /^(\S+)=(\S+)$/) { $opts{$1} = $2; }
		else { $opts{$ch[$i]} = 1; }
		}
	}

print &ui_form_start("save_cache_host.cgi", "post");
if ($in{'new'}) {
	print &ui_hidden("new", 1);
	}
else {
	print &ui_hidden("num", $in{'num'});
	}
print &ui_table_start($text{'ech_cho'}, "width=100%", 4);

print &ui_table_row($text{'ech_h'},
	&ui_textbox("host", $ch[0], 30));

my @ts = ( [ "parent" => $text{"ech_parent"} ],
	   [ "sibling" => $text{"ech_sibling"} ],
	   [ "multicast" => $text{"ech_multicast"} ] );
print &ui_table_row($text{'ech_t'},
	&ui_select("type", $ch[1], \@ts));

print &ui_table_row($text{'ech_pp'},
	&ui_textbox("proxy", $ch[2], 6));

print &ui_table_row($text{'ech_ip'},
	&ui_textbox("icp", $ch[3], 6));

print &ui_table_row($text{'ech_po'},
	&ui_yesno_radio("proxy-only", $opts{'proxy-only'}));

print &ui_table_row($text{'ech_siq2'},
	&ui_yesno_radio("no-query", $opts{'no-query'}));

print &ui_table_row($text{'ech_dc'},
	&ui_yesno_radio("default", $opts{'default'}));

print &ui_table_row($text{'ech_rrc'},
	&ui_yesno_radio("round-robin", $opts{'round-robin'}));

print &ui_table_row($text{'ech_ittl'},
	&ui_opt_textbox("ttl", $opts{'ttl'}, 6, $text{'ech_d'}));

print &ui_table_row($text{'ech_cw'},
	&ui_opt_textbox("weight", $opts{'weight'}, 6, $text{'ech_d'}));

if ($squid_version >= 2) {
	print &ui_table_row($text{'ech_co'},
		&ui_yesno_radio("closest-only", $opts{'closest-only'}));

	print &ui_table_row($text{'ech_nd'},
		&ui_yesno_radio("no-digest", $opts{'no-digest'}));

	print &ui_table_row($text{'ech_nne'},
	    &ui_yesno_radio("no-netdb-exchange", $opts{'no-netdb-exchange'}));

	print &ui_table_row($text{'ech_nne'},
		&ui_yesno_radio("no-delay", $opts{'no-delay'}));
	}

if ($squid_version >= 2.1) {
	my $mode = $opts{'login'} eq 'PASS' ? 2 :
		      $opts{'login'} =~ /^\*:\S+$/ ? 3 :
		      $opts{'login'} ? 1 : 0;
	my @up = split(/:/, $opts{'login'});
	print &ui_table_row($text{'ech_ltp'},
	    &ui_radio_table("login", $mode,
		[ [ 0, $text{'ech_nl'} ],
		  [ 1, $text{'ech_u'},
		    &ui_textbox("login_user", $mode == 1 ? $up[0] : "", 15)." ".
		    $text{'ech_p'}." ".
		    &ui_textbox("login_pass", $mode == 1 ? $up[1] : "", 15) ],
		  [ 2, $text{'ech_pass'} ],
		  [ 3, $text{'ech_upass'},
		    &ui_textbox("login_pass2", $mode == 3 ? $up[1] : "", 15) ],
		]));
	}

if ($squid_version >= 2.6) {
	print &ui_table_row($text{'ech_timeo'},
		&ui_opt_textbox("connect-timeout", $opts{'connect-timeout'},
				6, $text{'ech_d'}));

	print &ui_table_row($text{'ech_digest'},
		&ui_opt_textbox("digest-url", $opts{'digest-url'},
				20, $text{'ech_d'}));

	print &ui_table_row($text{'ech_miss'},
		&ui_yesno_radio("allow-miss", $opts{'allow-miss'}));

	print &ui_table_row($text{'ech_maxconn'},
		&ui_opt_textbox("max-conn", $opts{'max-conn'}, 6,
				$text{'ech_d'}));

	print &ui_table_row($text{'ech_htcp'},
		&ui_yesno_radio("htcp", $opts{'htcp'}));

	print &ui_table_row($text{'ech_force'},
		&ui_opt_textbox("forceddomain", $opts{'forceddomain'}, 20,
				$text{'ech_same'}));

	print &ui_table_row($text{'ech_origin'},
		&ui_yesno_radio("originserver", $opts{'originserver'}));

	print &ui_table_row($text{'ech_ssl'},
		&ui_yesno_radio("ssl", $opts{'ssl'}));
	}

print &ui_table_row($text{'ech_mr'},
	&ui_yesno_radio("multicast-responder", $opts{'multicast-responder'}));

my (@dontq, @doq);
if (!$in{'new'}) {
	my @chd = &find_config($cache_host."_domain", $conf);
	foreach my $chd (@chd) {
		my @chdv = @{$chd->{'values'}};
		if ($chdv[0] eq $ch[0]) {
			# found a record for this host..
			for(my $i=1; $i<@chdv; $i++) {
				if ($chdv[$i] =~ /^\!(\S+)$/) {
					push(@dontq, $1);
					}
				else { push(@doq, $chdv[$i]); }
				}
			}
		}
	}
print &ui_table_row($text{'ech_qhfd'},
	&ui_textarea("doq", join("\n", @doq), 6, 30));

print &ui_table_row($text{'ech_dqfd'},
	&ui_textarea("dontq", join("\n", @dontq), 6, 30));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'ech_buttsave'} ],
	     $in{'new'} ? ( ) : ( [ 'delete', $text{'ech_buttdel'} ] ) ]);

&ui_print_footer("edit_icp.cgi", $text{'ech_return'},
	"", $text{'index_return'});

