# mysql-lib.pl
# Common MySQL functions

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
require 'view-lib.pl';
if ($config{'mysql_libs'}) {
	$ENV{$gconfig{'ld_env'}} .= ':' if ($ENV{$gconfig{'ld_env'}});
	$ENV{$gconfig{'ld_env'}} .= $config{'mysql_libs'};
	}
if ($config{'mysql'} =~ /^(\S+)\/bin\/mysql$/ && $1 ne '' && $1 ne '/usr') {
	$ENV{$gconfig{'ld_env'}} .= ':' if ($ENV{$gconfig{'ld_env'}});
	$ENV{$gconfig{'ld_env'}} .= "$1/lib";
	}
if ($module_info{'usermin'}) {
	# Usermin always runs this module as the logged-in Unix user.
	# %access is faked up to prevent attempts to create and delete DBs
	&switch_to_remote_user();
	&create_user_config_dirs();
	%access = ( 'create', 0,
	            'delete', 0,
	            'bpath', '/',
	            'buser', 'root',
	            'edonly', 0 );
	if ($config{'useident'} ne 'yes') {
		$mysql_login = $userconfig{'login'};
		$mysql_pass = $userconfig{'pass'};
		}
	chop($mysql_version = &read_file_contents(
		"$user_module_config_directory/version"));
	$max_dbs = $userconfig{'max_dbs'};
	$commands_file = "$user_module_config_directory/commands";
	$sql_charset = $userconfig{'charset'};
	%displayconfig = %userconfig;
	}
else {
	# Webmin connects to the database as the user specified in the per-user
	# or global config
	%access = &get_module_acl();
	if ($access{'user'} && !$use_global_login) {
		$mysql_login = $access{'user'};
		$mysql_pass = $access{'pass'};
		}
	else {
		$mysql_login = $config{'login'};
		$mysql_pass = $config{'pass'};
		}
	chop($mysql_version = &read_file_contents(
		"$module_config_directory/version"));
	$mysql_version ||= &get_mysql_version();
	$cron_cmd = "$module_config_directory/backup.pl";
	$max_dbs = $config{'max_dbs'};
	$commands_file = "$module_config_directory/commands";
	$sql_charset = $config{'charset'};
	%displayconfig = %config;
	}
$authstr = &make_authstr();
$master_db = 'mysql';
$password_func = $config{'passwd_mode'} ? "old_password" : "password";

@type_list = ('tinyint', 'smallint', 'mediumint', 'int', 'bigint',
	    'float', 'double', 'decimal', 'date', 'datetime', 'timestamp',
	    'time', 'year', 'char', 'varchar', 'tinyblob', 'tinytext',
	    'blob', 'text', 'mediumblob', 'mediumtext', 'longblob', 'longtext',
	    'enum', 'set');

@priv_cols = ('Host', 'User', 'Password', 'Select_priv', 'Insert_priv', 'Update_priv', 'Delete_priv', 'Create_priv', 'Drop_priv', 'Reload_priv', 'Shutdown_priv', 'Process_priv', 'File_priv', 'Grant_priv', 'References_priv', 'Index_priv', 'Alter_priv', 'Show_db_priv', 'Super_priv', 'Create_tmp_table_priv', 'Lock_tables_priv', 'Execute_priv', 'Repl_slave_priv', 'Repl_client_priv', 'Create_view_priv', 'Show_view_priv', 'Create_routine_priv', 'Alter_routine_priv', 'Create_user_priv');

if (!$config{'nodbi'}) {
	# Check if we have DBI::mysql
	eval <<EOF;
use DBI;
\$driver_handle = DBI->install_driver("mysql");
EOF
}

@mysql_set_variables = ( $mysql_version >= 5.5 ? "key_buffer_size"
					       : "key_buffer",
			 $mysql_version >= 5.5 ? "sort_buffer_size"
					       : "sort_buffer",
			 "net_buffer_length" );
@mysql_number_variables = ( $mysql_version >= 5.6 ? "table_open_cache"
						  : "table_cache",
			    "max_connections" );
@mysql_byte_variables = ( "query_cache_size", "max_allowed_packet" );
if ($mysql_version >= 5) {
	push(@mysql_byte_variables, "myisam_sort_buffer_size");
	}
else {
	push(@mysql_set_variables, "myisam_sort_buffer_size");
	}

# make_authstr([login], [pass], [host], [port], [sock], [unix-user])
# Returns a string to pass to MySQL commands to login to the database
sub make_authstr
{
local $login = defined($_[0]) ? $_[0] : $mysql_login;
local $pass = defined($_[1]) ? $_[1] : $mysql_pass;
local $host = defined($_[2]) ? $_[2] : $config{'host'};
local $port = defined($_[3]) ? $_[3] : $config{'port'};
local $sock = defined($_[4]) ? $_[4] : $config{'sock'};
local $unix = $_[5];
if (&supports_env_pass($unix)) {
	$ENV{'MYSQL_PWD'} = $pass;
	}
return ($sock ? " -S $sock" : "").
       ($host ? " -h $host" : "").
       ($port ? " -P $port" : "").
       ($login ? " -u ".quotemeta($login) : "").
       (&supports_env_pass($unix) ? "" :    # Password comes from environment
        $pass && $mysql_version >= 4.1 ? " --password=".quotemeta($pass) :
        $pass ? " -p".quotemeta($pass) : "");
}

# is_mysql_running()
# Returns 1 if mysql is running, 0 if not, or -1 if running but
# inaccessible without a password. When called in an array context, also
# returns the full error message
sub is_mysql_running
{
# First type regular connection
if ($driver_handle && !$config{'nodbi'}) {
	local $main::error_must_die = 1;
	local ($data, $rv);
	eval { $data = &execute_sql_safe(undef, "select version()"); };
	local $err = $@;
	$err =~ s/\s+at\s+\S+\s+line.*$//;
	if ($@ =~ /denied|password/i) {
		$rv = -1;
		}
	elsif ($@ =~ /connect/i) {
		$rv = 0;
		}
	elsif ($data->{'data'}->[0]->[0] =~ /^\d/) {
		$rv = 1;
		}
	if (defined($rv)) {
		return wantarray ? ( $rv, $err ) : $rv;
		}
	}

# Fall back to mysqladmin command
local $out = &backquote_command(
	"\"$config{'mysqladmin'}\" $authstr status 2>&1");
local $rv = $out =~ /uptime/i ? 1 :
            $out =~ /denied|password/i ? -1 : 0;
$out =~ s/^.*\Q$config{'mysqladmin'}\E\s*:\s*//;
return wantarray ? ($rv, $out) : $rv;
}

