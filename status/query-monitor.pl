# query-monitor.pl
# Try an SQL query on a database server

# SQL drivers offered in the UI and permitted by strict validation.
my @query_driver_options = (
	[ "mysql", "MySQL" ],
	[ "MariaDB", "MariaDB" ],
	[ "Pg", "PostgreSQL" ],
	[ "Oracle", "Oracle" ]
	);
my %allowed_query_drivers = map { $_->[0], 1 } @query_driver_options;

# canonical_query_driver(driver)
# Normalize a stored driver name to the canonical DBI driver key.
sub canonical_query_driver
{
my ($driver) = @_;
# Accept legacy lowercase value while storing/using canonical DBI name.
return $driver eq 'mariadb' ? 'MariaDB' : $driver;
}

# query_driver_candidates(driver)
# Returns preferred and fallback DBI driver names for the selected driver.
sub query_driver_candidates
{
my ($driver) = @_;
$driver = &canonical_query_driver($driver);
# Match mysql/mysql-lib.pl behavior : prefer selected family, then fallback.
return ($driver eq 'mysql') ? ( "mysql", "MariaDB" ) :
       ($driver eq 'MariaDB') ? ( "MariaDB", "mysql" ) :
				( $driver );
}

# get_query_status(&service)
# Attempts DB connect and query execution and returns monitor status hash.
sub get_query_status
{
my $driver = &canonical_query_driver($_[0]->{'driver'});
if (!$allowed_query_drivers{$driver}) {
	return { 'up' => -1,
		 'desc' => &text('query_edriver',
				 "<tt>DBD::$driver</tt>") };
	}

# Load the driver
local $drh;
eval { require DBI; };
if ($@) {
	return { 'up' => -1,
		 'desc' => &text('query_edriver',
				 "<tt>DBD::$driver</tt>") };
	}
my @drivers = &query_driver_candidates($driver);
# Try fallback-compatible drivers to tolerate either DBD::mysql or DBD::MariaDB.
foreach my $try (@drivers) {
	eval { $drh = DBI->install_driver($try); };
	last if (!$@ && $drh);
	}
if (!$drh) {
	return { 'up' => -1,
		 'desc' => &text('query_edriver',
				 "<tt>DBD::$driver</tt>") };
	}

# Connect to the database server
local $dbistr = &make_dbistr($driver, $_[0]->{'db'}, $_[0]->{'host'});
local $dbh = $drh->connect($dbistr,
                           $_[0]->{'user'}, $_[0]->{'pass'}, { });
if (!$dbh) {
	return { 'up' => 0,
		 'desc' => &text('query_elogin', $drh->errstr) };
	}

# Execute the query
local $cmd = $dbh->prepare($_[0]->{'sql'});
if (!$cmd) {
	return { 'up' => 0,
		 'desc' => &text('query_eprepare', $dbh->errstr) };
	}
if (!$cmd->execute()) {
	return { 'up' => 0,
		 'desc' => &text('query_eexecute', $dbh->errstr) };
	}
local @r = $cmd->fetchrow();
$cmd->finish();

if ($_[0]->{'result'} ne '' && $r[0] ne $_[0]->{'result'}) {
	return { 'up' => 0,
		 'desc' => &text('query_ewrong', $r[0]) };
	}

return { 'up' => 1 };
}

# show_query_dialog(&service)
# Displays the SQL query monitor configuration form fields.
sub show_query_dialog
{
print &ui_table_row($text{'query_driver'},
	&ui_select("driver", &canonical_query_driver($_[0]->{'driver'}),
		   \@query_driver_options));

print &ui_table_row($text{'query_db'},
	&ui_textbox("db", $_[0]->{'db'}, 20));

print &ui_table_row($text{'query_user'},
	&ui_textbox("quser", $_[0]->{'user'}, 20));

print &ui_table_row($text{'query_pass'},
	&ui_password("qpass", $_[0]->{'pass'}, 20));

print &ui_table_row($text{'query_host'},
	&ui_opt_textbox("host", $_[0]->{'host'}, 40, $text{'query_local'}), 3);

print &ui_table_row($text{'query_sql'},
	&ui_textbox("sql", $_[0]->{'sql'}, 60), 3);

print &ui_table_row($text{'query_result'},
	&ui_opt_textbox("result", $_[0]->{'result'}, 40,
			$text{'query_ignore'}), 3);
}

# parse_query_dialog(&service)
# Validates query monitor inputs and stores normalized settings.
sub parse_query_dialog
{
my $driver = &canonical_query_driver($in{'driver'});
$allowed_query_drivers{$driver} ||
	&error(&text('query_edriver', "<tt>DBD::$driver</tt>"));
eval { require DBI; };
&error(&text('query_edriver', "<tt>DBD::$driver</tt>")) if ($@);
my $ok;
foreach my $try (&query_driver_candidates($driver)) {
	# Validation mirrors runtime loading : any valid fallback driver is accepted.
	eval { DBI->install_driver($try); };
	if (!$@) {
		$ok = 1;
		last;
		}
	}
&error(&text('query_edriver', "<tt>DBD::$driver</tt>")) if (!$ok);
$_[0]->{'driver'} = $driver;

$in{'db'} =~ /^\S+$/ || &error($text{'query_edb'});
$_[0]->{'db'} = $in{'db'};

if ($in{'host_def'}) {
	delete($_[0]->{'host'});
	}
else {
	&to_ipaddress($in{'host'}) || &to_ip6address($in{'host'}) ||
		&error($text{'query_ehost'});
	$_[0]->{'host'} = $in{'host'};
	}

$in{'quser'} =~ /^\S*$/ || &error($text{'query_euser'});
$_[0]->{'user'} = $in{'quser'};

$in{'qpass'} =~ /^\S*$/ || &error($text{'query_epass'});
$_[0]->{'pass'} = $in{'qpass'};

$in{'sql'} =~ /\S/ || &error($text{'query_esql'});
$_[0]->{'sql'} = $in{'sql'};

if ($in{'result_def'}) {
	delete($_[0]->{'result'});
	}
else {
	$in{'result'} =~ /\S/ || &error($text{'query_eresult'});
	$_[0]->{'result'} = $in{'result'};
	}
}

# make_dbistr(driver, database, host)
# Builds the DBI connection string for the selected SQL driver.
sub make_dbistr
{
local ($driver, $db, $host) = @_;
local $rv;
if ($driver eq "mysql" || $driver eq "MariaDB") {
	# Both DBI drivers use "database=" style DSN here.
	$rv = "database=$db";
	}
elsif ($driver eq "Pg") {
	$rv = "dbname=$db";
	}
else {
	$rv = $db;
	}
if ($host) {
	$rv .= ";host=$host";
	}
return $rv;
}
