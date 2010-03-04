
$use_global_login = 1;		# Always login as master user, not the mysql
				# login of the current Webmin user
do 'mysql-lib.pl';

# useradmin_create_user(&details)
# Create a new mysql user if syncing is enabled
sub useradmin_create_user
{
if ($config{'sync_create'}) {
	local %privs;
	map { $privs{$_}++ } split(/\s+/, $config{'sync_privs'});
	local @yesno;
	for($i=3; $i<=&user_priv_cols()+3-1; $i++) {
		push(@yesno, $privs{$i} ? "'Y'" : "'N'");
		}
	local @desc = &table_structure($master_db, 'user');
	local $sql = sprintf "insert into user (%s) values ('%s', '%s', %s, %s)",
		join(",", map { $desc[$_]->{'field'} } (0 .. &user_priv_cols()+3-1)),
		$config{'sync_host'},
		$_[0]->{'user'},
		$_[0]->{'passmode'} == 3 ? "$password_func('$_[0]->{'plainpass'}')" :
		$_[0]->{'passmode'} == 0 ? "''" : "'*'",
		join(",", @yesno);
	&execute_sql_logged($master_db, $sql);
	&execute_sql_logged($master_db, 'flush privileges');
	}
}

# useradmin_delete_user(&details)
# Delete a mysql user
sub useradmin_delete_user
{
if ($config{'sync_delete'}) {
	&execute_sql_logged($master_db,
		    "delete from user where user = '$_[0]->{'user'}'");
	&execute_sql_logged($master_db,
		    "delete from db where user = '$_[0]->{'user'}'");
	&execute_sql_logged($master_db,
		    "delete from tables_priv where user = '$_[0]->{'user'}'");
	&execute_sql_logged($master_db,
		    "delete from columns_priv where user = '$_[0]->{'user'}'");
	&execute_sql_logged($master_db, 'flush privileges');
	}
}

# useradmin_modify_user(&details)
# Update a mysql user
sub useradmin_modify_user
{
if ($config{'sync_modify'}) {
	local $sql;
	$_[0]->{'olduser'} ||= $_[0]->{'user'};	# In case not changed
	if ($_[0]->{'passmode'} == 4) {
		# Not changing password
		$sql = sprintf "update user set user = '%s' where user = '%s'", $_[0]->{'user'}, $_[0]->{'olduser'};
		}
	elsif ($_[0]->{'passmode'} == 3) {
		# Setting new password
		$sql = sprintf "update user set user = '%s', password = $password_func('%s') where user = '%s'", $_[0]->{'user'}, $_[0]->{'plainpass'}, $_[0]->{'olduser'};
		}
	elsif ($_[0]->{'passmode'} == 0) {
		# No password
		$sql = sprintf "update user set user = '%s', password = '' where user = '%s'", $_[0]->{'user'}, $_[0]->{'olduser'};
		}
	else {
		# Assume locked
		$sql = sprintf "update user set user = '%s', password = '*' where user = '%s'", $_[0]->{'user'}, $_[0]->{'olduser'};
		}
	&execute_sql_logged($master_db, $sql);
	if ($_[0]->{'user'} ne $_[0]->{'olduser'}) {
		&execute_sql_logged($master_db,
			"update db set user = '$_[0]->{'user'}' ".
			"where user = '$_[0]->{'olduser'}'");
		&execute_sql_logged($master_db,
			"update tables_priv set user = '$_[0]->{'user'}' ".
			"where user = '$_[0]->{'olduser'}'");
		&execute_sql_logged($master_db,
			"update columns_priv set user = '$_[0]->{'user'}' ".
			"where user = '$_[0]->{'olduser'}'");
		}
	&execute_sql_logged($master_db, 'flush privileges');
	}
}

1;

