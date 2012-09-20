#!/usr/local/bin/perl
# Show details of one connection

use strict;
use warnings;
require './iscsi-client-lib.pl';
our (%text, %in);
&ReadParse();

# Get the connection
my $conns = &list_iscsi_connections();
ref($conns) || &error(&text('conns_elist', $conns));
my ($conn) = grep { $_->{'num'} eq $in{'num'} } @$conns;
$conn || &error($text{'vconn_egone'});

&ui_print_header(undef, $text{'vconn_title'}, "");

print &ui_form_start("delete_conns.cgi");
print &ui_hidden("d", $in{'num'});
print &ui_table_start($text{'vconn_header'}, undef, 2);

print &ui_table_row($text{'conns_ip'}, $conn->{'ip'});

print &ui_table_row($text{'conns_sport'}, $conn->{'port'});

print &ui_table_row($text{'conns_name'}, $conn->{'name'});

print &ui_table_row($text{'conns_target'}, $conn->{'target'});

print &ui_table_row($text{'vconn_proto'}, uc($conn->{'proto'}));

print &ui_table_row($text{'vconn_init'}, $conn->{'initiator'});

print &ui_table_row($text{'vconn_connection'}, $conn->{'connection'});

print &ui_table_row($text{'vconn_session'}, $conn->{'session'});

print &ui_table_hr();

foreach my $f ("username", "password", "username_in", "password_in") {
	print &ui_table_row($text{'vconn_'.$f},
		$conn->{$f} || "<i>$text{'vconn_none'}</i>");
	}

if ($conn->{'device'}) {
	print &ui_table_hr();

	print &ui_table_row($text{'vconn_device'},
		"<a href='../fdisk/edit_disk.cgi?device=$conn->{'device'}'>".
		"$conn->{'device'}</a>");

	print &ui_table_row($text{'vconn_device2'},
		&mount::device_name($conn->{'device'}));

	my @disks = &fdisk::list_disks_partitions();
	my ($disk) = grep { $_->{'device'} eq $conn->{'device'} } @disks;
	if ($disk) {
		print &ui_table_row($text{'vconn_size'},
			&nice_size($disk->{'size'}));
		}

	my @users = &get_connection_users($conn);
	if (@users) {
		my $utable = &ui_columns_start([
			$text{'dconns_part'},
			$text{'dconns_size'},
			$text{'dconns_use'},
			], undef, 0, [ "", "nowrap", "" ]);
		foreach my $u (@users) {
			$utable .= &ui_columns_row([
				&mount::device_name($u->[1]->{'device'}),
				&nice_size($u->[1]->{'size'}),
				&lvm::device_message($u->[2], $u->[3], $u->[4]),
				], "50");
			}
		$utable .= &ui_columns_end();
		print &ui_table_row($text{'vconn_users'}, $utable);
		}
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'vconn_delete'} ] ]);

&ui_print_footer("list_conns.cgi", $text{'conns_return'});
