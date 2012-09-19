#!/usr/local/bin/perl
# Remove one or more interfaces

use strict;
use warnings;
require './iscsi-client-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'difaces_err'});

# Get the interfaces
my $ifaces = &list_iscsi_ifaces();
ref($ifaces) || &error(&text('ifaces_elist', $ifaces));
my @d = split(/\0/, $in{'d'});
my @delifaces;
foreach my $d (@d) {
	my ($iface) = grep { $_->{'name'} eq $d } @$ifaces;
	push(@delifaces, $iface) if ($iface);
	}
@delifaces || &error($text{'difaces_enone'});

if (!$in{'confirm'}) {
	&ui_print_header(undef, $text{'difaces_title'}, "");

	# Find interface users
	my @users;
	foreach my $iface (@delifaces) {
		foreach my $target (@{$iface->{'targets'}}) {
			$target->{'iface'} = $iface->{'name'};
			push(@users, $target);
			}
		}

	# Build list of users
	my $utable = "";
	if (@users) {
		$utable = $text{'difaces_users'}."<p>\n";
		$utable .= &ui_columns_start([
			$text{'ifaces_name'},
			$text{'difaces_ip'},
			$text{'difaces_target'},
			], 50);
		foreach my $u (@users) {
                        $utable .= &ui_columns_row([
				$u->{'iface'},
				$u->{'ip'},
				$u->{'target'},
				]);
			}
		$utable .= &ui_columns_end();
		}

	# Ask the user if he is sure
	print &ui_confirmation_form(
		"delete_ifaces.cgi",
		@delifaces == 1 ?
			&text('difaces_rusure1',
			      "<tt>".$delifaces[0]->{'name'}."</tt>") :
			&text('difaces_rusure', scalar(@delifaces)),
		[ map { [ "d", $_ ] } @d ],
		[ [ "confirm", $text{'difaces_confirm'} ] ],
		$utable);

	&ui_print_footer("list_ifaces.cgi", $text{'ifaces_return'});
	}
else {
	# Delete each one
	foreach my $iface (@delifaces) {
		my $err = &delete_iscsi_iface($iface);
		&error(&text('difaces_edelete', $iface->{'name'}, $err))
			if ($err);
		}

	if (@delifaces == 1) {
		&webmin_log("delete", "iface", $delifaces[0]->{'name'},
			    $delifaces[0]);
		}
	else {
		&webmin_log("delete", "ifaces", scalar(@delifaces));
		}
	&redirect("list_ifaces.cgi");
	}
