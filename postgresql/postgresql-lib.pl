# postgresql-lib.pl
# Common PostgreSQL functions
# XXX updating date field

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
do 'view-lib.pl';
if ($config{'plib'}) {
	$ENV{$gconfig{'ld_env'}} .= ':' if ($ENV{$gconfig{'ld_env'}});
	$ENV{$gconfig{'ld_env'}} .= $config{'plib'};
	}
if ($config{'psql'} =~ /^(.*)\/bin\/psql$/ && $1 ne '' && $1 ne '/usr') {
	$ENV{$gconfig{'ld_env'}} .= ':' if ($ENV{$gconfig{'ld_env'}});
	$ENV{$gconfig{'ld_env'}} .= "$1/lib";
	}
$pg_shadow_cols = "usename,usesysid,usecreatedb,usesuper,usecatupd,passwd,valuntil";

if ($module_info{'usermin'}) {
	# Login and password is set by user in Usermin, and the module always
	# runs as the Usermin user
	&switch_to_remote_user();
	&create_user_config_dirs();
	$postgres_login = $userconfig{'login'};
	$postgres_pass = $userconfig{'pass'};
	$postgres_sameunix = 0;
	%access = ( 'backup' => 1,
		    'restore' => 1,
		    'tables' => 1,
		    'cmds' => 1, );
	$max_dbs = $userconfig{'max_dbs'};
	$commands_file = "$user_module_config_directory/commands";
	%displayconfig = %userconfig;
	}
else {
	# Login and password is determined by ACL in Webmin
	%access = &get_module_acl();
	if ($access{'user'} && !$use_global_login) {
		$postgres_login = $access{'user'};
		$postgres_pass = $access{'pass'};
		$postgres_sameunix = $access{'sameunix'};
		}
	else {
		$postgres_login = $config{'login'};
		$postgres_pass = $config{'pass'};
		$postgres_sameunix = $config{'sameunix'};
		}
	$max_dbs = $config{'max_dbs'};
	$commands_file = "$module_config_directory/commands";
	%displayconfig = %config;
	}
foreach my $hba (split(/\t+/, $config{'hba_conf'})) {
	if ($hba =~ /\*|\?/) {
		($hba) = glob($hba);
		}
	if ($hba && -r $hba) {
		$hba_conf_file = $hba;
		last;
		}
	}
$cron_cmd = "$module_config_directory/backup.pl";

if (!$config{'nodbi'}) {
	# Check if we have DBD::Pg
	eval <<EOF;
use DBI;
\$driver_handle = DBI->install_driver("Pg");
EOF
	}

# is_postgresql_running()
# Returns 1 if yes, 0 if no, -1 if the login is invalid, -2 if there
# is a library problem. When called in an array context, returns the full error
# message too.
sub is_postgresql_running
{
local $temp = &transname();
local $host = $config{'host'} ? "-h $config{'host'}" : "";
$host .= " -p $config{'port'}" if ($config{'port'});
local $cmd = &quote_path($config{'psql'}).
	     (!&supports_pgpass() ? " -u" : " -U $postgres_login").
	     " -c '' $host $config{'basedb'}";
if ($postgres_sameunix && defined(getpwnam($postgres_login))) {
	$cmd = "su $postgres_login -c ".quotemeta($cmd);
	}
$cmd = &command_with_login($cmd);
if (&foreign_check("proc")) {
	&foreign_require("proc", "proc-lib.pl");
	if (defined(&proc::close_controlling_pty)) {
		# Detach from tty if possible, so that the psql
		# command doesn't prompt for a login
		&proc::close_controlling_pty();
		}
	}
open(OUT, "$cmd 2>&1 |");
while(<OUT>) { $out .= $_; }
close(OUT);
unlink($temp);
local $rv;
if ($out =~ /setuserid:/i || $out =~ /no\s+password\s+supplied/i ||
    $out =~ /no\s+postgres\s+username/i || $out =~ /authentication\s+failed/i ||
    $out =~ /password:.*password:/i || $out =~ /database.*does.*not/i ||
    $out =~ /user.*does.*not/i) {
	$rv = -1;
	}
elsif ($out =~ /connect.*failed/i || $out =~ /could not connect to server:/) {
	$rv = 0;
	}
elsif ($out =~ /lib\S+\.so/i) {
	$rv = -2;
	}
else {
	$rv = 1;
	}
return wantarray ? ($rv, $out) : $rv;
}

# get_postgresql_version([from-command])
sub get_postgresql_version
{
local ($fromcmd) = @_;
local $main::error_must_die = 1;
return $postgresql_version_cache if (defined($postgresql_version_cache));
local $rv;
if (!$fromcmd) {
	eval {
		local $v = &execute_sql_safe($config{'basedb'},
					     'select version()');
		$v = $v->{'data'}->[0]->[0];
		if ($v =~ /postgresql\s+([0-9\.]+)/i) {
			$rv = $1;
			}
		};
	}
if (!$rv || $@) {
	local $out = &backquote_command(&quote_path($config{'psql'})." -V 2>&1 <$null_file");
	$rv = $out =~ /\s([0-9\.]+)/ ? $1 : undef;
	}
$postgresql_version_cache = $rv;
return $rv;
}

