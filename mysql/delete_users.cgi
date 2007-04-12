#!/usr/local/bin/perl
# Delete several selected users

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} == 1 || &error($text{'perms_ecannot'});
&error_setup($text{'users_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($trext{'users_enone'});

# Delete the users
foreach $hu (@d) {
	($host, $user) = split(/ /, $hu);
	&execute_sql_logged($master_db,
		     "delete from user where user = '$user' ".
		     "and host = '$host'");
	}
&execute_sql_logged($master_db, 'flush privileges');

# Log it
&webmin_log("delete", "users", scalar(@d));
&redirect("list_users.cgi");

