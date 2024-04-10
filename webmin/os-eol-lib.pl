# os-eol-lib.pl
# Functions for managing OS end-of-life data

use strict;
use warnings;
use Time::Local;

our (%gconfig, %text, $root_directory);

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
my @eol_oses_list = &eol_oses_list();
my ($os_found) = grep {
        my $__ = $_;
        $__ =~ s/-?linux//;
        $__ =~ s/-/ /;
        $os_type =~ /$__/ } @eol_oses_list;
return $os_found if ($os_found);
return undef;
}

# eol_build_all_os_data()
# Fetches the latest EOL data for all supported
# OSes and writes it to given file.
sub eol_build_all_os_data
{
my $eol_cache_file = shift;
$eol_cache_file ||= "$root_directory/os_eol.json";
my @eol_oses = &eol_oses_list();
my @eol_oses_data;
foreach my $os (@eol_oses) {
        my ($fdata, $ferror);
        &http_download('endoflife.date', 443, "/api/$os.json", \$fdata, \$ferror, undef, 1,
                        undef, undef, 5);
        if ($ferror) {
                &error_stderr("Could not fetch OS EOL data: " . $ferror);
                next;
                }
        my $fdata_json;
        eval { $fdata_json = &convert_from_json($fdata); };
        if ($@) {
                &error_stderr("Could not parse fetched OS EOL data: $@");
                next;
                }
        # Add OS
        $fdata_json = [ map { $_->{'_os'} = $os; $_ } @$fdata_json ];
        # Fix (blessed) LTS key
        $fdata_json = [ map { $_->{'lts'} = $_->{'lts'} ? 1 : 0; $_ } @$fdata_json ];
        push(@eol_oses_data, @$fdata_json);
        }
&write_file_contents($eol_cache_file, &convert_to_json(\@eol_oses_data));
}

# eol_get_os_data()
# Returns EOL data for the current OS.
# Returns undef if OS is not supported.
sub eol_get_os_data
{
my $os = &eol_get_os();
return undef if (!$os);
my $eol_file = shift;
$eol_file ||= "$root_directory/os_eol.json";
if (!-r $eol_file) {
        &error_stderr("Could not read OS EOL data file: $eol_file");
        return undef;
        }
my $eol_data = &read_file_contents($eol_file);
my $eol_json;
eval { $eol_json = &convert_from_json($eol_data); };
if ($@) {
        &error_stderr("Could not parse OS EOL data: $@");
        return undef;
        }
if (ref($eol_json) eq 'ARRAY' && @$eol_json) {
        my $os_version = $gconfig{'real_os_version'};
        # Extract the major and minor versions
        $os_version =~ m/^(?:stable\/)?(?<major>\d+)(?:\.(?<minor>\d+))?/;
        $os_version = $+{minor} ? "$+{major}.$+{minor}" : $+{major};
        return undef if (!$+{major});
        # Minor versions in cycle are allowed only for Ubuntu
        $os_version = $+{major} if ($os !~ /ubuntu/);
        my ($eol_json_this_os) =
                grep { $_->{'_os'} eq $os &&
                       $_->{'cycle'} eq $os_version } @$eol_json;
        $eol_json_this_os->{'_os_name'} = $gconfig{'real_os_type'};
        $eol_json_this_os->{'_os_version'} = $os_version;
        # Convert EOL date to a timestamp
        my ($year, $month, $day) = split('-', $eol_json_this_os->{'eol'});
        $eol_json_this_os->{'_eol_timestamp'} = timelocal(0, 0, 0, $day, $month - 1, $year);
        # Convert EOL extendend date to a timestamp
        if ($eol_json_this_os->{'extendedSupport'}) {
                my ($year, $month, $day) = split('-', $eol_json_this_os->{'extendedSupport'});
                $eol_json_this_os->{'_ext_eol_timestamp'} =
                        timelocal(0, 0, 0, $day, $month - 1, $year);
                }
        return $eol_json_this_os if ($eol_json_this_os);
        }
return undef;
}

# eol_populate_dates(&eol_data)
# Updates given EOL hash reference with
# human readable date and the time ago
sub eol_populate_dates
{
my ($eol_data) = @_;
if (!$eol_data->{'_eol_timestamp'}) {
        &error_stderr("The provided data is not a valid EOL data hash reference");
        return undef;
        }
my $eol_date = &make_date($eol_data->{'_eol_timestamp'}, { '_' => 1 });
if (ref($eol_date)) {
        my $eol_in = sub {
                my $eol_date = shift;
                my $ago = $eol_date->{'ago'};
                my @ago_units = qw(year month week day hour minute second);
                foreach my $unit (@ago_units) {
                        if ($ago->{"${unit}s"}) {
                                my $value = abs($ago->{"${unit}s"});
                                return $value == 1 ? "1 " . $text{"eol_${unit}"} :
                                        "$value " . $text{"eol_${unit}s"};
                                }
                        }
                };
        $eol_data->{'_eol'} =
                { daymonth => $eol_date->{'complete_short'},
                  month => $eol_date->{'monthfull'},
                  year => $eol_date->{'year'},
                  short => $eol_date->{'short'} };
        $eol_data->{'_eol_in'} = $eol_in->($eol_date);
        if ($eol_data->{'extendedSupport'}) {
                my $eol_date = &make_date(
                        $eol_data->{'_ext_eol_timestamp'}, { '_' => 1 });
                $eol_data->{'_ext_eol'} =
                        { daymonth => $eol_date->{'complete_short'},
                          month => $eol_date->{'monthfull'},
                          year => $eol_date->{'year'},
                          short => $eol_date->{'short'} };
                $eol_data->{'_ext_eol_in'} = $eol_in->($eol_date);
                }
        }
else {
        $eol_data->{'_eol'} =
                &make_date($eol_data->{'_eol_timestamp'}, 1);
        if ($eol_data->{'extendedSupport'}) {
                $eol_data->{'_ext_eol'} =
                        &make_date($eol_data->{'_ext_eol_timestamp'}, 1);
                }
        }

# Is expired?
my $expired = $eol_data->{'_eol_timestamp'} < time();
$eol_data->{'_expired'} = $text{'eol_reached'} if ($expired);

# Is expiring (in 6 months by default, unless configured otherwise)
my $os_eol_warn = $gconfig{'os_eol_warn'} // 6;
if (!$expired && $os_eol_warn) {
        my $expiring = $eol_data->{'_eol_timestamp'} < time() +
                                60*60*24*30*$os_eol_warn ? 1 : 0;
        if ($expiring) {
                $eol_data->{'_expiring'} =
                        $eol_data->{'_eol_in'} ?
                                $text{'eol_reaching'} . " " .
                                        $eol_data->{'_eol_in'} :
                                $text{'eol_reaching2'};
                }
        if ($eol_data->{'extendedSupport'}) {
                my $expiring = $eol_data->{'_ext_eol_timestamp'} < time() +
                                60*60*24*30*$os_eol_warn ? 1 : 0;
                if ($expiring) {
                        $eol_data->{'_ext_expiring'} =
                                $eol_data->{'_ext_eol_in'} ?
                                        $text{'eol_reaching'} . " " .
                                                $eol_data->{'_ext_eol_in'} :
                                        $text{'eol_reaching2'};
                        }
                }
        }
return $eol_data;
}

# eol_get_os_alert_message()
# Returns the EOL alert message to be shown on the dashboard
sub eol_get_os_alert_message
{
# XXX to-do
}

# eol_get_os_message()
# Returns the EOL data to be shown in the table row
sub eol_get_os_message
{
# XXX to-do
}

1;
