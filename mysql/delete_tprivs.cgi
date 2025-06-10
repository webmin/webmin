#!/usr/local/bin/perl
# Delete several selected table permissions

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_edb'});
&error_setup($text{'tprivs_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($trext{'tprivs_enone'});

if (!$in{'confirm'}) {
	# Ask first
	&ui_print_header(undef, $text{'tprivs_dtitle'}, "");

	print &ui_confirmation_form("delete_tprivs.cgi",
		&text('tprivs_drusure', scalar(@d)),
		[ map { [ "d", $_ ] } @d ],
		[ [ "confirm", $text{'tprivs_dok'} ] ],
		);

	&ui_print_footer('list_tprivs.cgi', $text{'tprivs_return'},
			 "", $text{'index_return'});
	}
else {
	# Delete the table privs
	foreach $hdut (@d) {
		($host, $db, $user, $table) = split(/ /, $hdut);
		$access{'perms'} == 1 || &can_edit_db($db) ||
			&error($text{'perms_edb'});
		&execute_sql_logged($master_db,
			     "delete from tables_priv where host = '$host' ".
			     "and db = '$db' ".
			     "and user = '$user' ".
			     "and table_name = '$table'");
		}
	&execute_sql_logged($master_db, 'flush privileges');

	# Log it
	&webmin_log("delete", "tprivs", scalar(@d));
	&redirect("list_tprivs.cgi");
	}

