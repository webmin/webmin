#!/usr/local/bin/perl
# acl.cgi
# Display a form for editing or creating a new ACL

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config, %acl_types,
     @caseless_acl_types);
require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
my $conf = &get_config();

my $type;
my (@acl, @deny, @vals, $file);
if ($in{'type'}) {
	&ui_print_header(undef, $text{'acl_header1'}, "", undef, 0, 0, 0,
			 &restart_button());
	$type = $in{'type'};
	@vals = ( );
	}
else {
	&ui_print_header(undef, $text{'acl_header2'}, "", undef, 0, 0, 0,
			 &restart_button());
	@acl = @{$conf->[$in{'index'}]->{'values'}};
	$type = $acl[1];
	if (($type eq "external" ||
	     &indexof($type, @caseless_acl_types) >= 0) &&
	    $acl[3] =~ /^"(.*)"$/) {
		# Extra parameters come from file
		@vals = ( $acl[2] );
		$file = $1;
		}
	elsif ($acl[2] =~ /^"(.*)"$/) {
		# All values come from a file
		$file = $1;
		}
	else {
		# All values come from acl parameters
		@vals = @acl[2..$#acl];
		}
	if ($file) {
		my @newvals = split(/\r?\n/, &read_file_contents($file));
		push(@vals, @newvals);
		}
	if ($type =~ /^(src|dst|srcdomain|dstdomain|user|myip)$/) {
		@vals = sort { $a cmp $b } @vals;
		}
	elsif ($type eq "port") {
		@vals = sort { $a <=> $b } @vals;
		}
	@deny = grep { $_->{'values'}->[1] eq $acl[0] }
			&find_config("deny_info", $conf);
	}

print &ui_form_start("acl_save.cgi", "form-data");
if (@acl) {
	print &ui_hidden("index", $in{'index'});
	}
if (@deny) {
	print &ui_hidden("dindex", $deny[0]->{'index'});
	}
print &ui_hidden("type", $type);
print &ui_table_start("$acl_types{$type} ACL", undef, 2);

# ACL name
print &ui_table_row($text{'acl_name'},
	&ui_textbox("name", $acl[0], 30));

if ($type eq "src" || $type eq "dst") {
	# By source or dest address/network
	my $table = &ui_columns_start([ $text{'acl_fromip'},
					$text{'acl_toip'},
					$text{'acl_nmask'} ]);
	for(my $i=0; $i<=@vals; $i++) {
		my ($from, $to, $mask) = @_;
		if ($vals[$i] =~ /^([a-z0-9\.\:]+)-([a-z0-9\.\:]+)\/([\d\.]+)$/) {
			$from = $1; $to = $2; $mask = $3;
			}
		elsif ($vals[$i] =~ /^([a-z0-9\.\:]+)-([a-z0-9\.\:]+)$/) {
			$from = $1; $to = $2; $mask = "";
			}
		elsif ($vals[$i] =~ /^([a-z0-9\.\:]+)\/([\d\.]+)$/) {
			$from = $1; $to = ""; $mask = $2;
			}
		elsif ($vals[$i] =~ /^([a-z0-9\.\:]+)$/) {
			$from = $1; $to = ""; $mask = "";
			}
		else { $from = $to = $mask = ""; }
		$table .= &ui_columns_row([
			&ui_textbox("from_$i", $from, 20),
			&ui_textbox("to_$i", $to, 20),
			&ui_textbox("mask_$i", $mask, 20),
			]);
		}
	$table .= &ui_columns_end();
	print &ui_table_row(undef, $table, 2);
	}
elsif ($type eq "myip") {
	# By local IP address
	my $table = &ui_columns_start([ $text{'acl_ipaddr'},
					$text{'acl_nmask'} ]);
	for(my $i=0; $i<=@vals; $i++) {
		my ($ip, $mask);
		if ($vals[$i] =~ /^([a-z0-9\.\:]+)\/([\d\.]+)$/) {
			$ip = $1; $mask = $2;
			}
		else { $ip = $mask = ""; }
		$table .= &ui_columns_row([
			&ui_textbox("ip_$i", $ip, 20),
			&ui_textbox("mask_$i", $mask, 20),
			]);
		}
	$table .= &ui_columns_end();
	print &ui_table_row(undef, $table, 2);
	}
elsif ($type eq "srcdomain" || $type eq "dstdomain") {
	# Source or destination domain
	print &ui_table_row($text{'acl_domains'},
		&ui_textarea("vals", join("\n", @vals), 6, 60));
	}
elsif ($type eq "time") {
	# Day or week and time of day
	my $vals = join(' ', @vals);
	my %day;
	if ($vals =~ /[A-Z]+/) {
		foreach my $d (split(//, $vals)) {
			$day{$d}++;
			}
		}
	my ($h1, $h2, $m1, $m2, $hour);
	if ($vals =~ /(\d+):(\d+)-(\d+):(\d+)/) {
		$h1 = $1; $m1 = $2;
		$h2 = $3; $m2 = $4;
		$hour++;
		}
	my @day_name = ( [ 'S', $text{'acl_dsun'} ], 
                         [ 'M', $text{'acl_dmon'} ], 
                         [ 'T', $text{'acl_dtue'} ],
		         [ 'W', $text{'acl_dwed'} ], 
                         [ 'H', $text{'acl_dthu'} ], 
                         [ 'F', $text{'acl_dfri'} ],
		         [ 'A', $text{'acl_dsat'} ] );
	print &ui_table_row($text{'acl_dofw'},
		&ui_radio("day_def", %day ? 0 : 1,
			  [ [ 1, $text{'acl_all'} ],
			    [ 0, $text{'acl_sel'} ] ])."<br>\n".
		&ui_select("day", [ keys %day ], \@day_name,
			   7, 1));

	print &ui_table_row($text{'acl_hofd'},
		&ui_radio("hour_def", $hour ? 0 : 1,
			  [ [ 1, $text{'acl_all'} ],
			    [ 0, &ui_textbox("h1", $h1, 2).":".
				 &ui_textbox("m1", $m1, 2)." $text{'acl_to'} ".
				 &ui_textbox("h2", $h2, 2).":".
				 &ui_textbox("m2", $m2, 2) ] ]));
	}
elsif ($type eq "url_regex" || $type eq "urlpath_regex") {
	# URL regular expression
	my $caseless;
	if ($vals[0] eq '-i') {
		$caseless++;
		shift(@vals);
		}
	print &ui_table_row($text{'acl_regexp'},
		&ui_checkbox("caseless", 1, $text{'acl_case'}, $caseless).
		"<br>\n".
		&ui_textarea("vals", join("\n", @vals), 6, 60));
	}
elsif ($type eq "port") {
	# Request port number
	print &ui_table_row($text{'acl_tcpports'},
		&ui_textbox("vals", join(" ", @vals), 60));
	}
elsif ($type eq "proto") {
	# Request protocol
	my %proto = map { $_, 1 } @vals;
	print &ui_table_row($text{'acl_urlproto'},
		join(" ", map { &ui_checkbox("vals", $_, $_, $proto{$_}) }
		      ('http', 'ftp', 'gopher', 'wais', 'cache_object')));
	}
elsif ($type eq "method") {
	# HTTP method
	my %meth =  map { $_, 1 } @vals;
	print &ui_table_row($text{'acl_reqmethods'},
		join(" ", map { &ui_checkbox("vals", $_, $_, $meth{$_}) }
                      ('GET', 'POST', 'HEAD', 'CONNECT', 'PUT', 'DELETE')));
	}
elsif ($type eq "browser") {
	# Browser user agent
	print &ui_table_row($text{'acl_bregexp'},
		&ui_textbox("vals", join(" ", @vals), 60));
	}
elsif ($type eq "user") {
	# Proxy usernames
	print &ui_table_row($text{'acl_pusers'},
		&ui_textarea("vals", join("\n", @vals), 6, 60));
	}
elsif ($type eq "src_as" || $type eq "dst_as") {
	# Source or destination AS number
	print &ui_table_row($text{'acl_asnum'},
		&ui_textbox("vals", join(" ", @vals), 20));
	}
elsif ($type eq "proxy_auth" && $squid_version < 2.3) {
	# Refresh time
	print &ui_table_row($text{'acl_rtime'},
		&ui_textbox("vals", $vals[0], 8));
	}
elsif ($type eq "proxy_auth" && $squid_version >= 2.3) {
	# Proxy username
	print &ui_table_row($text{'acl_eusers'},
		&ui_radio("authall",
			  $vals[0] eq 'REQUIRED' || $in{'type'} ? 1 : 0,
			  [ [ 1, $text{'acl_eusersall'} ],
			    [ 0, $text{'acl_euserssel'} ] ])."<br>\n".
		&ui_textarea("vals", $vals[0] eq 'REQUIRED' || $in{'type'} ?
					"" : join("\n", @vals), 6, 60));
	}
elsif ($type eq "proxy_auth_regex") {
	# Username regexp
	my $caseless;
	if ($vals[0] eq '-i') {
		$caseless++;
		shift(@vals);
		}
	print &ui_table_row($text{'acl_eusers'},
		&ui_checkbox("caseless", 1, $text{'acl_case'}, $caseless).
		"<br>\n".
		&ui_textarea("vals", join("\n", @vals), 6, 60));
	}
elsif ($type eq "srcdom_regex" || $type eq "dstdom_regex") {
	# Source or destination domain regexp
	my $caseless;
	if ($vals[0] eq '-i') {
		$caseless++;
		shift(@vals);
		}
	print &ui_table_row($text{'acl_regexp'},
		&ui_checkbox("caseless", 1, $text{'acl_case'}, $caseless).
		"<br>\n".
		&ui_textarea("vals", join("\n", @vals), 6, 60));
	}
elsif ($type eq "ident") {
	# IDENT protocol user
	print &ui_table_row($text{'acl_rfcusers'},
		&ui_textarea("vals", join("\n", @vals), 6, 60));
	}
elsif ($type eq "ident_regex") {
	# IDENT protocol username regexp
	my $caseless;
	if ($vals[0] eq '-i') {
		$caseless++;
		shift(@vals);
		}
	print &ui_table_row($text{'acl_rfcusersr'},
		&ui_checkbox("caseless", 1, $text{'acl_case'}, $caseless).
                "<br>\n".
                &ui_textarea("vals", join("\n", @vals), 6, 60));
	}
elsif ($type eq "maxconn") {
	# Max concurrent connections
	print &ui_table_row($text{'acl_mcr'},
		&ui_textbox("vals", $vals[0], 8));
	}
elsif ($type eq "max_user_ip") {
	# Max connections per IP
	my $mipstrict;
	if ($vals[0] eq '-s') {
		$mipstrict++;
		shift(@vals);
		}
	print &ui_table_row($text{'acl_mai'},
		&ui_textbox("vals", $vals[0], 8));
	print &ui_table_row($text{'acl_extargs'},
		&ui_checkbox("strict", 1, $text{'acl_maistrict'}, $mipstrict).
		"<br>\n".
		&ui_textbox("args", join(" ", @vals[1..$#vals]), 60).
		"<br>\n".$text{'acl_mairemind'});
	}
elsif ($type eq "myport") {
	# Local port number
	print &ui_table_row($text{'acl_psp'},
		&ui_textbox("vals", $vals[0], 8));
	}
elsif ($type eq "snmp_community") {
	# SNMP community
	print &ui_table_row($text{'acl_scs'},
		&ui_textbox("vals", $vals[0], 15));
	}
elsif ($type eq "req_mime_type") {
	# Request MIME type
	print &ui_table_row($text{'acl_rmt'},
		&ui_textbox("vals", $vals[0], 15));
	}
elsif ($type eq "rep_mime_type") {
	# Reply MIME type
	print &ui_table_row($text{'acl_rpmt'},
		&ui_textbox("vals", $vals[0], 15));
	}
elsif ($type eq "arp") {
	# Client MAC address
	print &ui_table_row($text{'acl_arp'},
		&ui_textarea("vals", join("\n", @vals), 6, 60));
	}
elsif ($type eq "external") {
	# External program
	print &ui_table_row($text{'acl_extclass'},
		&ui_select("class", $vals[0],
			[ map { $_->{'values'}->[0] }
			      &find_config("external_acl_type", $conf) ]));
	print &ui_table_row($text{'acl_extargs'},
		&ui_textbox("args", join(" ", @vals[1..$#vals]), 60));
	}

# Show URL to redirect on failure
print &ui_table_row($text{'acl_failurl'},
	&ui_textbox("deny", @deny ? $deny[0]->{'values'}->[0] : "", 40));

# Show file in which ACL is stored
print &ui_table_row($text{'acl_file'},
	&ui_opt_textbox("file", $file, 40, $text{'acl_nofile'},
			$text{'acl_infile'})." ".
	&file_chooser_button("file")."<br>\n".
	($in{'type'} ? &ui_checkbox("keep", 1, $text{'acl_keep'}, 0) : ""));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'acl_buttsave'} ],
		     $in{'type'} ? ( ) : ( [ 'delete', $text{'acl_buttdel'} ] ),
		   ]); 

&ui_print_footer("edit_acl.cgi?mode=acls", $text{'acl_return'},
		 "", $text{'index_return'});

