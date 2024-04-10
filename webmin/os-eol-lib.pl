# os-eol-lib.pl
# Functions for managing OS end-of-life data

use Time::Local;

# eol_oses_list()
# Returns a list of OSes for which EOL data is available
sub eol_oses_list
{
return ('almalinux', 'amazon-linux', 'centos-stream', 'centos',
        'debian', 'fedora', 'freebsd', 'openbsd', 'opensuse',
        'oracle-linux', 'rhel', 'rocky-linux', 'ubuntu');
}

# eol_get_os()
# Returns the current OS or undef if the OS is not supported
sub eol_get_os
{
my $os_type = lc($gconfig{'real_os_type'});
@eol_oses_list = &eol_oses_list();
my ($os_found) = grep {
        my $__ = $_;
        $__ =~ s/-?linux//;
        $__ =~ s/-/ /;
        $os_type =~ /$__/ } @eol_oses_list;
return $os_found if ($os_found);
return undef;
}

# eol_fetch_os_data()
# Fetches the latest EOL data for the current OS and caches it.
# Returns undef if OS is not supported.
sub eol_fetch_os_data
{
my $os = &eol_get_os();
return undef if (!$os);
my ($fetch, $error);
my $eol_cache_file = "$module_var_directory/eolcache";
my $eol_write_cache = sub {
        my $data = shift;
        &write_file_contents($eol_cache_file, $data);
};
&http_download('endoflife.date', 443, "/api/$os.json", \$fetch, \$error, undef, 1,
                undef, undef, 5);
if ($error) {
        &error_stderr("Could not fetch current OS EOL data: " . $error);
        $eol_write_cache->('[]') if (!-r $eol_cache_file);
        return undef;
        }
my $fetch_json;
eval { $fetch_json = &convert_from_json($fetch); };
if ($@) {
        &error_stderr("Could not parse fetched OS EOL data: $@");
        $eol_write_cache->('[]') if (!-r $eol_cache_file);
        return undef;
        }
$eol_write_cache->($fetch);
return $fetch_json;
}

# eol_get_os_data()
# Returns the current OS EOL data from the cache or fetches it
# if it is not available
sub eol_get_os_data
{
my $eol_cache_file = "$module_var_directory/eolcache";
my $eol_cache = &read_file_contents($eol_cache_file);
if ($eol_cache) {
        # Check if the cache is still valid (1 month)
        if (time() - (stat($eol_cache_file))[9] < 60*60*24*30) {
                eval { $eol_cache = &convert_from_json($eol_cache); };
                if ($@) {
                        unlink($eol_cache_file);
                        &error_stderr("Could not parse current OS EOL data: $@");
                        return undef;
                        }
                return (ref($eol_cache) eq 'ARRAY' && @$eol_cache) ?
                        $eol_cache : undef;
                }
        }
# No cache found, fetch the data
my $eol_fetched = &eol_fetch_os_data();
return $eol_fetched;
}

# eol_get_os_eol_data()
# Returns the EOL hash for the current OS or undef if the OS is not supported
sub eol_get_os_eol_data
{
my $os_version = lc($gconfig{'real_os_version'});
my $os_type = $gconfig{'real_os_type'};
my $os_version_formatter = sub {
        my $v = shift;
        # Extract the major and minor versions
        $v =~ m/^(?:stable\/)?(?<major>\d+)(?:\.(?<minor>\d+))?/;
        $v = $+{minor} ? "$+{major}.$+{minor}" : $+{major};
        return undef if (!$+{major});
        # Minor versions in cycle are allowed only for Ubuntu
        return $+{major} if (lc($os_type) !~ /ubuntu/);
        return $v;
};
$os_version = $os_version_formatter->($os_version);
# Get the EOL data for the current OS
my $eol_data = &eol_get_os_data();
return undef if (!$eol_data);
# Find the EOL data for the current OS version
($eol_data) = grep { $_->{'cycle'} eq $os_version } @$eol_data;
return undef if (!$eol_data);

# Add OS real name
$eol_data->{'_os'} = $os_type;

# Convert EOL date to a timestamp and a human-readable date based on locale
my ($year, $month, $day) = split('-', $eol_data->{'eol'});
$month -= 1;
my $eol_timestamp = timelocal(0, 0, 0, $day, $month, $year);
my $eol_date = &make_date($eol_timestamp, { '_' => 1 });
$eol_data->{'_eol'} =
        { daymonth => $eol_date->{'complete_short'},
          month => $eol_date->{'monthfull'},
          year => $eol_date->{'year'},
          short => $eol_date->{'short'},
          timestamp => $eol_timestamp };
$eol_data->{'_eol_in'} =
        { years => abs($eol_date->{'ago'}->{'years'}),
          months => abs($eol_date->{'ago'}->{'months'}),
          weeks => abs($eol_date->{'ago'}->{'weeks'}),
          days => abs($eol_date->{'ago'}->{'days'}) };

# Convert EOL extendend date to a timestamp and a human-readable date based on locale
if ($eol_data->{'extendedSupport'}) {
        my ($year, $month, $day) = split('-', $eol_data->{'extendedSupport'});
        $month -= 1;
        my $eol_extendedSupport_timestamp = timelocal(0, 0, 0, $day, $month, $year);
        my $eol_extendedSupport_date = &make_date($eol_extendedSupport_timestamp, { '_' => 1 });
        $eol_data->{'_eol_sec'} =
                { daymonth => $eol_extendedSupport_date->{'complete_short'},
                  month => $eol_extendedSupport_date->{'monthfull'},
                  year => $eol_extendedSupport_date->{'year'},
                  short => $eol_extendedSupport_date->{'short'},
                  timestamp => $eol_extendedSupport_timestamp };
        $eol_data->{'_eol_sec_in'} =
                { years => abs($eol_extendedSupport_date->{'ago'}->{'years'}),
                  months => abs($eol_extendedSupport_date->{'ago'}->{'months'}),
                  weeks => abs($eol_extendedSupport_date->{'ago'}->{'weeks'}),
                  days => abs($eol_extendedSupport_date->{'ago'}->{'days'}) };
        }

# Is expired?
my $expired = $eol_data->{'_eol'}->{'timestamp'} < time();
$eol_data->{'_expired'} = $expired ? 1 : 0 if ($expired);

# Is expiring in (3 months by default)
my $os_eol_warn = $gconfig{'os_eol_warn'} || 3;
my $expiring = $eol_data->{'_eol'}->{'timestamp'} < time() + 60*60*24*30*$os_eol_warn ? 1 : 0;
if (!$expired && $expiring) {
        $eol_data->{'_expiring'} = $expiring;
        }

# Return the final EOL data object
return $eol_data;
}

# eol_get_os_eol_alert_message()
# Returns the EOL alert message to be shown on the dashboard
sub eol_get_os_eol_alert_message
{
# XXX to-do
}

# eol_get_os_eol_table_message()
# Returns the EOL data to be shown in the table row
sub eol_get_os_eol_table_message
{
# XXX to-do
}

1;
