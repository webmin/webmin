
$use_global_login = 1;		# Always login as master user, not the mysql
				# login of the current Webmin user
do 'mysql-lib.pl';

# useradmin_create_user(&details)
# Create a new mysql user if syncing is enabled
sub useradmin_create_user
{
my ($user) = @_;
if ($config{'sync_create'}) {
	my %privs = map { $_, 1 } split(/\s+/, $config{'sync_privs'});
        my @pfields = map { $_->[0] } &priv_fields('user');
	my @ssl_field_names = &ssl_fields();
	my @ssl_field_values = map { '' } @ssl_field_names;
	my @other_field_names = &other_user_fields();
	my @other_field_values = map { '' } @other_field_names;
	my $sql = "insert into user (host, user, ".
		  join(", ", @pfields, @ssl_field_names,
			     @other_field_names).
		  ") values (?, ?, ".
		  join(", ", map { "?" } (@pfields, @ssl_field_names,
					  @other_field_names)).")";
	&execute_sql_logged($master_db, $sql,
		$config{'sync_host'},
		$user->{'user'},
		(map { $privs{$_} ? 'Y' : 'N' } @pfields),
		@ssl_field_values,
		@other_field_values);
	&execute_sql_logged($master_db, 'flush privileges');
	if ($user->{'passmode'} == 3) {
		$esc = &escapestr($user->{'plainpass'});
		&execute_sql_logged($master_db,
			"set password for '".$user->{'user'}."'\@'".
			$config{'sync_host'}."' = ".
			"$password_func('$esc')");
		}
	}
}

# useradmin_delete_user(&details)
# Delete a mysql user
sub useradmin_delete_user
{
my ($user) = @_;
if ($config{'sync_delete'}) {
	&execute_sql_logged($master_db,
		"delete from user where user = ?", $user->{'user'});
	&execute_sql_logged($master_db,
		"delete from db where user = ?", $user->{'user'});
	&execute_sql_logged($master_db,
		"delete from tables_priv where user = ?", $user->{'user'});
	&execute_sql_logged($master_db,
		"delete from columns_priv where user = ?", $user->{'user'});
	&execute_sql_logged($master_db, 'flush privileges');
	}
}

# useradmin_modify_user(&details)
# Update a mysql user
sub useradmin_modify_user
{
my ($user) = @_;
if ($config{'sync_modify'}) {
	$user->{'olduser'} ||= $user->{'user'};	# In case not changed

	# Rename user if needed
	if ($user->{'user'} ne $user->{'olduser'}) {
		&execute_sql_logged($master_db,
			"update db set user = '$user->{'user'}' ".
			"where user = '$user->{'olduser'}'");
		&execute_sql_logged($master_db,
			"update tables_priv set user = '$user->{'user'}' ".
			"where user = '$user->{'olduser'}'");
		&execute_sql_logged($master_db,
			"update columns_priv set user = '$user->{'user'}' ".
			"where user = '$user->{'olduser'}'");
		}
	&execute_sql_logged($master_db, 'flush privileges');

	# Update password if changed
	if ($user->{'passmode'} == 3) {
		my $d = &execute_sql_safe($master_db,
		    "select host from user where user = ?", $user->{'user'});
		my @hosts = map { $_->[0] } @{$d->{'data'}};
		my $esc = &escapestr($user->{'plainpass'});
		foreach my $host (@hosts) {
			$sql = "set password for '".$user->{'user'}.
			       "'\@'".$host."' = $password_func('$esc')";
			&execute_sql_logged($master_db, $sql);
			}
		}
	}
}

1;

