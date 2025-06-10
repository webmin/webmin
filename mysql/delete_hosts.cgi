#!/usr/local/bin/perl
# Delete several selected host permissions

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_edb'});
&error_setup($text{'hosts_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($trext{'hosts_enone'});

if (!$in{'confirm'}) {
	# Ask first
	&ui_print_header(undef, $text{'hosts_dtitle'}, "");

	print &ui_confirmation_form("delete_hosts.cgi",
		&text('hosts_drusure', scalar(@d)),
		[ map { [ "d", $_ ] } @d ],
		[ [ "confirm", $text{'hosts_dok'} ] ],
		);

	&ui_print_footer('list_hosts.cgi', $text{'hosts_return'},
			 "", $text{'index_return'});
	}
else {
	# Delete the users
	foreach $hdu (@d) {
		($host, $db) = split(/ /, $hdu);
		$access{'perms'} == 1 || &can_edit_db($db) ||
			&error($text{'perms_edb'});
		&execute_sql_logged($master_db,
			     "delete from host where host = '$host' ".
			     "and db = '$db'");
		}
	&execute_sql_logged($master_db, 'flush privileges');

	# Log it
	&webmin_log("delete", "hosts", scalar(@d));
	&redirect("list_hosts.cgi");
	}

