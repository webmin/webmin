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
	$oldhost = $host;
	$oldhost = $in{'oldhost'}
		if ($in{'oldhost'});
	$user = $in{'mysqluser_def'} ? '' : $in{'mysqluser'};
	$olduser = defined($in{'olduser'}) ? $in{'olduser'} : $user;
	@pfields = map { $_->[0] } &priv_fields('user');
	my @ssl_field_names = &ssl_fields();
	my @ssl_field_values = map { '' } @ssl_field_names;
	my @other_field_names = &other_user_fields();
	my @other_field_values = map { '' } @other_field_names;
	my ($ver, $variant) = &get_remote_mysql_variant();
	my $plugin = &get_mysql_plugin(1);

	if ($in{'new'}) {
		# Create a new user
		&create_user({
			'user', $olduser,
			'pass', $in{'mysqlpass'},
			'host', $host,
			'perms', \%perms,
			'pfields', \@pfields,
			'plugin', $in{'plugin'},
			'ssl_field_names', \@ssl_field_names,
			'ssl_field_values', \@ssl_field_values,
			'other_field_names', \@other_field_names,
			'other_field_values', \@other_field_values,
			});
		}
	else {
		# Rename user and/or host, if requested
		my $changing_user = ($user ne $olduser);
		my $changing_host = ($host ne $oldhost);
		if ($changing_user ||
			$changing_host) {
			&rename_user({
				'user', $user,
				'olduser', $olduser,
				'host', $host,
				'oldhost', $oldhost,
				});
			$olduser = $user if ($changing_user);
			$oldhost = $host if ($changing_host);
			}
		
		# Update user password, if requested
		if ($in{'mysqlpass_mode'} == 4) {
			# Never used for admin accounts
			&change_user_password(undef, $olduser, $oldhost,
					      $in{'plugin'});
			}
		elsif ($in{'mysqlpass_mode'} == 1 &&
		       $in{'plugin'} eq "unix_socket") {
			&change_user_password('', $olduser, $oldhost,
					      $in{'plugin'});
			}
		elsif ($in{'mysqlpass_mode'} != 1) {
			($in{'mysqlpass_mode'} eq '0' && !$in{'mysqlpass'}) && &error($text{'root_epass1'});
			my $pass = $in{'mysqlpass'} || '';
			&change_user_password($pass, $olduser, $oldhost,
					      $in{'plugin'});
			}

		&update_privileges({
			'user', $olduser,
			'host', $oldhost,
			'perms', \%perms,
			'pfields', \@pfields
			});
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
					"alter user '$olduser'\@'$oldhost' with $f_tbl_diff "
					.($in{$f.'_def'} ? 0 : $in{$f})."");
			}
		else {
			&execute_sql_logged($master_db,
				"update user set $f = ? ".
				"where user = ? and host = ?",
				$in{$f.'_def'} ? 0 : $in{$f}, $olduser, $oldhost);
			}

		}

	# Set SSL fields
	if ($variant eq "mariadb" && &compare_version_numbers($ver, "10.4") >= 0) {
		if ($in{'ssl_type'} =~ /^(NONE|SSL|X509)$/) {
			&execute_sql_logged($mysql::master_db,
				"alter user '$olduser'\@'$oldhost' require $in{'ssl_type'}");
			}
		}
	else {
		if (&compare_version_numbers($ver, 5) >= 0 &&
		    defined($in{'ssl_type'}) &&
		    (!$in{'new'} || $in{'ssl_type'} || $in{'ssl_cipher'})) {
			&execute_sql_logged($master_db,
				"update user set ssl_type = ? ".
				"where user = ? and host = ?",
				$in{'ssl_type'}, $olduser, $oldhost);
			&execute_sql_logged($master_db,
				"update user set ssl_cipher = ? ".
				"where user = ? and host = ?",
				$in{'ssl_cipher'}, $olduser, $oldhost);
			}
		}
	}
&execute_sql_logged($master_db, 'flush privileges');

# Log actions
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

