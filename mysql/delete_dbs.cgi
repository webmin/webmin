#!/usr/local/bin/perl
# Delete several selected database permissions

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_ecannot'});
&error_setup($text{'dbs_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($trext{'dbs_enone'});

if (!$in{'confirm'}) {
	# Ask first
	&ui_print_header(undef, $text{'dbs_dtitle'}, "");

	print &ui_confirmation_form("delete_dbs.cgi",
		&text('dbs_drusure', scalar(@d)),
		[ map { [ "d", $_ ] } @d ],
		[ [ "confirm", $text{'dbs_dok'} ] ],
		);

	&ui_print_footer('list_dbs.cgi', $text{'dbs_return'},
			 "", $text{'index_return'});
	}
else {
	# Delete the database permissions
	foreach $hdu (@d) {
		($host, $db, $user) = split(/ /, $hdu);
		$access{'perms'} == 1 || &can_edit_db($db) ||
			&error($text{'perms_edb'});
		&execute_sql_logged($master_db,
			     "delete from db where user = '$user' ".
			     "and host = '$host' ".
			     "and db = '$db'");
		}
	&execute_sql_logged($master_db, 'flush privileges');

	# Log it
	&webmin_log("delete", "dbprivs", scalar(@d));
	&redirect("list_dbs.cgi");
	}

