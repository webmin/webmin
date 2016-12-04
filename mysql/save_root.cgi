#!/usr/local/bin/perl
# Update the password for root, both in MySQL and Webmin

require './mysql-lib.pl';
&ReadParse();
&error_setup($text{'root_err'});
$access{'perms'} == 1 || &error($text{'perms_ecannot'});

# Validate inputs
$in{'newpass1'} || &error($text{'root_epass1'});
$in{'newpass1'} eq $in{'newpass2'} || &error($text{'root_epass2'});
$in{'newpass1'} =~ /\\/ && &error($text{'user_eslash'});

# Update MySQL
$esc = &escapestr($in{'newpass1'});
$user = $mysql_login || "root";
$d = &execute_sql_safe($master_db,
	"select host from user where user = ?", $user);
@hosts = map { $_->[0] } @{$d->{'data'}};
foreach my $host (@hosts) {
	$sql = "set password for '".$user."'\@'".$host."' = ".
	       "$password_func('$esc')";
	eval {
		local $main::error_must_die = 1;
		&execute_sql_logged($master_db, $sql);
		};
	if ($@) {
		# Try again with the new password
		local $config{'pass'} = $in{'newpass1'};
		&execute_sql_logged($master_db, $sql);
		}
	}

# Update webmin
$config{'pass'} = $in{'newpass1'};
&lock_file($module_config_file);
&save_module_config();
&unlock_file($module_config_file);

&webmin_log("root");
&redirect("");