sub can_drop_fields
{
return &get_postgresql_version() >= 7.3;
}

# list_databases()
# Returns a list of all databases
sub list_databases
{
local $force_nodbi = 1;
local $t = &execute_sql_safe($config{'basedb'}, 'select * from pg_database order by datname');
return sort { lc($a) cmp lc($b) } map { $_->[0] } @{$t->{'data'}};
}

# supports_schemas(database)
# Returns 1 if schemas are supported
sub supports_schemas
{
local $t = &execute_sql_safe($_[0], "select a.attname FROM pg_class c, pg_attribute a, pg_type t WHERE c.relname = 'pg_tables' and a.attnum > 0 and a.attrelid = c.oid and a.atttypid = t.oid and a.attname = 'schemaname' order by attnum");
return $t->{'data'}->[0]->[0] ? 1 : 0;
}

# list_tables(database)
# Returns a list of tables in some database
sub list_tables
{
if (&supports_schemas($_[0])) {
	local $t = &execute_sql_safe($_[0], 'select schemaname,tablename from pg_tables order by tablename');
	return map { ($_->[0] eq "public" ? "" : $_->[0].".").$_->[1] }
		   grep { $_->[1] !~ /^(pg|sql)_/ } @{$t->{'data'}};
	}
else {
	local $t = &execute_sql_safe($_[0], 'select tablename from pg_tables order by tablename');
	return map { $_->[0] } grep { $_->[0] !~ /^(pg|sql)_/ } @{$t->{'data'}};
	}
}

# list_types()
# Returns a list of all available field types
sub list_types
{
local $t = &execute_sql_safe($config{'basedb'}, 'select typname from pg_type where typrelid = 0 and typname !~ \'^_.*\' order by typname');
local @types = map { $_->[0] } @{$t->{'data'}};
push(@types, "serial", "bigserial") if (&get_postgresql_version() >= 7.4);
return sort { $a cmp $b } &unique(@types);
}

