#!/usr/local/bin/perl
# Update the password for root, both in MySQL and Webmin

require './mysql-lib.pl';
&ReadParse();
&error_setup($text{'root_err'});
$access{'perms'} == 1 || &error($text{'perms_ecannot'});

# Validate inputs
$in{'newpass1'} || &error($text{'root_epass1'});
$in{'newpass1'} eq $in{'newpass2'} || &error($text{'root_epass2'});

# Update MySQL
$esc = &escapestr($in{'newpass1'});
$user = $mysql_login || "root";
&execute_sql_logged($master_db,
    "update user set password = $password_func('$esc') ".
    "where user = '$user'");
&execute_sql_logged($master_db, 'flush privileges');

# Update webmin
$config{'pass'} = $in{'newpass1'};
&lock_file($module_config_file);
&save_module_config();
&unlock_file($module_config_file);

&webmin_log("root");
&redirect("");