# list_databases()
# Returns a list of all databases
sub list_databases
{
local @rv;
eval {
	# First try using SQL
	local $main::error_must_die = 1;
	local $t = &execute_sql_safe($master_db, "show databases");
	@rv = map { $_->[0] } @{$t->{'data'}};
	};
if (!@rv || $@) {
	# Fall back to mysqlshow command
	open(DBS, "\"$config{'mysqlshow'}\" $authstr |");
	local $t = &parse_mysql_table(DBS);
	close(DBS);
	ref($t) || &error("Failed to list databases : $t");
	@rv = map { $_->[0] } @{$t->{'data'}};
	}
return sort { lc($a) cmp lc($b) } @rv;
}

# list_tables(database, [empty-if-denied], [no-filter-views])
# Returns a list of tables in some database
sub list_tables
{
my ($db, $empty_denied, $include_views) = @_;
my @rv;
eval {
	# First try using SQL
	local $main::error_must_die = 1;
        local $t = &execute_sql_safe($db, "show tables");
        @rv = map { $_->[0] } @{$t->{'data'}};
	};
if ($@) {
	# Fall back to mysqlshow command
	local $tspec = $db =~ /_/ ? "%" : "";
	open(DBS, "\"$config{'mysqlshow'}\" $authstr ".
		  quotemeta($db)." $tspec 2>&1 |");
	local $t = &parse_mysql_table(DBS);
	close(DBS);
	if ($t =~ /access denied/i) {
		if ($empty_denied) {
			return ( );
			}
		else {
			&error($text{'edenied'});
			}
		}
	elsif (!ref($t)) {
		&error("<tt>".&html_escape($t)."</tt>");
		}
	@rv = map { $_->[0] } @{$t->{'data'}};
	}

# Filter out views
if (!$include_views) {
	if (&supports_views()) {
		my %views = map { $_, 1 } &list_views($db);
		@rv = grep { !$views{$_} } @rv;
		}
	}
return @rv;
}

# table_structure(database, table)
# Returns a list of hashes detailing the structure of a table
sub table_structure
{
local $s = &execute_sql_safe($_[0], "desc ".&quotestr($_[1]));
local (@rv, $r);
local (%tp, $i);
for($i=0; $i<@{$s->{'titles'}}; $i++) {
	$tp{lc($s->{'titles'}->[$i])} = $i;
	}
my $i = 0;
foreach $r (@{$s->{'data'}}) {
	push(@rv, { 'field' => $r->[$tp{'field'}],
		    'type' => $r->[$tp{'type'}],
		    'null' => $r->[$tp{'null'}],
		    'key' => $r->[$tp{'key'}],
		    'default' => $r->[$tp{'default'}],
		    'extra' => $r->[$tp{'extra'}],
		    'index' => $i++ });
	}
return @rv;
}

# table_field_sizes(db, table)
# Returns a hash mapping field names to sizes
sub table_field_sizes
{
local %rv;
foreach my $s (&table_structure(@_)) {
	if ($s->{'type'} =~ /^\S+\((\d+)(,\d+)?\)/) {
		$rv{lc($s->{'field'})} = $1;
		}
	}
return %rv;
}

# execute_sql(database, command, [param, ...])
# Executes some SQL and returns the results, after checking for the user's
# readonly status.
sub execute_sql
{
return { } if (&is_readonly_mode());
return &execute_sql_safe(@_);
}

