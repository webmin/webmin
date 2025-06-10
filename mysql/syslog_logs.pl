# Contains a function to supply the syslog module with extra logs

require 'mysql-lib.pl';

# syslog_getlogs()
# Returns a list of structures containing extra log files known to this module
sub syslog_getlogs
{
my $conf = &get_mysql_config();
my ($mysqld) = grep { $_->{'name'} eq 'mysqld_safe' ||
		         $_->{'name'} eq 'safe_mysqld' } @$conf;
my ($mariadb) = grep { $_->{'name'} eq 'mariadb' } @$conf;
my @rv;

# Find the error log
my $log;
if ($mysqld) {
	$log = &find_value("err-log", $mysqld->{'members'});
	}
if ($mariadb && !$log) {
	$log = &find_value("log_error", $mariadb->{'members'});
	if ($log !~ /^\//) {
		my $datadir = $mysqld ?
			&find_value("datadir", $mysqld->{'members'}) : undef;
		if ($datadir) {
			$log = $datadir."/".$log;
			}
		else {
			$log = undef;
			}
		}
	}
if ($log) {
	push(@rv, { 'file' => $log,
		    'desc' => $text{'syslog_desc'},
		    'active' => 1,
		  } );
	}

# Find the query log
my $qlog;
if ($mysqld) {
	$qlog = &find_value("log", $mysqld->{'members'});
	}
if ($qlog) {
	push(@rv, { 'file' => $qlog,
		    'desc' => $text{'syslog_logdesc'},
		    'active' => 1,
		  } );
	}
return @rv;
}

