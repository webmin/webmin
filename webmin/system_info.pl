
use strict;
use warnings;
do 'webmin-lib.pl';
our ($module_var_directory, %gconfig, $hidden_announce_file, $module_name, %text);

our $webmin_announce_url = "https://announce.webmin.com:443/index.txt";
our $webmin_announce_cache = "$module_var_directory/announce-cache";
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
			&http_download($ahost, $aport, $apage, $afile, \$err,
				       undef, $assl, undef, undef, 5);
			last if ($err);
			my %a = ( 'file' => $l );
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
		my $fh = "CACHE";
		&open_tempfile($fh, ">$webmin_announce_cache");
		&print_tempfile($fh, &serialise_variable(\@ann));
		&close_tempfile($fh);
		}
	}

# Now we have the announcement hash refs, turn them into messages
my %hide;
&read_file($hidden_announce_file, \%hide);
my @rv;
my $i = 0;
my %vminfo = &get_module_info("virtual-server");
my $vmpro = %vminfo && $vminfo{'version'} !~ /gpl/;
my %cminfo = &get_module_info("server-manager");
my $cmpro = %cminfo && $cminfo{'version'} !~ /gpl/;
foreach my $a (@ann) {
	# Check if this announcement should be skipped
	next if ($hide{$a->{'file'}});
	next if ($a->{'skip_virtualmin_pro'} && $vmpro);
	next if ($a->{'skip_cloudmin_pro'} && $cmpro);
	next if ($a->{'skip_pro'} && ($vmpro || $cmpro));
	
	(my $id = $a->{'file'}) =~ s/\.//;
	my $info = { 'id' => "announce_".$id,
		     'open' => 1,
		     'desc' => $a->{'title'},
		   };
	my $hide = &ui_link_button(
		"/$module_name/hide.cgi?id=".&urlize($a->{'file'}),
		$text{'announce_hide'});
	if ($a->{'type'} eq 'warning') {
		# A warning message
		$info->{'type'} = 'warning';
		$info->{'level'} = $a->{'level'} || 'info';
		$info->{'warning'} = &html_escape($a->{'message'})."<p>\n";
		$info->{'warning'} .= $hide;
		}
	elsif ($a->{'type'} eq 'message') {
		# A message possibly with some buttons
		$info->{'type'} = 'html';
		$info->{'html'} = &html_escape($a->{'message'})."<p>\n";
		for(my $b=0; defined($a->{'link'.$b}); $b++) {
			$info->{'html'} .= &ui_link_button(
				$a->{'link'.$b}, $a->{'desc'.$b}, "_new")."\n";
			}
		$info->{'html'} .= $hide;
		}
	else {
		# Unknown type??
		next;
		}
	push(@rv, $info);
	}
return @rv;
}
