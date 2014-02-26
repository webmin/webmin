#!/usr/local/bin/perl
# edit_cache.cgi
# A form for editing cache options

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'copts'} || &error($text{'ec_ecannot'});
&ui_print_header(undef, $text{'ec_header'}, "", "edit_cache", 0, 0, 0, &restart_button());
my $conf = &get_config();

print &ui_form_start("save_cache.cgi", "post");
print &ui_table_start($text{'ec_cro'}, "width=100%", 4);

my @dirs = &find_config("cache_dir", $conf);
my $dtable = &ui_radio("cache_dir_def", @dirs ? 0 : 1,
		       [ [ 1, "$text{'ec_default'} ($config{'cache_dir'})" ],
			 [ 0, $text{'ec_listed'} ] ])."<br>\n";

my @cols = ( $text{'ec_directory'} );
if ($squid_version >= 2.3) {
	push(@cols, $text{'ec_type'});
	}
push(@cols, $text{'ec_size'}, $text{'ec_1dirs'}, $text{'ec_2dirs'});
if ($squid_version >= 2.4) {
	push(@cols, $text{'ec_opts'});
	}
$dtable .= &ui_columns_start(\@cols, 100);

for(my $i=0; $i<=@dirs; $i++) {
	my @dv = $i<@dirs ? @{$dirs[$i]->{'values'}} : ();
	my @row;
	if ($squid_version >= 2.4) {
		push(@row, &ui_textbox("cache_dir_$i", $dv[1], 30));
		push(@row, &ui_select("cache_type_$i", $dv[0],
				[ [ 'ufs', $text{'ec_u'} ],
				  [ 'diskd', $text{'ec_diskd'} ],
				  [ 'aufs', $text{'ec_ua'} ],
				  [ 'coss', $text{'ec_coss'} ] ]));
		push(@row, &ui_textbox("cache_size_$i", $dv[2], 8));
		push(@row, &ui_textbox("cache_lv1_$i", $dv[3], 8));
		push(@row, &ui_textbox("cache_lv2_$i", $dv[4], 8));
		push(@row, &ui_textbox("cache_opts_$i",
				       join(" ",@dv[5..$#dv]), 20));
		}
	elsif ($squid_version >= 2.3) {
		push(@row, &ui_textbox("cache_dir_$i", $dv[1], 30));
		push(@row, &ui_select("cache_type_$i", $dv[0],
				[ [ 'ufs', $text{'ec_u'} ],
				  [ 'asyncufs', $text{'ec_ua'} ] ]));
		push(@row, &ui_textbox("cache_size_$i", $dv[2], 8));
		push(@row, &ui_textbox("cache_lv1_$i", $dv[3], 8));
		push(@row, &ui_textbox("cache_lv2_$i", $dv[4], 8));
		}
	elsif ($squid_version >= 2) {
		push(@row, &ui_textbox("cache_dir_$i", $dv[0], 40));
		push(@row, &ui_textbox("cache_size_$i", $dv[1], 8));
		push(@row, &ui_textbox("cache_lv1_$i", $dv[2], 8));
		push(@row, &ui_textbox("cache_lv2_$i", $dv[3], 8));
		}
	else {
		push(@row, &ui_textbox("cache_dir_$i", $dv[0], 50));
		}
	$dtable .= &ui_columns_row(\@row);
	}
$dtable .= &ui_columns_end();
print &ui_table_row($text{'ec_cdirs'}, $dtable, 3);

print &ui_table_hr();

if ($squid_version < 2) {
	print &opt_input($text{'ec_1dirs1'}, "swap_level1_dirs", $conf,
			 $text{'ec_default'}, 6);
	print &opt_input($text{'ec_2dirs2'}, "swap_level2_dirs", $conf,
			 $text{'ec_default'}, 6);
	}

if ($squid_version < 2) {
	print &opt_input($text{'ec_aos'}, "store_avg_object_size", $conf,
			 $text{'ec_default'}, 6, $text{'ec_kb'});
	}
else {
	print &opt_bytes_input($text{'ec_aos'}, "store_avg_object_size",
			       $conf, $text{'ec_default'}, 6);
	}
print &opt_input($text{'ec_opb'}, "store_objects_per_bucket", $conf,
		 $text{'ec_default'}, 6);

if ($squid_version < 2) {
	print &list_input($text{'ec_ncuc'}, "cache_stoplist",
			  $conf, 1, $text{'ec_default'});

	print &list_input($text{'ec_ncum'}, "cache_stoplist_pattern",
			  $conf, 1, $text{'ec_default'});
	}

# ACLs not to cache
my %acldone;
my @acls = grep { !$acldone{$_->{'values'}->[0]}++ } &find_config("acl", $conf);
unshift(@acls, { 'values' => [ 'all' ] }) if ($squid_version >= 3);
my @v;
if ($squid_version >= 2.6) {
	# 2.6+ plus uses "cache deny"
	@v = &find_config("cache", $conf);
	}
else {
	# Older versions use cache
	@v = &find_config("no_cache", $conf);
	}
my %noca;
foreach my $v (@v) {
	foreach my $ncv (@{$v->{'values'}}) {
		$noca{$ncv}++;
		}
	}
my @grid;
foreach my $acl (@acls) {
	my $aclv = $acl->{'values'}->[0];
	push(@grid, &ui_checkbox("no_cache", $aclv, $aclv, $noca{$aclv}));
	}
print &ui_table_row($text{'ec_ncua'},
	&ui_grid_table(\@grid, 4));

print &opt_time_input($text{'ec_mct'}, "reference_age", $conf,
		      $text{'default'}, 6);

if ($squid_version >= 2) {
	if ($squid_version >= 2.3) {
		print &opt_bytes_input($text{'ec_mrbs'},
			"request_body_max_size", $conf, $text{'default'}, 6);
		print &opt_bytes_input($text{'ec_mrhs'},
			"request_header_max_size", $conf, $text{'default'}, 6);

		if ($squid_version < 2.5) {
			print &opt_bytes_input($text{'ec_mrbs1'},
			   "reply_body_max_size", $conf, $text{'default'}, 6);
			}
		else {
			print &opt_bytes_input($text{'ec_gap'},
			   "read_ahead_gap", $conf, $text{'default'}, 6);
			}
		}
	else {
		print &opt_bytes_input($text{'ec_mrs'}, "request_size",
				       $conf, $text{'default'}, 6);
		}
	print &opt_time_input($text{'ec_frct'},
			      "negative_ttl", $conf, $text{'default'}, 4);
	}
else {
	print &opt_input($text{'ec_mrs'}, "request_size", $conf,
			 $text{'default'}, 8, $text{'ec_kb'});
	print &opt_input($text{'ec_frct'}, "negative_ttl", $conf,
			 $text{'default'}, 4, $text{'ec_mins'});
	}
print "</tr>\n";

if ($squid_version >= 2.5) {
	# Max reply size can be limited by ACL
	my $rtable = &ui_columns_start([ $text{'ec_maxrn'},
					 $text{'ec_maxracls'} ]);
	my @maxrs = &find_config("reply_body_max_size", $conf);
	my $i = 0;
	foreach my $m (@maxrs, { 'values' => [] }) {
		my ($s, @a) = @{$m->{'values'}};
		$rtable .= &ui_columns_row([
			&ui_textbox("reply_body_max_size_$i", $s, 8),
			&ui_textbox("reply_body_max_acls_$i", join(" ", @a),50),
			]);
		$i++;
		}
	$rtable .= &ui_columns_end();
	print &ui_table_row($text{'ec_maxreplies'}, $rtable, 3);
	}

if ($squid_version < 2) {
	print &opt_input($text{'ec_dlct'}, "positive_dns_ttl", $conf,
			 $text{'default'}, 4, $text{'ec_mins'});
	print &opt_input($text{'ec_fdct'}, "negative_dns_ttl", $conf,
			 $text{'default'}, 4, $text{'ec_mins'});
	}
else {
	print &opt_time_input($text{'ec_dlct'}, "positive_dns_ttl",
			      $conf, $text{'default'}, 4);
	print &opt_time_input($text{'ec_fdct'}, "negative_dns_ttl",
			      $conf, $text{'default'}, 4);
	}

if ($squid_version < 2) {
	print &opt_input($text{'ec_ct'}, "connect_timeout", $conf,
			 $text{'default'}, 4, $text{'ec_secs'});
	print &opt_input($text{'ec_rt'}, "read_timeout", $conf,
			 $text{'default'}, 4, $text{'ec_secs'});

	print &opt_input($text{'ec_mcct'}, "client_lifetime", $conf,
			 $text{'default'}, 4, $text{'ec_mins'});
	print &opt_input($text{'ec_mst'}, "shutdown_lifetime", $conf,
			 $text{'default'}, 4, $text{'ec_mins'});
	}
else {
	print &opt_time_input($text{'ec_ct'}, "connect_timeout", $conf,
			      $text{'default'}, 4);
	print &opt_time_input($text{'ec_rt'}, "read_timeout", $conf,
			      $text{'default'}, 4);

	print &opt_time_input($text{'ec_sst'}, "siteselect_timeout",
			      $conf, $text{'default'}, 4);
	print &opt_time_input($text{'ec_crt'}, "request_timeout",
			      $conf, $text{'default'}, 4);
	print "</tr>\n";

	print &opt_time_input($text{'ec_mcct'}, "client_lifetime",
			      $conf, $text{'default'}, 4);
	print &opt_time_input($text{'ec_mst'}, "shutdown_lifetime",
			      $conf, $text{'default'}, 4);

	print &choice_input($text{'ec_hcc'}, "half_closed_clients",
			    $conf, "on", $text{'on'},"on", $text{'off'},"off");
	print &opt_time_input($text{'ec_pt'}, "pconn_timeout",
			      $conf, $text{'default'}, 4);
	}

if ($squid_version >= 2) {
	print &opt_input($text{'ec_wrh'}, "wais_relay_host",
			 $conf, $text{'none'}, 20);
	print &opt_input($text{'ec_wrp'}, "wais_relay_port",
			 $conf, $text{'default'}, 6);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'buttsave'} ] ]);

&ui_print_footer("", $text{'ec_return'});

