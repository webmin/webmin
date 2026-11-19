
$use_global_login = 1;          # Always login as master user, not the mysql
                                # login of the current Webmin user
do 'postgresql-lib.pl';

# useradmin_create_user(&details)
# Create a new postgesql user if syncing is enabled
sub useradmin_create_user
{
if ($config{'sync_create'}) {
	local $version = &get_postgresql_version();
	local $sql = "create user \"$_[0]->{'user'}\"";
	if ($_[0]->{'passmode'} == 3) {
		$sql .= " with password '$_[0]->{'plainpass'}'";
		}
	$sql .= " nocreatedb";
	if (&get_postgresql_version() < 9.5) {
		$sql .= " nocreateuser";
		}
	&execute_sql_logged($config{'basedb'}, $sql);
	}
}

# useradmin_delete_user(&details)
# Delete a mysql user
sub useradmin_delete_user
{
if ($config{'sync_delete'}) {
	my ($pg_table, $pg_cols) = &get_pg_shadow_table();
	local $s = &execute_sql($config{'basedb'},
		"select $pg_cols from $pg_table where usename = '$_[0]->{'user'}'");
	return if (!@{$s->{'data'}});
	&execute_sql_logged($config{'basedb'}, "drop user \"$_[0]->{'user'}\"");
	}
}

# useradmin_modify_user(&details)
# Update a mysql user
sub useradmin_modify_user
{
if ($config{'sync_modify'}) {
	my ($pg_table, $pg_cols) = &get_pg_shadow_table();
	local $s = &execute_sql($config{'basedb'},
		"select $pg_cols from $pg_table where usename = '$_[0]->{'olduser'}'");
	return if (!@{$s->{'data'}});
	local $version = &get_postgresql_version();
	if ($_[0]->{'user'} ne $_[0]->{'olduser'}) {
		# Need to delete and re-create to rename :(
		local @user = @{$s->{'data'}->[0]};
		&execute_sql_logged($config{'basedb'},
				    "drop user \"$_[0]->{'olduser'}\"");
		local $sql = "create user \"$_[0]->{'user'}\"";
		if ($_[0]->{'passmode'} == 3) {
			$sql .= " with password '$_[0]->{'plainpass'}'";
			}
		elsif ($_[0]->{'passmode'} == 4) {
			$sql .= " with password '$user[6]'";
			}
		&execute_sql_logged($config{'basedb'}, $sql);
		}
	elsif ($_[0]->{'passmode'} != 4) {
		# Just change password
		local $sql = "alter user \"$_[0]->{'user'}\"";
		if ($_[0]->{'passmode'} == 3) {
			$sql .= " with password '$_[0]->{'plainpass'}'";
			}
		&execute_sql_logged($config{'basedb'}, $sql);
		}
	}
}

1;

