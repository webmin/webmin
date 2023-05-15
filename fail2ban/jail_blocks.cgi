#!/usr/local/bin/perl
# Show a status of all active jails

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%in, %text, %config);

&ReadParse();

my $jail = $in{'jail'};
my $out = &backquote_logged("$config{'client_cmd'} status 2>&1 </dev/null");
my ($jail_list) = $out =~ /jail\s+list:\s*(.*)/im;
my @jails = split(/,\s*/, $jail_list);
&indexof($jail, @jails) > -1 || error($text{'status_err_unknownjail'});

&ui_print_header("$jail", $text{'status_title3'}, "");
my $fh = 'jailinfo';
my @jail_blocks;
&open_execute_command($fh, "$config{'client_cmd'} get @{[quotemeta($jail)]} banip --with-time 2>&1 </dev/null", 1);
while(<$fh>) {
	if (/^(?<ip>.*?)\s+(?<start>.*?\s+.*?)\s+.*?\s+.*?\s+=\s+(?<end>.*)$/) {
		my $ip = $+{ip};
		my $start = $+{start};
		my $end = $+{end};
		if ($ip && $start && $end) {
			push(@jail_blocks, [$ip, $start, $end]);
			}
		}
	}
close($fh);

if (@jail_blocks) {
	my $popts = \%in;
	$popts->{'paginations'}->{'form'} = { 'jail' => $jail };
	my $pagination = &ui_paginations(\@jail_blocks, $popts);
	my @links = ( &select_all_link("ip"),
	              &select_invert_link("ip"));
	print $pagination->{'search'}->{'form-data'};
	print &ui_form_start("unblock_jailed_ip.cgi", "post");
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'status_head_blocks_ip'},
				  $text{'status_head_blocks_stime'},
				  $text{'status_head_blocks_etime'} ]);
	if (@jail_blocks) {
		foreach my $r (@jail_blocks) {
			print &ui_checked_columns_row($r, [ 'width=5' ], "ip", $r->[0]);
			}
		}
	else {
		print $pagination->{'search'}->{'no-results'};
		}
	print &ui_columns_end();
	print $pagination->{'paginator'}->{'form-data'};
	print $pagination->{'paginator'}->{'form-scripts'};
	print &ui_hidden("jail", $jail);
	print &ui_hidden("return", 1);
	print $pagination->{'form'};
	print &ui_links_row(\@links);
	print &ui_form_end([ [ undef, $text{'status_jail_unblock_ips'} ] ]);
	print $pagination->{'search'}->{'form'};
	print $pagination->{'paginator'}->{'form'};
	}
else {
	print &text('status_jail_noactiveips', $jail);
	}

&ui_print_footer("list_status.cgi", $text{'status_return'},
                 "", $text{'index_return'});
