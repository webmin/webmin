# query-monitor.pl
# Try an SQL query on a MySQL or PostgreSQL server

sub get_query_status
{
# Load the driver
local $drh;
eval <<EOF;
use DBI;
\$drh = DBI->install_driver(\$_[0]->{'driver'});
EOF
if ($@) {
	return { 'up' => -1,
		 'desc' => &text('query_edriver',
				 "<tt>DBD::$_[0]->{'driver'}</tt>") };
	}

# Connect to the database server
local $dbistr = &make_dbistr($_[0]->{'driver'}, $_[0]->{'db'}, $_[0]->{'host'});
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

sub show_query_dialog
{
print &ui_table_row($text{'query_driver'},
	&ui_select("driver", $_[0]->{'driver'},
		   [ [ "mysql", "MySQL" ],
		     [ "Pg", "PostgreSQL" ],
		     [ "Oracle", "Oracle" ] ]));

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

sub parse_query_dialog
{
eval "use DBD::$in{'driver'}";
&error(&text('query_edriver', "<tt>DBD::$in{'driver'}</tt>")) if ($@);
$_[0]->{'driver'} = $in{'driver'};

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

sub make_dbistr
{
local ($driver, $db, $host) = @_;
local $rv;
if ($driver eq "mysql") {
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


