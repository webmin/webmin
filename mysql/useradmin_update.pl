$use_global_login = 1;      # Always login as master user, not the mysql
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

	&create_user({
		'new', 1,
		'user', $user->{'user'},
		'olduser', $user->{'olduser'},
		'pass', $user->{'plainpass'},
		'host', $config{'sync_host'} || '%',
		'perms', \%privs,
		'pfields', \@pfields,
		'ssl_field_names', \@ssl_field_names,
		'ssl_field_values', \@ssl_field_values,
		'other_field_names', \@other_field_names,
		'other_field_values', \@other_field_values,
		});

	# Update user password
	if ($in{'passmode'} == 3 || $in{'passmode'} eq '0') {
		&change_user_password($user->{'plainpass'} || '', $user->{'user'}, $config{'sync_host'});
		}
	# Locked account
	elsif ($in{'passmode'} == 1) {
		&change_user_password(undef, $user->{'user'}, $config{'sync_host'});
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
	my $actual_user = $user->{'olduser'};

	# Rename user if needed
	if ($user->{'user'} && $user->{'olduser'} && $user->{'user'} ne $user->{'olduser'}) {
		&rename_user({
			'user', $user->{'user'},
			'olduser', $user->{'olduser'},
			'host', $config{'sync_host'} || '%',
			'oldhost', $config{'sync_host'} || '%'
			});
		$actual_user = $user->{'user'};
		}

	# Update user password
	if ($in{'passmode'} == 3 || $in{'passmode'} eq '0') {
		&change_user_password($user->{'plainpass'} || '', $actual_user, $config{'sync_host'});
		}
	# Locked account
	elsif ($in{'passmode'} == 1) {
		&change_user_password(undef, $actual_user, $config{'sync_host'});
		}
	}
}

1;