# execute_sql_safe(database, command, [param, ...])
# Executes some SQL and returns the results
sub execute_sql_safe
{
local $sql = $_[1];
@params = @_[2..$#_];
if ($gconfig{'debug_what_sql'}) {
	# Write to Webmin debug log
	local $params;
	for(my $i=0; $i<@params; $i++) {
		$params .= " ".$i."=".$params[$i];
		}
	&webmin_debug_log('SQL', "db=$_[0] sql=$sql".$params);
	}
$sql = &escape_backslashes_in_quotes($sql);
if ($driver_handle && !$config{'nodbi'}) {
	# Use the DBI interface
	local $cstr = "database=$_[0]";
	$cstr .= ";host=$config{'host'}" if ($config{'host'});
	$cstr .= ";port=$config{'port'}" if ($config{'port'});
	$cstr .= ";mysql_socket=$config{'sock'}" if ($config{'sock'});
	$cstr .= ";mysql_read_default_file=$config{'my_cnf'}"
		if (-r $config{'my_cnf'});
	local $dbh = $driver_handle->connect($cstr, $mysql_login, $mysql_pass,
					     { });
	$dbh || &error("DBI connect failed : ",$driver_handle->errstr);
	if ($sql_charset) {
		# Switch to correct character set
		local $sql = "set names '$sql_charset'";
		local $cmd = $dbh->prepare($sql);
		if (!$cmd) {
			&error(&text('esql', "<tt>".&html_escape($sql)."</tt>",
				     "<tt>".&html_escape($dbh->errstr)."</tt>"));
			}
		if (!$cmd->execute()) {
			&error(&text('esql', "<tt>".&html_escape($sql)."</tt>",
				     "<tt>".&html_escape($dbh->errstr)."</tt>"));
			}
		$cmd->finish();
		}
	local $cmd = $dbh->prepare($sql);
	if (!$cmd) {
		&error(&text('esql', "<tt>".&html_escape($_[1])."</tt>",
			     "<tt>".&html_escape($dbh->errstr)."</tt>"));
		}
	if (!$cmd->execute(@params)) {
		&error(&text('esql', "<tt>".&html_escape($_[1])."</tt>",
			     "<tt>".&html_escape($dbh->errstr)."</tt>"));
		}
	local (@data, @row);
	local @titles = @{$cmd->{'NAME'}};
	while(@row = $cmd->fetchrow()) {
		push(@data, [ @row ]);
		}
	$cmd->finish();
	$dbh->disconnect();
	return { 'titles' => \@titles,
		 'data' => \@data };
	}
else {
	# Use the mysql command program
	local $temp = &transname();
	if (@params) {
		# Sub in ? parameters
		$sql = &replace_sql_parameters($sql, @params);
		}
	open(TEMP, ">$temp");
	if ($sql_charset) {
		print TEMP "set names '$sql_charset';\n";
		}
	print TEMP $sql,"\n";
	close(TEMP);
	open(DBS, "\"$config{'mysql'}\" $authstr -E -t ".quotemeta($_[0])." <$temp 2>&1 |");
	local $t = &parse_mysql_vertical(DBS);
	close(DBS);
	unlink($temp);
	if (!ref($t)) {
		$t =~ s/^ERROR[^:]*://;
		&error(&text('esql', "<tt>".&html_escape($_[1])."</tt>",
			    "<tt>".&html_escape($t)."</tt>"));
		}
	return $t;
	}
}

# replace_sql_parameters(sql, params)
# Returns a string with ? replaced by parameter text
sub replace_sql_parameters
{
my ($sql, @params) = @_;
my $pos = -1;
foreach my $p (@params) {
	$pos = index($sql, '?', $pos+1);
	&error("Incorrect number of parameters") if ($pos < 0);
	local $qp = $p;
	$qp =~ s/'/''/g;
	$qp = !defined($qp) ? 'NULL' : "'$qp'";
	$sql = substr($sql, 0, $pos).$qp.substr($sql, $pos+1);
	$pos += length($qp)-1;
	}
return $sql;
}

# execute_sql_logged(database, command, param, ...)
# Calls execute_sql, but logs the command first
sub execute_sql_logged
{
local ($db, $sql, @params) = @_;
if (@params) {
	eval {
		local $main::error_must_die = 1;
		$sql = &replace_sql_parameters($sql, @params);
		}
	}
&additional_log('sql', $db, $sql);
return &execute_sql(@_);
}

# parse_mysql_table(handle)
# Given a filehandle, parses a text table in the format mysql uses
sub parse_mysql_table
{
local $fh = $_[0];
local ($line, $i, @edge);
do {
	# skip to table top
	$line = <$fh>;
	return $line if ($line =~ /^(ERROR|\S*mysqlshow:)/);
	} while($line && $line !~ /^\+/);
for($i=0; $i<length($line); $i++) {
	push(@edge, $i) if (substr($line, $i, 1) eq '+');
	}
$line = <$fh>;		# skip first row of -'s
local @titles = &parse_mysql_line($line, \@edge);
$line = <$fh>;		# skip next row of -'s
local @data;
while(1) {
	$line = <$fh>;
	last if (!$line || $line !~ /^\|/);
	while($line !~ /\|\s+$/) {
		# Line has a return in it!
		$line .= <$fh>;
		}
	push(@data, [ &parse_mysql_line($line, \@edge) ]);
	}
return { 'titles' => \@titles,
	 'data' => \@data };
}

# parse_mysql_line(line, &edges)
sub parse_mysql_line
{
local @rv;
for($i=0; $i<@{$_[1]}-1; $i++) {
	local $w = substr($_[0], $_[1]->[$i]+1,
			  $_[1]->[$i+1] - $_[1]->[$i] - 2);
	$w =~ s/^\s//;
	$w =~ s/\s+$//;
	$w =~ s/\\/\\\\/g;
	$w =~ s/\n/\\n/g;
	push(@rv, $w);
	}
return @rv;
}

# parse_mysql_vertical(handle)
# Parses mysql output in the -E format
sub parse_mysql_vertical
{
local (@data, @titles, $row = -1, $col, %hascol);
local $fh = $_[0];
local $line = <$fh>;
if (!$line) {
	# No output at all - must be a non-select
	return { };
	}
return $line if ($line =~ /^ERROR/);
local $errtxt = &text('eparse', "<tt>mysql</tt>", "<tt>DBI</tt>",
		      "<tt>DBD::mysql</tt>");
while($line) {
	$line =~ s/\r|\n//g;
	if ($line =~ /^\*\*\*/) {
		# A row header
		$row++;
		$col = -1;
		$data[$row] = [ ];
		}
	elsif ($line =~ /^\s*([^:\s]+): (.*)/ && ($row == 0 || $hascol{$1})) {
		# A new column
		$col++;
		$titles[$col] = $1;
		$row >= 0 || return $errtxt;
		$data[$row]->[$col] = $2;
		$hascol{$1}++;
		}
	else {
		# Continuing the last column
		$row >= 0 || return $errtxt;
		$data[$row]->[$col] .= "\n".$line;
		}
	$line = <$fh>;
	}
return { 'titles' => \@titles,
	 'data' => \@data };
}

sub can_edit_db
{
if ($module_info{'usermin'}) {
	foreach $l (split(/\t/, $config{'access'})) {
		if ($l =~ /^(\S+):\s*(.*)$/ &&
		    ($1 eq $remote_user || $1 eq '*')) {
			local @dbs = split(/\s+/, $2);
			local $d;
			foreach $d (@dbs) {
				$d =~ s/\$REMOTE_USER/$remote_user/g;
				return 1 if ($d eq '*' || $_[0] =~ /^$d$/);
				}
			return 0;
			}
		}
	return 0;
	}
else {
	local $d;
	return 1 if ($access{'dbs'} eq '*');
	foreach $d (split(/\s+/, $access{'dbs'})) {
		return 1 if ($d && $d eq $_[0]);
		}
	return 0;
	}
}

# supports_backup_db(name)
# Returns 1 if some database can be backed up
sub supports_backup_db
{
return $_[0] ne "information_schema" &&
       $_[0] ne "performance_schema";
}

# list_accessible_databases()
# Returns a list of databases that the current user may access to. Returns
# an empty list if he has all of them.
sub list_accessible_databases
{
if ($module_info{'usermin'}) {
	# From Usermin list
	local @rv;
	foreach $l (split(/\t/, $config{'access'})) {
		if ($l =~ /^(\S+):\s*(.*)$/ &&
		    ($1 eq $remote_user || $1 eq '*')) {
			push(@rv, split(/\s+/, $2));
			}
		}
	return @rv;
	}
else {
	# From Webmin access control list
	return ( ) if ($access{'dbs'} eq '*');
	return split(/\s+/, $access{'dbs'});
	}
}

# split_table(&titles, &checkboxes, &links, &col1, &col2, ...)
# Outputs a table that is split into two parts
sub split_table
{
local $mid = int((@{$_[2]}+1) / 2);
local ($i, $j);
print "<table width=100%><tr>\n";
foreach $s ([0, $mid-1], [$mid, @{$_[2]}-1]) {
	print "<td width=50% valign=top>\n";

	# Header
	local @tds = $_[1] ? ( "width=5" ) : ( );
	if ($s->[0] <= $s->[1]) {
		local @hcols;
		foreach $t (@{$_[0]}) {
			push(@hcols, $t);
			}
		print &ui_columns_start(\@hcols, 100, 0, \@tds);
		}

	for($i=$s->[0]; $i<=$s->[1]; $i++) {
		local @cols;
		push(@cols, "<a href='$_[2]->[$i]'>$_[3]->[$i]</a>");
		for($j=4; $j<@_; $j++) {
			push(@cols, $_[$j]->[$i]);
			}
		if ($_[1]) {
			print &ui_checked_columns_row(\@cols, \@tds, "d", $_[1]->[$i]);
			}
		else {
			print &ui_columns_row(\@cols, \@tds);
			}
		}
	if ($s->[0] <= $s->[1]) {
		print &ui_columns_end();
		}
	print "</td>\n";
	}
print "</tr></table>\n";
}

# select_db(db)
sub select_db
{
local $rv;
local @dbs = &list_databases();
local $d;
if ($access{'perms'} == 2 && $access{'dbs'} ne '*') {
	# Can only select his own databases
	$rv = &ui_select("dbs", $_[0],
			 [ grep { &can_edit_db($_) } @dbs ], 1, 0, $_[0] ? 1 : 0);
	}
else {
	# Can select any databases
	local $ind = &indexof($_[0],@dbs) >= 0;
	local $js1 = "onChange='form.db_def[1].checked = true'";
	local $js2 = "onClick='form.db_def[2].checked = true'";
	$rv = &ui_radio("db_def", $_[0] eq '%' || $_[0] eq '' ? 1 :
				  $ind ? 2 : 0,
			[ [ 1, $text{'host_any'} ],
			  [ 2, $text{'host_sel'}."&nbsp;".
			    &ui_select("dbs", $_[0], \@dbs, 1, 0, 0, 0, $js1) ],
			  [ 0, $text{'host_otherdb'}."&nbsp;".
			       &ui_textbox("db", $_[0] eq '%' || $_[0] eq '' ||
						 $ind ? '' : $_[0], 30, 0,
					   undef, $js2) ] ]);
	}
return $rv;
}

sub quote_table
{
return &quotestr($_[0]);
}

# quotestr(string)
sub quotestr
{
local $rv = $_[0];
if (&supports_quoting()) {
	return "`$rv`";
	}
else {
	return $rv;
	}
}

# escapestr(string)
# Returns a string with quotes escaped, for use in SQL
sub escapestr
{
local $rv = $_[0];
$rv =~ s/'/''/g;
return $rv;
}

# escape_backslashes_in_quotes(string)
# Escapes backslashes, but only inside quoted strings
sub escape_backslashes_in_quotes
{
local ($str) = @_;
local $rv;
while($str =~ /^([^"]*)"([^"]*)"(.*)$/) {
	local ($before, $quoted, $after) = ($1, $2, $3);
	$quoted =~ s/\\/\\\\/g;
	$rv .= $before.'"'.$quoted.'"';
	$str = $after;
	}
$rv .= $str;
return $rv;
}

# supports_quoting()
# Returns 1 if running mysql version 3.23.6 or later
sub supports_quoting
{
if ($mysql_version =~ /^(\d+)\.(\d+)\.(\d+)$/ &&
    ($1 > 3 || ($1 == 3 && $2 > 23) || ($1 == 3 && $2 == 23 && $3 >= 6))) {
	return 1;
	}
elsif ($mysql_version > 4) {
	return 1;
	}
else {
	return 0;
	}
}

# supports_mysqldump_events()
# Returns 1 if running mysqldump 5.1.8 or later, which supports (and needs)
# the events flag
sub supports_mysqldump_events
{
if ($mysql_version >= 6 ||
    $mysql_version =~ /^(\d+)\.(\d+)/ && $1 == 5 && $2 >= 2 ||
    $mysql_version =~ /^(\d+)\.(\d+)\.(\d+)/ && $1 == 5 && $2 == 1 && $3 >= 8) {
	return 1;
	}
return 0;
}

# supports_routines()
# Returns 1 if mysqldump supports routines
sub supports_routines
{
local $out = &backquote_command("$config{'mysqldump'} --help 2>&1 </dev/null");
return $out =~ /--routines/ ? 1 : 0;
}

# supports_views()
# Returns 1 if this MySQL install supports views
sub supports_views
{
return $mysql_version >= 5;
}

# supports_variables()
# Returns 1 if running mysql version 4.0.3 or later
sub supports_variables
{
if ($mysql_version =~ /^(\d+)\.(\d+)\.(\d+)$/ &&
    ($1 > 4 || ($1 == 4 && $2 > 0) || ($1 == 4 && $2 == 0 && $3 >= 3))) {
	return 1;
	}
elsif ($mysql_version > 4) {
	return 1;
	}
else {
	return 0;
	}
}

# supports_hosts()
# Returns 1 if the hosts table exists
sub supports_hosts
{
return $mysql_version < 5.7 ? 1 :
       $mysql_version =~ /^5\.7\.(\d+)/ && $1 < 16 ? 1 : 0;
}

# supports_env_pass([run-as-user])
# Returns 1 if passing the password via an environment variable is supported
sub supports_env_pass
{
local ($user) = @_;
if ($mysql_version >= 4.1 && !$config{'nopwd'}) {
	# Theortically possible .. but don't do this if ~/.my.cnf contains
	# a [client] block with password= in it
	my @uinfo = $user ? getpwnam($user) : getpwuid($<);
	foreach my $cf ($config{'my_cnf'}, "$uinfo[7]/.my.cnf",
			"$ENV{'HOME'}/.my.cnf") {
		next if (!$cf || !-r $cf);
		local @cf = &parse_mysql_config($cf);
		local $client = &find("client", \@cf);
		next if (!$client);
		local $password = &find("password", $client->{'members'});
		return 0 if ($password ne '');
		}
	return 1;
	}
return 0;
}

# working_env_pass()
# Returns 1 if MYSQL_PWD can be used to pass the password to mysql
sub working_env_pass
{
return 1 if (!&supports_env_pass());	# Not even used
local $config{'nodbi'} = 1;
local $data;
local $main::error_must_die = 1;
eval { $data = &execute_sql_safe(undef, "select version()") };
return $@ || !$data ? 0 : 1;
}

# priv_fields(type)
# Returns the names and descriptions of fields for user/db/host privileges
sub priv_fields
{
my ($type) = @_;
if (!$priv_fields{$type}) {
	$priv_fields{$type} = [];
	foreach my $s (&table_structure("mysql", $type)) {
		if ($s->{'field'} =~ /^(.*)_priv/i) {
			push(@{$priv_fields{$type}},
			     [ $s->{'field'}, $text{'user_priv_'.lc($1)} ||
					      $s->{'field'} ]);
			}
		}
	}
return @{$priv_fields{$type}};
}

# ssl_fields()
# Returns the names of SSL fields that need to be set for new users
sub ssl_fields
{
my @desc = &table_structure($master_db, 'user');
my %fieldmap = map { $_->{'field'}, $_->{'index'} } @desc;
return grep { $fieldmap{$_} } ('ssl_type', 'ssl_cipher',
			       'x509_issuer', 'x509_subject');
}

# other_user_fields()
# Returns the names of other non-default new user fields
sub other_user_fields
{
my @desc = &table_structure($master_db, 'user');
my %fieldmap = map { $_->{'field'}, $_->{'index'} } @desc;
return grep { $fieldmap{$_} } ('authentication_string');
}

sub is_blob
{
return $_[0]->{'type'} =~ /(text|blob)$/i;
}

# get_mysql_version(&out)
# Returns a version number, undef if one cannot be found, or -1 for a .so
# problem. This is the version of the *local* mysql command, not necessarily
# the remote server.
sub get_mysql_version
{
local $out = &backquote_command("\"$config{'mysql'}\" -V 2>&1");
${$_[0]} = $out if ($_[0]);
if ($out =~ /lib\S+\.so/) {
	return -1;
	}
elsif ($out =~ /(distrib|Ver)\s+((3|4|5|6|7|8|9|10)\.[0-9\.]*)/i) {
	return $2;
	}
else {
	return undef;
	}
}

# get_remote_mysql_version()
# Returns the version of the MySQL server, or -1 if unknown
sub get_remote_mysql_version
{
local $main::error_must_die = 1;
local $data;
eval { $data = &execute_sql_safe(undef, "select version()"); };
return -1 if ($@);
return -1 if (!@{$data->{'data'}});
return $data->{'data'}->[0]->[0];
}

# save_mysql_version([number])
# Update the saved local MySQL version number
sub save_mysql_version
{
local ($ver) = @_;
$ver ||= &get_mysql_version();
if ($ver) {
	&open_tempfile(VERSION, ">$module_config_directory/version");
	&print_tempfile(VERSION, $ver,"\n");
	&close_tempfile(VERSION);
	}
}

# date_subs(filename)
# Does strftime-style date substitutions on a filename, if enabled
sub date_subs
{
local ($path) = @_;
local $rv;
if ($config{'date_subs'}) {
        eval "use POSIX";
	eval "use posix" if ($@);
        local @tm = localtime(time());
	&clear_time_locale();
        $rv = strftime($path, @tm);
	&reset_time_locale();
        }
else {
        $rv = $path;
        }
if ($config{'webmin_subs'}) {
	$rv = &substitute_template($rv, { });
	}
return $rv;
}

# execute_before(db, handle, escape, path, db-for-config)
# Executes the before-backup command for some DB, and sends output to the
# given file handle. Returns 1 if the command succeeds, or 0 on failure
sub execute_before
{
local $cmd = $config{'backup_before_'.$_[4]};
if ($cmd) {
	$ENV{'BACKUP_FILE'} = $_[3];
	local $h = $_[1];
	local $out;
	local $rv = &execute_command($cmd, undef, \$out, \$out);
	if ($h && $out) {
		print $h $_[2] ? "<pre>".&html_escape($out)."</pre>" : $out;
		}
	return !$rv;
	}
return 1;
}

# execute_after(db, handle, escape, path, db-for-config)
sub execute_after
{
local $cmd = $config{'backup_after_'.$_[4]};
if ($cmd) {
	$ENV{'BACKUP_FILE'} = $_[3];
	local $h = $_[1];
	local $out;
	local $rv = &execute_command($cmd, undef, \$out, \$out);
	if ($h && $out) {
		print $h $_[2] ? "<pre>".&html_escape($out)."</pre>" : $out;
		}
	return !$rv;
	}
return 1;
}

# show_table_form(count)
sub show_table_form
{
my $rv;
$rv = &ui_columns_start([ $text{'field_name'}, $text{'field_type'},
			  $text{'field_size'}, $text{'table_nkey'},
			  $text{'field_auto'}, $text{'field_null'},
			  $text{'field_unsigned'}, $text{'field_default'} ]);
for(my $i=0; $i<$_[0]; $i++) {
	my @cols;
	push(@cols, &ui_textbox("field_$i", undef, 20));
	push(@cols, &ui_select("type_$i", "", [ "", @type_list ]));
	push(@cols, &ui_textbox("size_$i", undef, 10));
	push(@cols, &ui_checkbox("key_$i", 1, $text{'yes'}, 0));
	push(@cols, &ui_checkbox("auto_$i", 1, $text{'yes'}, 0));
	push(@cols, &ui_checkbox("null_$i", 1, $text{'yes'}, 1));
	push(@cols, &ui_checkbox("unsigned_$i", 1, $text{'yes'}, 0));
	push(@cols, &ui_textbox("default_$i", undef, 20));
	$rv .= &ui_columns_row(\@cols);
	}
$rv .= &ui_columns_end();
return $rv;
}

# parse_table_form(&extrafields, tablename)
sub parse_table_form
{
local @fields = @{$_[0]};
local $i;
local (@auto, @pri);
for($i=0; defined($in{"field_$i"}); $i++) {
	next if (!$in{"field_$i"});
	$in{"field_$i"} =~ /^\S+$/ ||
		&error(&text('table_efield', $in{"field_$i"}));
	$in{"type_$i"} || &error(&text('table_etype', $in{"field_$i"}));
	if ($in{"type_$i"} eq 'enum' || $in{"type_$i"} eq 'set') {
		local @ev = split(/\s+/, $in{"size_$i"});
		@ev || &error(&text('table_eenum', $in{"type_$i"},
						   $in{"field_$i"}));
		$in{"size_$i"} = join(",", map { "'$_'" } @ev);
		}
	if ($in{"size_$i"}) {
		push(@fields, sprintf "%s %s(%s)",
		     &quotestr($in{"field_$i"}), $in{"type_$i"},$in{"size_$i"});
		}
	else {
		push(@fields, sprintf "%s %s",
			&quotestr($in{"field_$i"}), $in{"type_$i"});
		}
	if ($in{"unsigned_$i"}) {
		$fields[@fields-1] .= " unsigned";
		}
	if (!$in{"null_$i"}) {
		$fields[@fields-1] .= " not null";
		}
	if ($in{"key_$i"}) {
		$in{"null_$i"} && &error(&text('table_epnull',$in{"field_$i"}));
		push(@pri, $in{"field_$i"});
		}
	if ($in{"auto_$i"}) {
		push(@auto, $fields[@fields-1]);
		push(@autokey, $in{"key_$i"});
		}
	if ($in{"default_$i"}) {
		$fields[@fields-1] .= " default '".$in{"default_$i"}."'";
		}
	}
@auto < 2 || &error($text{'table_eauto'});
@fields || &error($text{'table_enone'});
local @sql;
local $sql = "create table ".&quotestr($_[1])." (".join(",", @fields).")";
$sql .= " engine $in{'type'}" if ($in{'type'});
push(@sql, $sql);
if (@pri) {
	# Setup primary fields too
	push(@sql, "alter table ".&quotestr($_[1])." add primary key (".
		    join(",", map { &quotestr($_) } @pri).")");
	}
if (@auto) {
	# Make field auto-increment
	push(@sql, "alter table ".&quotestr($_[1]).
		   " modify $auto[0] auto_increment ".
		   ($autokey[0] ? "" : "unique"));
	}
return @sql;
}

# execute_sql_file(database, file, [user, pass], [unix-user])
# Executes some file of SQL commands, and returns the exit status and output
sub execute_sql_file
{
if (&is_readonly_mode()) {
	return (0, undef);
	}
local ($db, $file, $user, $pass) = @_;
local $authstr = &make_authstr($user, $pass);
local $cs = $sql_charset ? "--default-character-set=".quotemeta($sql_charset)
			 : "";
local $temp = &transname();
&open_tempfile(TEMP, ">$temp");
&print_tempfile(TEMP, "source ".$file.";\n");
&close_tempfile(TEMP);
&set_ownership_permissions(undef, undef, 0644, $temp);
local $cmd = "$config{'mysql'} $authstr -t ".quotemeta($db)." ".$cs.
	     " <".quotemeta($temp);
-r $file || return (1, "$file does not exist");
if ($_[4] && $_[4] ne 'root' && $< == 0) {
	# Restoring as a Unix user
	$cmd = &command_as_user($_[4], 0, $cmd);
	}
local $out = &backquote_logged("$cmd 2>&1");
local @rv = ($?, $? ? $out || "$cmd failed" : $out);
&make_authstr();	# Put back old password environment variable
return @rv;
}

# start_mysql()
# Starts the MySQL database server, and returns undef on success or an
# error message on failure.
sub start_mysql
{
local $temp = &transname();
local $rv = &system_logged("($config{'start_cmd'}) >$temp 2>&1");
local $out = `cat $temp`; unlink($temp);
if ($rv || $out =~ /failed/i) {
	return "<pre>".&html_escape($out)."</pre>";
	}
return undef;
}

# stop_mysql()
# Halts the MySQL database server, and returns undef on success or an
# error message on failure.
sub stop_mysql
{
local $out;
if ($config{'stop_cmd'}) {
	$out = &backquote_logged("$config{'stop_cmd'} 2>&1");
	}
else {
	$out = &backquote_logged("$config{'mysqladmin'} $authstr shutdown 2>&1");
	}
if ($? || $out =~ /failed/i) {
	return "<pre>".&html_escape($out)."</pre>";
	}
return undef;
}

# split_enum(type)
# Returns a list of allowed values for an enum
sub split_enum
{
local ($type) = @_;
if ($type =~ /^(enum|set)\((.*)\)$/) {
	$type = $2;
	}
local $esize = $type;
local @ev;
while($esize =~ /^'([^']*)'(,?)(.*)$/) {
	push(@ev, $1);
	$esize = $3;
	}
return @ev;
}

# Returns 1 if the mysql server being managed is on this system
sub is_mysql_local
{
return $config{'host'} eq '' || $config{'host'} eq 'localhost' ||
       $config{'host'} eq &get_system_hostname() ||
       &to_ipaddress($config{'host'}) eq &to_ipaddress(&get_system_hostname());
}

# get_mysql_config()
# Returns the parsed my.cnf file
sub get_mysql_config
{
if (!scalar(@mysql_config_cache)) {
	if (!-r $config{'my_cnf'}) {
		return undef;
		}
	@mysql_config_cache = &parse_mysql_config($config{'my_cnf'});
	}
return \@mysql_config_cache;
}

# parse_mysql_config(file)
# Reads one MySQL config file
sub parse_mysql_config
{
local ($file) = @_;
local @rv;
local $sect;
local $lnum = 0;
local $lref = &read_file_lines($file, 1);
local $_;
foreach (@$lref) {
	s/\r|\n//g;
	s/#.*$//;
	s/\s+$//;
	if (/^\s*\[(\S+)\]$/) {
		# Start of a section
		$sect = { 'name' => $1,
			  'members' => [ ],
			  'file' => $file,
			  'line' => $lnum,
			  'eline' => $lnum };
		push(@rv, $sect);
		}
	elsif (/^\s*(\S+)\s*=\s*(.*)$/ && $sect) {
		# Variable in a section
		push(@{$sect->{'members'}},
		     { 'name' => $1,
		       'value' => $2,
		       'file' => $file,
		       'line' => $lnum });
		$sect->{'eline'} = $lnum;
		}
	elsif (/^\s*(\S+)$/ && $sect) {
		# Single directive in a section
		push(@{$sect->{'members'}},
		     { 'name' => $1,
		       'file' => $file,
		       'line' => $lnum });
		$sect->{'eline'} = $lnum;
		}
	elsif (/^\s*\!include\s+(\S+)/) {
		# Including sections from a file
		foreach my $file (glob($1)) {
			push(@rv, &parse_mysql_config($file));
			}
		}
	elsif (/^\s*\!includedir\s+(\S+)/) {
		# Including sections from files in a directory
		my $dir = $1;
		opendir(DIR, $dir);
		my @files = map { $dir."/".$_ } readdir(DIR);
		closedir(DIR);
		foreach my $file (@files) {
			push(@rv, &parse_mysql_config($file));
			}
		}
	$lnum++;
	}
return @rv;
}

# find(name, &conf)
sub find
{
local ($name, $conf) = @_;
local @rv = grep { lc($_->{'name'}) eq lc($name) } @$conf;
return wantarray ? @rv : $rv[0];
}

# find_value(name, &conf)
sub find_value
{
local ($name, $conf) = @_;
local @rv = map { $_->{'value'} } &find($name, $conf);
return wantarray ? @rv : $rv[0];
}

# save_directive(&conf, &section, name, &values)
# Updates one or multiple lines in a my.cnf section
sub save_directive
{
local ($conf, $sect, $name, $values) = @_;
local @old = &find($name, $sect->{'members'});
local $file = @old ? $old[0]->{'file'} :
	      $sect ? $sect->{'file'} : $config{'my_cnf'};
local $lref = &read_file_lines($file);

for(my $i=0; $i<@old || $i<@$values; $i++) {
	local $old = $old[$i];
	local $line = $values->[$i] eq "" ? $name :
			"$name = $values->[$i]";
	if ($old && defined($values->[$i])) {
		# Updating
		$lref->[$old->{'line'}] = $line;
		$old->{'value'} = $values->[$i];
		}
	elsif (!$old && defined($values->[$i])) {
		# Adding
		splice(@$lref, $sect->{'eline'}+1, 0, $line);
		&renumber($conf, $sect->{'eline'}+1, 1, $file);
		push(@{$sect->{'members'}},
			{ 'name' => $name,
			  'value' => $values->[$i],
			  'line' => $sect->{'eline'}+1 });
		}
	elsif ($old && !defined($values->[$i])) {
		# Deleting
		splice(@$lref, $old->{'line'}, 1);
		&renumber($conf, $old->{'line'}, -1, $file);
		@{$sect->{'members'}} = grep { $_ ne $old }
					     @{$sect->{'members'}};
		}
	}
}

sub renumber
{
local ($conf, $line, $offset, $file) = @_;
foreach my $sect (@$conf) {
	next if ($sect->{'file'} ne $file);
	$sect->{'line'} += $offset if ($sect->{'line'} >= $line);
	$sect->{'eline'} += $offset if ($sect->{'eline'} >= $line);
	foreach my $m (@{$sect->{'members'}}) {
		$m->{'line'} += $offset if ($m->{'line'} >= $line);
		}
	}
}

# parse_set_variables(value, ...)
# Returns a hash of variable mappings
sub parse_set_variables
{
local %vars;
foreach my $v (@_) {
	if ($v =~ /^(\S+)=(\S+)$/) {
		$vars{$1} = $2;
		}
	}
return %vars;
}

sub mysql_size_input
{
local ($name, $value) = @_;
local $units;
if ($value =~ /^(\d+)([a-z])$/i) {
	$value = $1;
	$units = $2;
	}
$units = "" if ($units eq "b");
return &ui_textbox($name, $value, 8)."\n".
       &ui_select($name."_units", $units,
		  [ [ "", "bytes" ], [ "K", "kB" ],
		    [ "M", "MB" ], [ "G", "GB" ] ]);
}

# list_indexes(db)
# Returns the names of all indexes in some database
sub list_indexes
{
local ($db) = @_;
local (@rv, $r);
foreach my $table (&list_tables($db)) {
	local $s = &execute_sql_safe($db, "show index from ".&quotestr($table));
	local (%tp, $i);
	for($i=0; $i<@{$s->{'titles'}}; $i++) {
		$tp{lc($s->{'titles'}->[$i])} = $i;
		}
	foreach $r (@{$s->{'data'}}) {
		if ($r->[$tp{'key_name'}] ne 'PRIMARY') {
			push(@rv, $r->[$tp{'key_name'}]);
			}
		}
	}
return &unique(@rv);
}

# index_structure(db, indexname)
# Returns information on an index
sub index_structure
{
local ($db, $index) = @_;
local (@rv, $r);
local $info;
foreach my $table (&list_tables($db)) {
	local $s = &execute_sql_safe($db, "show index from ".&quotestr($table));
	local (%tp, $i);
	for($i=0; $i<@{$s->{'titles'}}; $i++) {
		$tp{lc($s->{'titles'}->[$i])} = $i;
		}
	foreach $r (@{$s->{'data'}}) {
		if ($r->[$tp{'key_name'}] eq $index) {
			# Found some info
			$info->{'table'} = $r->[$tp{'table'}];
			$info->{'name'} = $index;
			$info->{'type'} = lc($r->[$tp{'index_type'}]) ||
					  lc($r->[$tp{'comment'}]);
			push(@{$info->{'cols'}}, $r->[$tp{'column_name'}]);
			}
		}
	}
return $info;
}

# list_views(db)
# Returns the names of all views in some database
sub list_views
{
local ($db) = @_;
local @rv;
local $d = &execute_sql($db, "select table_schema,table_name from information_schema.views where table_schema = ?", $db);
foreach $r (@{$d->{'data'}}) {
	push(@rv, $r->[1]);
	}
return @rv;
}

# view_structure(db, viewname)
# Returns information about a view
sub view_structure
{
local ($db, $view) = @_;
local $info = { 'name' => $view };
local $d = &execute_sql($db, "show create view $view");
local $c = $d->{'data'}->[0]->[1];
if ($c =~ /algorithm\s*=\s*(\S+)/i) {
	$info->{'algorithm'} = lc($1);
	}
if ($c =~ /definer\s*=\s*`(\S+)`\@`(\S+)`/i) {
	$info->{'definer'} = "$1\@$2";
	}
elsif ($c =~ /definer\s*=\s*(\S+)/i) {
	$info->{'definer'} = $1;
	}
if ($c =~ /sql\s+security\s+(\S+)/i) {
	$info->{'security'} = lc($1);
	}
if ($c =~ s/\s+with\s+(cascaded|local)\s+check\s+option//i) {
	$info->{'check'} = lc($1);
	}
if ($c =~ /view\s+(`\S+`|\S+)\s+as\s+(.*)/i) {
	$info->{'query'} = $2;
	}
return $info;
}

# list_character_sets([db])
# Returns a list of supported character sets. Each row is an array ref of
# a code and name
sub list_character_sets
{
local @rv;
local $db = $_[0] || $master_db;
if (&get_remote_mysql_version() < 4.1) {
	local $d = &execute_sql($db, "show variables like 'character_sets'");
	@rv = map { [ $_, $_ ] } split(/\s+/, $d->{'data'}->[0]->[1]);
	}
else {
	local $d = &execute_sql($db, "show character set");
	@rv = map { [ $_->[0], $_->[1] ] } @{$d->{'data'}};
	}
return sort { lc($a->[1]) cmp lc($b->[1]) } @rv;
}

# list_collation_orders([db])
# Returns a list of supported collation orders. Each row is an array ref of
# a code and character set it can work with.
sub list_collation_orders
{
local @rv;
local $db = $_[0] || $master_db;
if (&get_remote_mysql_version() >= 5) {
	local $d = &execute_sql($db, "show collation");
	@rv = map { [ $_->[0], $_->[1] ] } @{$d->{'data'}};
	}
return sort { lc($a->[0]) cmp lc($b->[0]) } @rv;
}

# list_system_variables()
# Returns a list of all system variables, and their default values
sub list_system_variables
{
local $mysqld = $config{'mysqld'};
if (!$mysqld) {
	# Mysqld path not in config .. guess from mysql path
	$mysqld = $config{'mysql'};
	$mysqld =~ s/mysql$/mysqld/g;
	$mysqld =~ s/bin/sbin/g;
	if (!-x $mysqld) {
		$mysqld = $config{'mysql'};
		$mysqld =~ s/mysql$/mysqld/g;
		$mysqld =~ s/bin/libexec/g;
		if (!-x $mysqld) {
			# Look in Webmin path
			&error($mysqld);
			$mysqld = &has_command("mysqld");
			}
		}
	}
return ( ) if (!$mysqld);

# Read supported variables
local @rv;
&open_execute_command(MYSQLD, "$mysqld --verbose --help", 1, 1);
while(<MYSQLD>) {
	s/\r|\n//g;
	if (/^(\S+)\s+current\s+value:\s+(\S*)/) {
		push(@rv, [ $1, $2 ]);
		}
	elsif (/^\-\-\-\-/) {
		$started = 1;
		}
	elsif ($started && /^(\S+)\s+(.*)/) {
		push(@rv, [ $1, $2 eq "(No default value)" ? undef : $2 ]);
		}
	}
close(MYSQL);
return @rv;
}

# list_compatible_formats()
# Returns a list of two-element arrays, containing compatibility format
# codes and descriptions
sub list_compatible_formats
{
return map { [ $_, $text{'compat_'.$_} ] }
	   ( "ansi", "mysql323", "mysql40", "postgresql", "oracle", "mssql",
	     "db2", "maxdb" );
}

# list_compatible_options()
# Returns a list of two-element arrays, containing compatibility options
sub list_compatible_options
{
return map { [ $_, $text{'compat_'.$_} ] }
	   ( "no_key_options", "no_table_options", "no_field_options" );
}

# compression_format(file)
# Returns 0 if uncompressed, 1 for gzip, 2 for compress, 3 for bzip2 or
# 4 for zip
sub compression_format
{
open(BACKUP, $_[0]);
local $two;
read(BACKUP, $two, 2);
close(BACKUP);
return $two eq "\037\213" ? 1 :
       $two eq "\037\235" ? 2 :
       $two eq "PK" ? 4 :
       $two eq "BZ" ? 3 : 0;
}

# backup_database(db, dest-file, compress-mode, drop-flag, where-clause,
#                 charset, &compatible, &only-tables, run-as-user,
#                 single-transaction-flag, quick-flag)
# Backs up a database to the given file, optionally with compression. Returns
# undef on success, or an error message on failure.
sub backup_database
{
local ($db, $file, $compress, $drop, $where, $charset, $compatible,
       $tables, $user, $single, $quick) = @_;
if ($compress == 0) {
	$writer = "cat >".quotemeta($file);
	}
elsif ($compress == 1) {
	$writer = "gzip -c >".quotemeta($file);
	}
elsif ($compress == 2) {
	$writer = "bzip2 -c >".quotemeta($file);
	}
local $dropsql = $drop ? "--add-drop-table" : "";
local $singlesql = $single ? "--single-transaction" : "";
local $quicksql = $quick ? "--quick" : "";
local $wheresql = $where ? "\"--where=$in{'where'}\"" : "";
local $charsetsql = $charset ?
	"--default-character-set=".quotemeta($charset) : "";
local $compatiblesql = @$compatible ?
	"--compatible=".join(",", @$compatible) : "";
local $quotingsql = &supports_quoting() ? "--quote-names" : "";
local $routinessql = &supports_routines() ? "--routines" : "";
local $tablessql = join(" ", map { quotemeta($_) } @$tables);
local $eventssql = &supports_mysqldump_events() ? "--events" : "";
local $gtidsql = "";
eval {
	$main::error_must_die = 1;
	local $d = &execute_sql($master_db, "show variables like 'gtid_mode'");
	if (@{$d->{'data'}} && uc($d->{'data'}->[0]->[1]) eq 'ON' &&
	    $mysql_version >= 5.6) {
		# Add flag to support GTIDs
		$gtidsql = "--set-gtid-purged=OFF";
		}
	};
if ($user && $user ne "root") {
	# Actual writing of output is done as another user
	$writer = &command_as_user($user, undef, $writer);
	}
local $cmd = "$config{'mysqldump'} $authstr $dropsql $singlesql $quicksql $wheresql $charsetsql $compatiblesql $quotingsql $routinessql ".quotemeta($db)." $tablessql $eventssql $gtidsql | $writer";
if (&shell_is_bash()) {
	$cmd = "set -o pipefail ; $cmd";
	}
local $out = &backquote_logged("($cmd) 2>&1");
if ($? || !-s $file) {
	return $out;
	}
return undef;
}

# delete_database_backup_job(db)
# If there is a backup scheduled for some database, remove it
sub delete_database_backup_job
{
my ($db) = @_;
&foreign_require("cron");
my @jobs = &cron::list_cron_jobs();
my $cmd = "$cron_cmd $db";
my ($job) = grep { $_->{'command'} eq $cmd } @jobs;
if ($job) {
	&lock_file(&cron::cron_file($job));
	&cron::delete_cron_job($job);
	&unlock_file(&cron::cron_file($job));
	}
}

# get_all_mysqld_files()
# Returns all config files used by MySQLd
sub get_all_mysqld_files
{
my $conf = &get_mysql_config();
return &unique(map { $_->{'file'} } @$conf);
}

1;

