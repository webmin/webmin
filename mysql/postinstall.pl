
require 'mysql-lib.pl';

sub module_install
{
my $mysql_version = &get_mysql_version();
if ($mysql_version && $mysql_version >= 0) {
	&save_mysql_version($mysql_version);
	&create_module_info_overrides();
	}

# Check if we have to use a new MariaDB commands
my ($mversion, $mvariant) = &get_remote_mysql_variant();
if (!$config{'mysql_postinstall_config_updated'} &&
    $config{'mysql_postinstall_config_updated'} !~ /\Q$mvariant\E/i) {
	if ($mvariant =~ /mariadb/i) {
		# Switch config to use MariaDB commands
		if (&compare_version_numbers($mversion, "10.5") > 0) {
			my $config_updated;
			foreach my $key (grep { /^mysql(?!_)/ } keys %config) {
				my $cmd = $config{$key};
				next if ($cmd !~ /^\//);
				# Check if symlink
				if (-l $cmd) {
					my $target = readlink($cmd);
					my $dir = $cmd =~ s|/[^/]+$||r;
					if ($target =~ /^mariadb/i) {
						# Update config if symlinked
						# to mariadb
						$config{$key} = "$dir/$target";
						$config_updated++;
						}
					}
				# If command doesn't exist, try mariadb version
				else {
					my $mariadb_cmd = $cmd;
					$mariadb_cmd =~ s/mysql(\w+)/mariadb-$1/;
					if (&has_command($mariadb_cmd)) {
						$config{$key} = $mariadb_cmd;
						$config_updated++;
						}
					}
				}
			if ($config_updated) {
				# Update start stop commands
				foreach my $key ('start_cmd', 'stop_cmd') {
					next if ($config{$key} !~ /systemctl/);
					$config{$key} =~
						s/mysql(?:\.service)?$/mariadb/;
					}
				# Update config file
				$config{'mysql_postinstall_config_updated'} =
					"$mvariant=$mversion";
				&save_module_config();
				}
			}
		}
	elsif ($mvariant =~ /mysql/i) {
		# Switch config to use MySQL commands
		my $config_updated;
		foreach my $key (grep { /^mysql(?!_)/ } keys %config) {
			my $cmd = $config{$key};
			next if ($cmd !~ /^\//);
	
			# Check if symlink
			if (-l $cmd) {
				my $target = readlink($cmd);
				my $dir = $cmd =~ s|/[^/]+$||r;
				if ($target =~ /^mysql/i) {
					# Update config if symlinked
					# to mysql
					$config{$key} = "$dir/$target";
					$config_updated++;
					}
				}
			# If command doesn't exist, try mysql version
			else {
				my $mysql_cmd = $cmd;
				$mysql_cmd =~ s/mariadb-(\w+)/mysql$1/;
				if (&has_command($mysql_cmd)) {
					$config{$key} = $mysql_cmd;
					$config_updated++;
					}
				}
			}
	
		if ($config_updated) {
			# Update start stop commands
			foreach my $key ('start_cmd', 'stop_cmd') {
				next if ($config{$key} !~ /systemctl/);
				$config{$key} =~ s/mariadb(?:\.service)?$/mysql/;
				}
			# Update config file
			$config{'mysql_postinstall_config_updated'} =
				"$mvariant=$mversion";
			&save_module_config();
			}
		}
	}
}