# table_structure(database, table)
# Returns a list of hashes detailing the structure of a table
sub table_structure
{
if (&supports_schemas($_[0])) {
	# Find the schema and table
	local ($tn, $ns);
	if ($_[1] =~ /^(\S+)\.(\S+)$/) {
		$ns = $1;
		$tn = $2;
		}
	else {
		$ns = "public";
		$tn = $_[1];
		}
	$tn =~ s/^([^\.]+)\.//;
	local $t = &execute_sql_safe($_[0], "select a.attnum, a.attname, t.typname, a.attlen, a.atttypmod, a.attnotnull, a.atthasdef FROM pg_class c, pg_attribute a, pg_type t, pg_namespace ns WHERE c.relname = '$tn' and ns.nspname = '$ns' and a.attnum > 0 and a.attrelid = c.oid and a.atttypid = t.oid and a.attname not like '%pg.dropped%' and c.relnamespace = ns.oid order by attnum");
	local (@rv, $r);
	foreach $r (@{$t->{'data'}}) {
		local $arr;
		$arr++ if ($r->[2] =~ s/^_//);
		local $sz = $r->[4] - 4;
		if ($sz >= 65536 && $r->[2] =~ /numeric/i) {
			$sz = int($sz/65536).",".($sz%65536);
			}
		push(@rv, { 'field' => $r->[1],
			    'arr' => $arr ? 'YES' : 'NO',
			    'type' => $r->[4] < 0 ? $r->[2]
						  : $r->[2]."($sz)",
			    'null' => $r->[5] =~ /f|0/ ? 'YES' : 'NO' } );
		}

	# Work out which fields are the primary key
	if (&supports_indexes()) {
		local ($keyidx) = grep { $_ eq $_[1]."_pkey" ||
					 $_ eq "pk_".$_[1] }
				       &list_indexes($_[0]);
		if ($keyidx) {
			local $istr = &index_structure($_[0], $keyidx);
			foreach my $r (@rv) {
				if (&indexof($r->{'field'},
					     @{$istr->{'cols'}}) >= 0) {
					$r->{'key'} = 'PRI';
					}
				}
			}
		}

	return @rv;
	}
else {
	# Just look by table name
	local $t = &execute_sql_safe($_[0], "select a.attnum, a.attname, t.typname, a.attlen, a.atttypmod, a.attnotnull, a.atthasdef FROM pg_class c, pg_attribute a, pg_type t WHERE c.relname = '$_[1]' and a.attnum > 0 and a.attrelid = c.oid     and a.atttypid = t.oid order by attnum");
	local (@rv, $r);
	foreach $r (@{$t->{'data'}}) {
		local $arr;
		$arr++ if ($r->[2] =~ s/^_//);
		local $sz = $r->[4] - 4;
		if ($sz >= 65536 && $r->[2] =~ /numeric/i) {
			$sz = int($sz/65536).",".($sz%65536);
			}
		push(@rv, { 'field' => $r->[1],
			    'arr' => $arr ? 'YES' : 'NO',
			    'type' => $r->[4] < 0 ? $r->[2]
						  : $r->[2]."($sz)",
			    'null' => $r->[5] =~ /f|0/ ? 'YES' : 'NO' } );
		}
	return @rv;
	}
}

# execute_sql(database, sql, [param, ...])
sub execute_sql
{
if (&is_readonly_mode()) {
	return { };
	}
&execute_sql_safe(@_);
}

# execute_sql_safe(database, sql, [param, ...])
sub execute_sql_safe
{
local $sql = $_[1];
local @params = @_[2..$#_];
if ($gconfig{'debug_what_sql'}) {
	# Write to Webmin debug log
	local $params;
	for(my $i=0; $i<@params; $i++) {
		$params .= " ".$i."=".$params[$i];
		}
	&webmin_debug_log('SQL', "db=$_[0] sql=$sql".$params);
	}
if ($sql !~ /^\s*\\/ && !$main::disable_postgresql_escaping) {
	$sql =~ s/\\/\\\\/g;
	}
if ($driver_handle &&
    $sql !~ /^\s*(create|drop)\s+database/ && $sql !~ /^\s*\\/ &&
    !$force_nodbi) {
	# Use the DBI interface
	local $pid;
	local $cstr = "dbname=$_[0]";
	$cstr .= ";host=$config{'host'}" if ($config{'host'});
	$cstr .= ";port=$config{'port'}" if ($config{'port'});
	local @uinfo;
	if ($postgres_sameunix &&
	    (@uinfo = getpwnam($postgres_login))) {
		# DBI call which must run in subprocess
		pipe(OUTr, OUTw);
		if (!($pid = fork())) {
			&switch_to_unix_user(\@uinfo);
			close(OUTr);
			local $dbh = $driver_handle->connect($cstr,
					$postgres_login, $postgres_pass);
			if (!$dbh) {
				print OUTw &serialise_variable(
				    "DBI connect failed : ".$DBI::errstr);
				exit(0);
				}
			$dbh->{'AutoCommit'} = 0;
			local $cmd = $dbh->prepare($sql);
			#foreach (@params) {	# XXX dbd quoting is broken!
			#	s/\\/\\\\/g;
			#	}
			if (!$cmd->execute(@params)) {
				print OUTw &serialise_variable(&text('esql',
				    "<tt>".&html_escape($sql)."</tt>",
				    "<tt>".&html_escape($dbh->errstr)."</tt>"));
				$dbh->disconnect();
				exit(0);
				}
			local (@data, @row);
			local @titles = @{$cmd->{'NAME'}};
			while(@row = $cmd->fetchrow()) {
				push(@data, [ @row ]);
				}
			$cmd->finish();
			$dbh->commit();
			$dbh->disconnect();
			print OUTw &serialise_variable(
					      { 'titles' => \@titles,
						'data' => \@data });
			exit(0);
			}
		close(OUTw);
		local $line = <OUTr>;
		local $rv = &unserialise_variable($line);
		if (ref($rv)) {
			return $rv;
			}
		else {
			&error($rv || "$sql : Unknown DBI error");
			}
		}
	else {
		# Just normal DBI call
		local $dbh = $driver_handle->connect($cstr,
				$postgres_login, $postgres_pass);
		$dbh || &error("DBI connect failed : ",$DBI::errstr);
		$dbh->{'AutoCommit'} = 0;
		local $cmd = $dbh->prepare($sql);
		if (!$cmd->execute(@params)) {
			&error(&text('esql', "<tt>".&html_escape($sql)."</tt>",
				     "<tt>".&html_escape($dbh->errstr)."</tt>"));
			}
		local (@data, @row);
		local @titles = @{$cmd->{'NAME'}};
		while(@row = $cmd->fetchrow()) {
			push(@data, [ @row ]);
			}
		$cmd->finish();
		$dbh->commit();
		$dbh->disconnect();
		return { 'titles' => \@titles,
			 'data' => \@data };
		}
	}
else {
	# Check for a \ command
        my $break_f = 0 ;
	if ($sql =~ /^\s*\\l\s*$/) {
		# \l command to list encodings needs no special handling
		}
        elsif ($sql =~ /^\s*\\/ ) {
		$break_f = 1 ;
		if ($sql !~ /^\s*\\copy\s+/ &&
                    $sql !~ /^\s*\\i\s+/) {
			&error ( &text ( 'r_command', ) ) ;
			}
		}

	if (@params) {
		# Sub in ? parameters
		local $p;
		local $pos = -1;
		foreach $p (@params) {
			$pos = index($sql, '?', $pos+1);
			&error("Incorrect number of parameters in $_[1] (".scalar(@params).")") if ($pos < 0);
			local $qp = $p;
			if ($qp !~ /^[bB]'\d+'$/) {
				# Quote value, except for bits
				$qp =~ s/\\/\\\\/g;
				$qp =~ s/'/''/g;
				$qp =~ s/\$/\\\$/g;
				$qp =~ s/\n/\\n/g;
				$qp = $qp eq '' ? "NULL" : "'$qp'";
				}
			$sql = substr($sql, 0, $pos).$qp.substr($sql, $pos+1);
			$pos += length($qp)-1;
			}
		}

	# Call the psql program
	local $host = $config{'host'} ? "-h $config{'host'}" : "";
	$host .= " -p $config{'port'}" if ($config{'port'});
	local $cmd = &quote_path($config{'psql'})." --html".
		     (!&supports_pgpass() ? " -u" : " -U $postgres_login").
		     " -c ".&quote_path($sql)." $host $_[0]";
	if ($postgres_sameunix && defined(getpwnam($postgres_login))) {
		$cmd = &command_as_user($postgres_login, 0, $cmd);
		}
	$cmd = &command_with_login($cmd);

	delete($ENV{'LANG'});		# to force output to english
	delete($ENV{'LANGUAGE'});
        if ($break_f == 0) {
		# Running a normal SQL command, not one with a \
		#$ENV{'PAGER'} = "cat";
		if (&foreign_check("proc")) {
			&foreign_require("proc", "proc-lib.pl");
			if (defined(&proc::close_controlling_pty)) {
				# Detach from tty if possible, so that the psql
				# command doesn't prompt for a login
				&proc::close_controlling_pty();
				}
			}
		open(OUT, "$cmd 2>&1 |");
		local ($line, $rv, @data);
		do {
			$line = <OUT>;
			} while($line =~ /^(username|password|user name):/i ||
				$line =~ /(warning|notice):/i ||
			        $line !~ /\S/ && defined($line));
		unlink($temp);
		if ($line =~ /^ERROR:\s+(.*)/ || $line =~ /FATAL.*:\s+(.*)/) {
			&error(&text('esql', "<tt>$sql</tt>", "<tt>$1</tt>"));
			}
		elsif (!defined($line)) {
			# Un-expected end of output ..
			&error(&text('esql', "<tt>$sql</tt>",
				     "<tt>$config{'psql'} failed</tt>"));
			}
		else {
			# Read HTML-format output
			local $row;
			local @data;
			while($line = <OUT>) {
				if ($line =~ /^\s*<tr>/) {
					# Start of a row
					$row = [ ];
					}
				elsif ($line =~ /^\s*<\/tr>/) {
					# End of a row
					push(@data, $row);
					$row = undef;
					}
				elsif ($line =~ /^\s*<(td|th)[^>]*>(.*)<\/(td|th)>/) {
					# Value in a row
					local $v = $2;
					$v =~ s/<br>/\n/g;
					push(@$row, &entities_to_ascii($v));
					}
				}
			$rv = { 'titles' => shift(@data),
				'data' => \@data };
			}
		close(OUT);
		return $rv;
		}
	else {
		# Running a special \ command
		local ( @titles, @row, @data, $rc, $emsgf, $emsg ) ;

		$emsgf = &transname();
		$rc = &system_logged ( "$cmd >$emsgf 2>&1");
		$emsg  = &read_file_contents($emsgf);
		&unlink_file($emsgf) ;
		if ($rc) {
			&error("<pre>$emsg</pre>");
			}
		else {
			@titles = ( "     Command Invocation      " ) ;
			@row    = ( "   Done ( return code : $rc )" ) ;
			map { s/^\s+//; s/\s+$// } @row ;
			push ( @data, \@row ) ;
			return { 'titles' => \@titles, 'data' => \@data } ;
			}
		}
	}
}

# execute_sql_logged(database, command)
sub execute_sql_logged
{
&additional_log('sql', $_[0], $_[1]);
return &execute_sql(@_);
}

sub can_edit_db
{
if ($module_info{'usermin'}) {
	# Check access control list in configuration
	local $rv;
	DB: foreach $l (split(/\t/, $config{'access'})) {
		if ($l =~ /^(\S+):\s*(.*)$/ &&
		    ($1 eq $remote_user || $1 eq '*')) {
			local @dbs = split(/\s+/, $2);
			foreach $d (@dbs) {
				$d =~ s/\$REMOTE_USER/$remote_user/g;
				if ($d eq '*' || $_[0] =~ /^$d$/) {
					$rv = 1;
					last DB;
					}
				}
			$rv = 0;
			last DB;
			}
		}
	if ($rv && $config{'access_own'}) {
		# Check ownership on DB - first get login ID
		if (!defined($postgres_login_id)) {
			local $d = &execute_sql($config{'basedb'}, "select usesysid from pg_user where usename = ?", $postgres_login);
			$postgres_login_id = $d->{'data'}->[0]->[0];
			}
		# Get database owner
		local $d = &execute_sql($config{'basedb'}, "select datdba from pg_database where datname = ?", $_[0]);
		if ($d->{'data'}->[0]->[0] != $postgres_login_id) {
			$rv = 0;
			}
		}
	return $rv;
	}
else {
	# Check Webmin ACL
	local $d;
	return 1 if ($access{'dbs'} eq '*');
	foreach $d (split(/\s+/, $access{'dbs'})) {
		return 1 if ($d && $d eq $_[0]);
		}
	return 0;
	}
}

# get_hba_config(version)
# Parses the postgres host access config file
sub get_hba_config
{
local $lnum = 0;
open(HBA, $hba_conf_file);
while(<HBA>) {
	s/\r|\n//g;
	s/^\s*#.*$//g;
	if ($_[0] >= 7.3) {
		# New file format
		if (/^\s*(host|hostssl)\s+(\S+)\s+(\S+)\s+(\S+)\/(\S+)\s+(\S+)(\s+(\S+))?/) {
			# Host/cidr format
			push(@rv, { 'type' => $1,
				    'index' => scalar(@rv),
				    'line' => $lnum,
				    'db' => $2,
				    'user' => $3,
				    'address' => $4,
				    'cidr' => $5,
				    'auth' => $6,
				    'arg' => $8 } );
			}
		elsif (/^\s*(host|hostssl)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)(\s+(\S+))?/) {
			# Host netmask format
			push(@rv, { 'type' => $1,
				    'index' => scalar(@rv),
				    'line' => $lnum,
				    'db' => $2,
				    'user' => $3,
				    'address' => $4,
				    'netmask' => $5,
				    'auth' => $6,
				    'arg' => $8 } );
			}
		elsif (/^\s*local\s+(\S+)\s+(\S+)\s+(\S+)(\s+(\S+))?/) {
			push(@rv, { 'type' => 'local',
				    'index' => scalar(@rv),
				    'line' => $lnum,
				    'db' => $1,
				    'user' => $2,
				    'auth' => $3,
				    'arg' => $5 } );
			}
		}
	else {
		# Old file format
		if (/^\s*host\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)(\s+(\S+))?/) {
			push(@rv, { 'type' => 'host',
				    'index' => scalar(@rv),
				    'line' => $lnum,
				    'db' => $1,
				    'address' => $2,
				    'netmask' => $3,
				    'auth' => $4,
				    'arg' => $6 } );
			}
		elsif (/^\s*local\s+(\S+)\s+(\S+)(\s+(\S+))?/) {
			push(@rv, { 'type' => 'local',
				    'index' => scalar(@rv),
				    'line' => $lnum,
				    'db' => $1,
				    'auth' => $2,
				    'arg' => $4 } );
			}
		}
	$lnum++;
	}
close(HBA);
return @rv;
}

# create_hba(&hba, version)
sub create_hba
{
local $lref = &read_file_lines($hba_conf_file);
push(@$lref, &hba_line($_[0], $_[1]));
&flush_file_lines();
}

# delete_hba(&hba, version)
sub delete_hba
{
local $lref = &read_file_lines($hba_conf_file);
splice(@$lref, $_[0]->{'line'}, 1);
&flush_file_lines();
}

# modify_hba(&hba, version)
sub modify_hba
{
local $lref = &read_file_lines($hba_conf_file);
splice(@$lref, $_[0]->{'line'}, 1, &hba_line($_[0], $_[1]));
&flush_file_lines();
}

# swap_hba(&hba1, &hba2)
sub swap_hba
{
local $lref = &read_file_lines($hba_conf_file);
local $line0 = $lref->[$_[0]->{'line'}];
local $line1 = $lref->[$_[1]->{'line'}];
$lref->[$_[1]->{'line'}] = $line0;
$lref->[$_[0]->{'line'}] = $line1;
&flush_file_lines();
}

# hba_line(&hba, version)
sub hba_line
{
if ($_[0]->{'type'} eq 'host' || $_[0]->{'type'} eq 'hostssl') {
	return join(" ", $_[0]->{'type'}, $_[0]->{'db'},
			 ( $_[1] >= 7.3 ? ( $_[0]->{'user'} ) : ( ) ),
			 ($_[0]->{'cidr'} eq '' ? 
				 ( $_[0]->{'address'},
				   $_[0]->{'netmask'} ) :
				 ( "$_[0]->{'address'}/$_[0]->{'cidr'}" )),
			 $_[0]->{'auth'},
			 $_[0]->{'arg'} ? ( $_[0]->{'arg'} ) : () );
	}
else {
	return join(" ", 'local', $_[0]->{'db'},
			 ( $_[1] >= 7.3 ? ( $_[0]->{'user'} ) : ( ) ),
			 $_[0]->{'auth'},
			 $_[0]->{'arg'} ? ( $_[0]->{'arg'} ) : () );
	}
}

# split_array(value)
sub split_array
{
if ($_[0] =~ /^\{(.*)\}$/) {
	local @a = split(/,/, $1);
	return @a;
	}
else {
	return ( $_[0] );
	}
}

# join_array(values ..)
sub join_array
{
local $alpha;
map { $alpha++ if (!/^-?[0-9\.]+/) } @_;
return $alpha ? '{'.join(',', map { "'$_'" } @_).'}'
	      : '{'.join(',', @_).'}';
}

sub is_blob
{
return $_[0]->{'type'} eq 'text' || $_[0]->{'type'} eq 'bytea';
}

# restart_postgresql()
# HUP postmaster if running, so that hosts file changes take effect
sub restart_postgresql
{
foreach my $pidfile (glob($config{'pid_file'})) {
	local $pid = &check_pid_file($pidfile);
	if ($pid) {
		&kill_logged('HUP', $pid);
		}
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

# make_backup_dir(directory)
# Create a directory that PostgreSQL can backup into
sub make_backup_dir
{
local ($dir) = @_;
if (!-d $dir) {
	&make_dir($dir, 0755);
	if ($postgres_sameunix && defined(getpwnam($postgres_login))) {
		&set_ownership_permissions($postgres_login, undef, undef, $dir);
		}
	}
}

sub quote_table
{
local @tn = split(/\./, $_[0]);
return join(".", map { "\"$_\"" } @tn);
}

sub quotestr
{
return "\"$_[0]\"";
}

# execute_sql_file(database, file, [user, pass], [unix-user])
# Executes some file of SQL statements, and returns the exit status and output
sub execute_sql_file
{
local ($db, $file, $user, $pass, $unixuser) = @_;
if (&is_readonly_mode()) {
	return (0, undef);
	}
if (!defined($user)) {
	$user = $postgres_login;
	$pass = $postgres_pass;
	}
local $cmd = &quote_path($config{'psql'})." -f ".&quote_path($file).
	     (&supports_pgpass() ? " -U $user" : " -u").
	     ($config{'host'} ? " -h $config{'host'}" : "").
	     ($config{'port'} ? " -h $config{'port'}" : "").
	     " $db";
if ($postgres_sameunix && defined(getpwnam($postgres_login))) {
	$cmd = &command_as_user($postgres_login, 0, $cmd);
	}
elsif ($unixuser && $unixuser ne 'root' && $< == 0) {
	$cmd = &command_as_user($unixuser, 0, $cmd);
	}
$cmd = &command_with_login($cmd, $user, $pass);
local $out = &backquote_logged("$cmd 2>&1");
return ($out =~ /ERROR/i ? 1 : 0, $out);
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

# accepting_connections(db)
# Returns 1 if some database is accepting connections, 0 if not
sub accepting_connections
{
if (!defined($has_connections)) {
	$has_connections = 0;
	local @str = &table_structure($config{'basedb'},
				      "pg_catalog.pg_database");
	foreach my $f (@str) {
		$has_connections = 1 if ($f->{'field'} eq 'datallowconn');
		}
	}
if ($has_connections) {
	$rv = &execute_sql_safe($config{'basedb'}, "select datallowconn from pg_database where datname = '$_[0]'");
	if ($rv->{'data'}->[0]->[0] !~ /^(t|1)/i) {
		return 0;
		}
	}
return 1;
}

# start_postgresql()
# Starts the PostgreSQL database server. Returns an error message on failure
# or undef on success.
sub start_postgresql
{
if ($gconfig{'os_type'} eq 'windows' && &foreign_check("init")) {
	# On Windows, always try to sc start the pgsql- service
	&foreign_require("init", "init-lib.pl");
	local ($pg) = grep { $_->{'name'} =~ /^pgsql-/ }
			   &init::list_win32_services();
	if ($pg) {
		return &init::start_win32_service($pg->{'name'});
		}
	}
local $temp = &transname();
local $rv = &system_logged("($config{'start_cmd'}) >$temp 2>&1");
local $out = `cat $temp`; unlink($temp);
unlink($temp);
if ($rv || $out =~ /failed|error/i) {
	return "<pre>$out</pre>";
	}
return undef;
}

# stop_postgresql()
# Stops the PostgreSQL database server. Returns an error message on failure
# or undef on success.
sub stop_postgresql
{
if ($gconfig{'os_type'} eq 'windows' && &foreign_check("init")) {
	# On Windows, always try to sc stop the pgsql- service
	&foreign_require("init", "init-lib.pl");
	local ($pg) = grep { $_->{'name'} =~ /^pgsql-/ }
			   &init::list_win32_services();
	if ($pg) {
		return &init::stop_win32_service($pg->{'name'});
		}
	}
if ($config{'stop_cmd'}) {
	local $out = &backquote_logged("$config{'stop_cmd'} 2>&1");
	if ($? || $out =~ /failed|error/i) {
		return "<pre>$?\n$out</pre>";
		}
	}
else {
	local $pidcount = 0;
	foreach my $pidfile (glob($config{'pid_file'})) {
		local $pid = &check_pid_file($pidfile);
		if ($pid) {
			&kill_logged('TERM', $pid) ||
				return &text('stop_ekill', "<tt>$pid</tt>",
					     "<tt>$!</tt>");
			$pidcount++;
			}
		}
	$pidcount || return &text('stop_epidfile',
				  "<tt>$config{'pid_file'}</tt>");
	}
return undef;
}

# setup_postgresql()
# Performs initial postgreSQL configuration. Returns an error message on failure
# or undef on success.
sub setup_postgresql
{
return undef if (!$config{'setup_cmd'});
local $temp = &transname();
local $rv = &system_logged("($config{'setup_cmd'}) >$temp 2>&1");
local $out = `cat $temp`;
unlink($temp);
if ($rv) {
	return "<pre>$out</pre>";
	}
return undef;
}

# list_indexes(db)
# Returns the names of all indexes in some database
sub list_indexes
{
local ($db) = @_;
local (@rv, $r);
local %tables = map { $_, 1 } &list_tables($db);
if (&supports_schemas($db)) {
	local $t = &execute_sql_safe($db, "select schemaname,indexname,tablename from pg_indexes");
	return map { ($_->[0] eq "public" ? "" : $_->[0].".").$_->[1] }
		grep { $tables{($_->[0] eq "public" ? "" : $_->[0].".").$_->[2]} }
		   @{$t->{'data'}};
	}
else {
	local $t = &execute_sql_safe($db, "select indexname,tablename from pg_indexes");
	return map { $_->[0] } grep { $tables{$t->[1]} } @{$t->{'data'}};
	}
}

# index_structure(db, indexname)
# Returns information on an index
sub index_structure
{
local ($db, $index) = @_;
local $info = { 'name' => $index };
if (&supports_schemas($db)) {
	local ($sn, $in);
	if ($index =~ /^(\S+)\.(\S+)$/) {
		($sn, $in) = ($1, $2);
		}
	else {
		($sn, $in) = ("public", $index);
		}
	local $t = &execute_sql_safe($db, "select schemaname,tablename,indexdef from pg_indexes where indexname = '$in' and schemaname = '$sn'");
	local $r = $t->{'data'}->[0];
	if ($r->[0] eq "public") {
		$info->{'table'} = $r->[1];
		}
	else {
		$info->{'table'} = $r->[0].".".$r->[1];
		}
	$info->{'create'} = $r->[2];
	}
else {
	local $t = &execute_sql_safe($db, "select tablename,indexdef from pg_indexes where indexname = '$index'");
	local $r = $t->{'data'}->[0];
	$info->{'table'} = $r->[0];
	$info->{'create'} = $r->[1];
	}

# Parse create expression
if ($info->{'create'} =~ /^create\s+unique/i) {
	$info->{'type'} = 'unique';
	}
if ($info->{'create'} =~ /using\s+(\S+)\s/) {
	$info->{'using'} = lc($1);
	}
if ($info->{'create'} =~ /\((.*)\)/) {
	$info->{'cols'} = [ split(/\s*,\s*/, $1) ];
	}

return $info;
}

sub supports_indexes
{
return &get_postgresql_version() >= 7.3;
}

# list_views(db)
# Returns the names of all views in some database
sub list_views
{
local ($db) = @_;
local (@rv, $r);
if (&supports_schemas($db)) {
	local $t = &execute_sql_safe($db, "select schemaname,viewname from pg_views where schemaname != 'pg_catalog' and schemaname != 'information_schema'");
	return map { ($_->[0] eq "public" ? "" : $_->[0].".").$_->[1] }
		   @{$t->{'data'}};
	}
else {
	local $t = &execute_sql_safe($db, "select viewname from pg_indexes");
	return map { $_->[0] } @{$t->{'data'}};
	}
}

# view_structure(db, viewname)
# Returns information about a view
sub view_structure
{
local ($db, $view) = @_;
local $info = { 'name' => $view };
if (&supports_schemas($db)) {
	local ($sn, $in);
	if ($view =~ /^(\S+)\.(\S+)$/) {
		($sn, $in) = ($1, $2);
		}
	else {
		($sn, $in) = ("public", $view);
		}
	local $t = &execute_sql_safe($db, "select schemaname,viewname,definition from pg_views where viewname = '$in' and schemaname = '$sn'");
	local $r = $t->{'data'}->[0];
	$info->{'query'} = $r->[2];
	}
else {
	local $t = &execute_sql_safe($db, "select viewname,definition from pg_views where viewname = '$index'");
	local $r = $t->{'data'}->[0];
	$info->{'query'} = $r->[1];
	}

$info->{'query'} =~ s/;$//;

return $info;
}

sub supports_views
{
return &get_postgresql_version() >= 7.3;
}

# list_sequences(db)
# Returns the names of all sequences in some database
sub list_sequences
{
local ($db) = @_;
local (@rv, $r);
if (&supports_schemas($db)) {
	local $t = &execute_sql_safe($db, "select schemaname,relname from pg_statio_user_sequences");
	return map { ($_->[0] eq "public" ? "" : $_->[0].".").$_->[1] }
		   @{$t->{'data'}};
	}
else {
	local $t = &execute_sql_safe($db, "select relname from pg_statio_user_sequences");
	return map { $_->[0] } @{$t->{'data'}};
	}
}

# sequence_structure(db, name)
# Returns details of a sequence
sub sequence_structure
{
local ($db, $seq) = @_;
local $info = { 'name' => $seq };

local $t = &execute_sql_safe($db, "select * from ".&quote_table($seq));
local $r = $t->{'data'}->[0];
local $i = 0;
foreach my $c (@{$t->{'titles'}}) {
	$info->{$c} = $r->[$i++];
	}

return $info;
}

sub supports_sequences
{
return &get_postgresql_version() >= 7.4 ? 1 :
       &get_postgresql_version() >= 7.3 ? 2 : 0;
}

# Returns 1 if the postgresql server being managed is on this system
sub is_postgresql_local
{
return $config{'host'} eq '' || $config{'host'} eq 'localhost' ||
       $config{'host'} eq &get_system_hostname() ||
       &to_ipaddress($config{'host'}) eq &to_ipaddress(&get_system_hostname());
}

# backup_database(database, dest-path, format, [&only-tables], [run-as-user])
# Executes the pg_dump command to backup the specified database to the
# given destination path. Returns undef on success, or an error message
# on failure.
sub backup_database
{
local ($db, $path, $format, $tables, $user) = @_;
local $tablesarg = join(" ", map { " -t ".quotemeta($_) } @$tables);
local $cmd = &quote_path($config{'dump_cmd'}).
	     (!$postgres_login ? "" :
	      &supports_pgpass() ? " -U $postgres_login" : " -u").
	     ($config{'host'} ? " -h $config{'host'}" : "").
	     ($config{'port'} ? " -p $config{'port'}" : "").
	     ($format eq 'p' ? "" : " -b").
	     $tablesarg.
	     " -F$format -f ".&quote_path($path)." $db";
if ($postgres_sameunix && defined(getpwnam($postgres_login))) {
	# Postgres connections have to be made as the 'postgres' Unix user
	$cmd = &command_as_user($postgres_login, 0, $cmd);
	}
elsif ($user) {
	# Run as a specific Unix user
	$cmd = &command_as_user($user, 0, $cmd);
	}
$cmd = &command_with_login($cmd);
local $out = &backquote_logged("$cmd 2>&1");
if ($? || $out =~ /could not|error|failed/i) {
	return $out;
	}
return undef;
}

# restore_database(database, source-path, only-data, clear-db, [&only-tables])
# Restores the contents of a PostgreSQL backup into the specified database.
# Returns undef on success, or an error message on failure.
sub restore_database
{
local ($db, $path, $only, $clean, $tables) = @_;
local $tablesarg = join(" ", map { " -t ".quotemeta($_) } @$tables);
local $cmd = &quote_path($config{'rstr_cmd'}).
	     (!$postgres_login ? "" :
	      &supports_pgpass() ? " -U $postgres_login" : " -u").
	     ($config{'host'} ? " -h $config{'host'}" : "").
	     ($config{'port'} ? " -p $config{'port'}" : "").
	     ($only ? " -a" : "").
	     ($clean ? " -c" : "").
	     $tablesarg.
	     " -d $db ".&quote_path($path);
if ($postgres_sameunix && defined(getpwnam($postgres_login))) {
	$cmd = &command_as_user($postgres_login, 0, $cmd);
	}
$cmd = &command_with_login($cmd);
local $out = &backquote_logged("$cmd 2>&1");
if ($? || $out =~ /could not|error|failed/i) {
	return $out;
	}
return undef;
}

# PostgreSQL versions below 7.3 don't support .pgpass, and version 8.0.*
# don't allow it to be located via $HOME or $PGPASSFILE.
sub supports_pgpass
{
local $ver = &get_postgresql_version(1);
return $ver >= 7.3 && $ver < 8.0 ||
       $ver >= 8.1;
}

# command_with_login(command, [user, pass])
# Given a command that talks to postgresql (like psql or pg_dump), sets up
# the environment so that it can login to the database. Returns a modified
# command to execute.
sub command_with_login
{
local ($cmd, $user, $pass) = @_;
if (!defined($user)) {
	$user = $postgres_login;
	$pass = $postgres_pass;
	}
local $loginfile;
if (&supports_pgpass()) {
	# Can use .pgpass file
	local $pgpass;
	if ($gconfig{'os_type'} eq 'windows') {
		# On Windows, the file is under ~/application data
		local $appdata = "$ENV{'HOME'}/application data";
		&make_dir($appdata, 0755);
		local $postgresql = "$appdata/postgresql";
		&make_dir($postgresql, 0755);
		$pgpass = "$postgresql/pgpass.conf";
		}
	else {
		local $temphome = &transname();
		&make_dir($temphome, 0755);
		$pgpass = "$temphome/.pgpass";
		push(@main::temporary_files, $pgpass);
		$ENV{'HOME'} = $temphome;
		}
	$ENV{'PGPASSFILE'} = $pgpass;
	open(PGPASS, ">$pgpass");
	print PGPASS "*:*:*:$user:$pass\n";
	close(PGPASS);
	&set_ownership_permissions(
		$postgres_sameunix ? $user : undef,
		undef, 0600, $pgpass);
	}
else {
	# Need to put login and password in temp file
	$loginfile = &transname();
	open(TEMP, ">$loginfile");
	print TEMP "$user\n$pass\n";
	close(TEMP);
	$cmd .= " <$loginfile";
	}
return $cmd;
}

# extract_grants(field)
# Given a field from pg_class that contains grants either as a comma-separated
# list or an array, return a list of tuples in user,grant format
sub extract_grants
{
my ($f) = @_;
my @rv;
if (ref($f)) {
	@rv = map { [ split(/=/, $_, 2) ] } @$f;
	}
else {
	$f =~ s/^\{//;
	$f =~ s/\}$//;
	@rv = map { [ split(/=/, $_, 2) ] } map { s/\\"/"/g; s/"//g; $_ } grep { /=\S/ } split(/,/, $f);
	}
return @rv;
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

# get_pg_shadow_table()
# Returns the table containing users, and the list of columns (comma-separated)
sub get_pg_shadow_table
{
if (&get_postgresql_version() >= 9.5) {
	my $cols = $pg_shadow_cols;
	$cols =~ s/usecatupd/'t'/g;
	return ("pg_user", $cols);
	}
elsif (&get_postgresql_version() >= 9.4) {
	return ("pg_user", $pg_shadow_cols);
	}
else {
	return ("pg_shadow", $pg_shadow_cols);
	}
}

1;

