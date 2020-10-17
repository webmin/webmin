#!/usr/local/bin/perl
# save_user.cgi
# Save, create or delete a user

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} == 1 || &error($text{'perms_ecannot'});

if ($in{'delete'}) {
	# Delete some user
	&execute_sql_logged($master_db,
		     "delete from user where user = '$in{'olduser'}' ".
		     "and host = '$in{'oldhost'}'");
	}
else {
	# Validate inputs
	&error_setup($text{'user_err'});
	$in{'mysqluser_def'} || $in{'mysqluser'} =~ /^\S+$/ ||
		&error($text{'user_euser'});
	$in{'host_def'} || $in{'host'} =~ /^\S+$/ ||
		&error($text{'user_ehost'});
	if ($in{'mysqlpass_mode'} eq '0' && $in{'mysqlpas'} =~ /\\/) {
		&error($text{'user_eslash'});
		}

	%perms = map { $_, 1 } split(/\0/, $in{'perms'});
	@desc = &table_structure($master_db, 'user');
	%fieldmap = map { lc($_->{'field'}), $_->{'index'} } @desc;
	$host = $in{'host_def'} ? '%' : $in{'host'};
	$user = $in{'mysqluser_def'} ? '' : $in{'mysqluser'};
	@pfields = map { $_->[0] } &priv_fields('user');
	my @ssl_field_names = &ssl_fields();
	my @ssl_field_values = map { '' } @ssl_field_names;
	my @other_field_names = &other_user_fields();
	my @other_field_values = map { '' } @other_field_names;
	my ($ver, $variant) = &get_remote_mysql_variant();
	my $plugin = &get_mysql_plugin(1);

	# Rename user if needed
	if ($user && $in{'olduser'} && $user ne $in{'olduser'}) {
		&rename_user({
			'user', $user,
			'olduser', $in{'olduser'},
			'host', $host,
			'oldhost', $host,
			});
		}

	# Create a new user
	if ($in{'new'}) {
		&create_user({
			'user', $user,
			'pass', $in{'mysqlpass'},
			'host', $host,
			'perms', \%perms,
			'pfields', \@pfields,
			'ssl_field_names', \@ssl_field_names,
			'ssl_field_values', \@ssl_field_values,
			'other_field_names', \@other_field_names,
			'other_field_values', \@other_field_values,
			});
		}
	# Update existing user's privileges
	else {
		&update_privileges({
			'user', $user,
			'host', $host,
			'perms', \%perms,
			'pfields', \@pfields
			});
		}

	# Update user password
	if ($in{'mysqlpass_mode'} == 4) {
		&change_user_password(undef, $user, $host)
		}
	elsif ($in{'mysqlpass_mode'} != 1) {
		&change_user_password(($in{'mysqlpass_mode'} eq '0' ? $in{'mysqlpass'} : ''), $user, $host)
		}
	
	# Save various limits
	my %mdb104_diff = ('max_connections', 'max_connections_per_hour',
                       'max_questions', 'max_queries_per_hour',
                       'max_updates', 'max_updates_per_hour');
	foreach $f ('max_user_connections', 'max_connections',
		    'max_questions', 'max_updates') {
		next if (&compare_version_numbers($ver, 5) < 0 ||
			 !defined($in{$f.'_def'}));
		$in{$f.'_def'} || $in{$f} =~ /^\d+$/ ||
		       &error($text{'user_e'.$f});
		if ($variant eq "mariadb" && &compare_version_numbers($ver, "10.4") >= 0) {
			my $f_tbl_diff = $mdb104_diff{$f} || $f;
			&execute_sql_logged($mysql::master_db,
					"alter user '$user'\@'$host' with $f_tbl_diff "
					.($in{$f.'_def'} ? 0 : $in{$f})."");
			}
		else {
			&execute_sql_logged($master_db,
				"update user set $f = ? ".
				"where user = ? and host = ?",
				$in{$f.'_def'} ? 0 : $in{$f}, $user, $host);
			}

		}

	# Set SSL fields
	if ($variant eq "mariadb" && &compare_version_numbers($ver, "10.4") >= 0) {
		if ($in{'ssl_type'} =~ /^(NONE|SSL|X509)$/) {
			&execute_sql_logged($mysql::master_db,
				"alter user '$user'\@'$host' require $in{'ssl_type'}");
			}
		}
	else {
		if (&compare_version_numbers($ver, 5) >= 0 &&
		    defined($in{'ssl_type'}) &&
		    (!$in{'new'} || $in{'ssl_type'} || $in{'ssl_cipher'})) {
			&execute_sql_logged($master_db,
				"update user set ssl_type = ? ".
				"where user = ? and host = ?",
				$in{'ssl_type'}, $user, $host);
			&execute_sql_logged($master_db,
				"update user set ssl_cipher = ? ".
				"where user = ? and host = ?",
				$in{'ssl_cipher'}, $user, $host);
			}
		}
	}
&execute_sql_logged($master_db, 'flush privileges');
if (!$in{'delete'} && !$in{'new'} &&
    $in{'olduser'} eq $config{'login'} && !$access{'user'}) {
	# Renamed or changed the password for the Webmin login .. update
	# it too!
	$config{'login'} = $in{'mysqluser'};
	if ($in{'mysqlpass_mode'} eq '0') {
		$config{'pass'} = $in{'mysqlpass'};
		}
	elsif ($in{'mysqlpass_mode'} == 2) {
		$config{'pass'} = undef;
		}
	&lock_file($module_config_file);
	&save_module_config();
	&unlock_file($module_config_file);
	}
if ($in{'delete'}) {
	&webmin_log("delete", "user", $in{'olduser'},
		    { 'user' => $in{'olduser'},
		      'host' => $in{'oldhost'} } );
	}
elsif ($in{'new'}) {
	&webmin_log("create", "user",
		    $in{'mysqluser_def'} ? '' : $in{'mysqluser'},
		    { 'user' => $in{'mysqluser_def'} ? '' : $in{'mysqluser'},
		      'host' => $in{'host_def'} ? '' : $in{'host'} } );
	}
else {
	&webmin_log("modify", "user",
		    $in{'mysqluser_def'} ? '' : $in{'mysqluser'},
		    { 'user' => $in{'mysqluser_def'} ? '' : $in{'mysqluser'},
		      'host' => $in{'host_def'} ? '' : $in{'host'} } );
	}
&redirect("list_users.cgi");

