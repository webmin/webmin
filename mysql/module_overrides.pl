
do 'mysql-lib.pl';

# Override function to substitute module's name
sub module_overrides
{
my ($rv) = @_;
my $mysql_version;
chop($mysql_version = &read_file_contents(
        "$module_config_directory/version"));
$mysql_version ||= &get_mysql_version();
if ($mysql_version =~ /mariadb/i) {
	foreach my $t (keys %{$rv}) {
		$rv->{$t} =~ s/MySQL/MariaDB/g;
		}
	}
}

1;