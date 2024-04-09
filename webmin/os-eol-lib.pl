# os-eol-lib.pl
# Functions for managing OS end-of-life data

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
my $eol_write_cache = sub {
        my $data = shift;
        &write_file_contents("$module_var_directory/eolcache", $data);
};
&http_download('endoflife.date', 443, "/api/$os.json", \$fetch, \$error, undef, 1);
if ($error) {
        &error_stderr("Could not fetch current OS EOL data: " . $error);
        $eol_write_cache->('[]');
        return undef;
        }
my $fetch_json;
eval { $fetch_json = &convert_from_json($fetch); };
if ($@) {
        &error_stderr("Could not parse fetched OS EOL data: $@");
        $eol_write_cache->('[]');
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
        # Check if the cache is still valid (5 days)
        if (time() - (stat($eol_cache_file))[9] < 60*60*24*5) {
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

1;
