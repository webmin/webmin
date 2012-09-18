#!/usr/local/bin/perl
# Remove one or more active connections

use strict;
use warnings;
require './iscsi-client-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'dconns_err'});

# Get the connections
my $conns = &list_iscsi_connections();
ref($conns) || &error(&text('conns_elist', $conns));
my @d = split(/\0/, $in{'d'});
my @delconns;
foreach my $d (@d) {
	my ($conn) = grep { $_->{'num'} eq $d } @$conns;
	push(@delconns, $conn) if ($conn);
	}
@delconns || &error($text{'dconns_enone'});

if (!$in{'confirm'}) {
	&ui_print_header(undef, $text{'dconns_title'}, "");

	# Find users of each device
	my @users;
	foreach my $conn (@delconns) {
		push(@users, &get_connection_users($conn));
		}

	# Build table of users
	my $utable = "";
	if (@users) {
		$utable = $text{'dconns_users'}."<p>\n";
		$utable .= &ui_columns_start([
			$text{'conns_ip'},
			$text{'conns_target'},
			$text{'dconns_part'},
			$text{'dconns_use'} ]);
		foreach my $u (@users) {
			$utable .= &ui_columns_row([
				$u->[0]->{'ip'},
				$u->[0]->{'target'},
				&mount::device_name($u->[1]->{'device'}),
				&lvm::device_message($u->[2], $u->[3], $u->[4]),
				], "50");
			}
		$utable .= &ui_columns_end();
		}

	# Ask the user if he is sure
	print &ui_confirmation_form(
		"delete_conns.cgi",
		@delconns == 1 && $delconns[0]->{'device'} ?
			&text('dconns_rusure2',
			      "<tt>".$delconns[0]->{'ip'}."</tt>",
			      "<tt>".$delconns[0]->{'device'}."</tt>") :
		@delconns == 1 ?
			&text('dconns_rusure1',
			      "<tt>".$delconns[0]->{'ip'}."</tt>") :
			&text('dconns_rusure', scalar(@delconns)),
		[ map { [ "d", $_ ] } @d ],
		[ [ "confirm", $text{'dconns_confirm'} ] ],
		$utable);

	&ui_print_footer("list_conns.cgi", $text{'conns_return'});
	}
else {
	# Delete each one
	foreach my $conn (@delconns) {
		my $err = &delete_iscsi_connection($conn);
		&error(&text('dconns_edelete', $conn->{'ip'},
			     $conn->{'target'}, $err)) if ($err);
		}

	if (@delconns == 1) {
		&webmin_log("delete", "connection", $delconns[0]->{'ip'},
			    { 'host' => $delconns[0]->{'ip'},
			      'port' => $delconns[0]->{'port'},
			      'target' => $delconns[0]->{'target'} });
		}
	else {
		&webmin_log("delete", "connections", scalar(@delconns));
		}
	&redirect("list_conns.cgi");
	}
