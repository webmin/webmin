
do 'webmin-lib.pl';

our $webmin_announce_url = "https://announce.webmin.com:443/index.txt";
our $webmin_announce_cache = "$module_var_directory/cache";
our $webmin_announce_cache_time = 24*60*60;

# list_system_info()
# If any, returns announcements to Webmin users
sub list_system_info
{
return ( ) if ($gconfig{'no_announce'});

# Can we use the cache?
my $rawcache = &read_file_contents($webmin_announce_cache);
my $cache = $rawcache ? &unserialise_variable($rawcache) : undef;
my @st = stat($webmin_announce_cache);
my @ann;
if (@st && $st[9] > time() - $webmin_announce_cache_time) {
	# Cache is new enough to use
	@ann = @$cache;
	}
else {
	# Fetch the index of announcements
	my ($host, $port, $page, $ssl) = &parse_http_url($webmin_announce_url);
	return ( ) if (!$host);
	my ($out, $err);
	&http_download($host, $port, $page, \$out, \$err,
		       undef, $ssl, undef, undef, 5);

	if (!$err) {
		# Parse the announcements index file
		foreach my $l (split(/\r?\n/, $out)) {
			$l =~ s/^#.*//;		# Skip comments and spaces
			$l =~ s/^\s+//;
			$l =~ s/\s+$//;
			next if (!$l);
			my ($ahost, $aport, $apage, $assl) =
				&parse_http_url($l, $host, $port, $page, $ssl);
			next if (!$ahost);	# Invalid URL??

			my $afile = &transname();
			&http_download($ahost, $aport, $apage, $afile, \$aerr,
				       undef, $assl, undef, undef, 5);
			last if ($err);
			my %a;
			&read_file($afile, \%a);
			&unlink_file($afile);
			push(@ann, \%a);
			}
		}
	if ($err && $cache) {
		# HTTP download failed somewhere, so fall back to the cache
		# and reset it's validity to prevent a failed retry storm
		@ann = @$cache;
		my $fh;
		open($fh, ">>$webmin_announce_cache");
		close($fh);
		}
	elsif ($err) {
		# Cannot fetch, and no cache
		return ( );
		}
	else {
		# Write to the cache
		&open_tempfile(CACHE, ">$webmin_announce_cache");
		&print_tempfile(CACHE, &serialise_variable(\@ann));
		&close_tempfile(CACHE);
		}
	}

# Now we have the announcement hash refs, turn them into messages
# XXX need dismiss buttons
my @rv;
my $i = 0;
foreach my $a (@ann) {
	my $info = { 'id' => "announce".($i++),
		     'open' => 1,
		     'desc' => $a->{'title'},
		   };
	if ($a->{'type'} eq 'warning') {
		# A warning message
		$info->{'type'} = 'warning';
		$info->{'level'} = $a->{'level'} || 'info';
		$info->{'warning'} = &html_escape($a->{'message'});
		}
	elsif ($a->{'type'} eq 'message') {
		# A message possibly with some buttons
		$info->{'type'} = 'html';
		$info->{'html'} = &html_escape($a->{'message'});
		for(my $b=0; defined($a->{'link'.$b}); $b++) {
			$info->{'html'} .= "\n<p>\n" if ($b == 0);
			$info->{'html'} .= &ui_link($a->{'link'.$b},
						    $a->{'desc'.$b},
						    undef,
						    "target=_new")."\n";
			}
		}
	else {
		# Unknown type??
		next;
		}
	push(@rv, $info);
	}
return @rv;
}
