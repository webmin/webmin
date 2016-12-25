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
	if ($in{'mysqlpass_mode'} == 0 && $in{'mysqlpas'} =~ /\\/) {
		&error($text{'user_eslash'});
		}

	%perms = map { $_, 1 } split(/\0/, $in{'perms'});
	@desc = &table_structure($master_db, 'user');
	%fieldmap = map { $_->{'field'}, $_->{'index'} } @desc;
	$host = $in{'host_def'} ? '%' : $in{'host'};
	$user = $in{'mysqluser_def'} ? '' : $in{'mysqluser'};
	@pfields = map { $_->[0] } &priv_fields('user');
	my @ssl_field_names = &ssl_fields();
	my @ssl_field_values = map { '' } @ssl_field_names;
	my @other_field_names = &other_user_fields();
	my @other_field_values = map { '' } @other_field_names;
	if ($in{'new'}) {
		# Create a new user
		$sql = "insert into user (host, user, ".
		       join(", ", @pfields, @ssl_field_names,
				  @other_field_names).
		       ") values (?, ?, ".
		       join(", ", map { "?" } (@pfields, @ssl_field_names,
					       @other_field_names)).")";
		&execute_sql_logged($master_db, $sql,
			$host, $user,
			(map { $perms{$_} ? 'Y' : 'N' } @pfields),
			@ssl_field_values, @other_field_values);
		}
	else {
		# Update existing user
		$sql = "update user set host = ?, user = ?, ".
		       join(", ",map { "$_ = ?" } @pfields).
		       " where host = ? and user = ?";
		&execute_sql_logged($master_db, $sql,
			$host, $user,
			(map { $perms{$_} ? 'Y' : 'N' } @pfields),
			$in{'oldhost'}, $in{'olduser'});
		}
	&execute_sql_logged($master_db, 'flush privileges');
	if ($in{'mysqlpass_mode'} == 0) {
		$esc = &escapestr($in{'mysqlpass'});
		&execute_sql_logged($master_db,
			"set password for '".$user."'\@'".$host."' = ".
			"$password_func('$esc')");
		}
	elsif ($in{'mysqlpass_mode'} == 2) {
		&execute_sql_logged($master_db,
			"update user set password = NULL ".
			"where user = ? and host = ?",
			$user, $host);
		}

	# Save various limits
	$remote_mysql_version = &get_remote_mysql_version();
	foreach $f ('max_user_connections', 'max_connections',
		    'max_questions', 'max_updates') {
		next if ($remote_mysql_version < 5 || !defined($in{$f.'_def'}));
		$in{$f.'_def'} || $in{$f} =~ /^\d+$/ ||
		       &error($text{'user_e'.$f});
		&execute_sql_logged($master_db,
			"update user set $f = ? ".
			"where user = ? and host = ?",
			$in{$f.'_def'} ? 0 : $in{$f}, $user, $host);
		}

	# Set SSL fields
	if ($remote_mysql_version >= 5 && defined($in{'ssl_type'}) &&
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
&execute_sql_logged($master_db, 'flush privileges');
if (!$in{'delete'} && !$in{'new'} &&
    $in{'olduser'} eq $config{'login'} && !$access{'user'}) {
	# Renamed or changed the password for the Webmin login .. update
	# it too!
	$config{'login'} = $in{'mysqluser'};
	if ($in{'mysqlpass_mode'} == 0) {
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

