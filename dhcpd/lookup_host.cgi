#!/usr/local/bin/perl
# lookup_host.cgi
# Find a host with a certain name and re-direct to its editing form
# or present a list of matching hosts if multiple hosts are found

require './dhcpd-lib.pl';
&ReadParse();
$in{'host'} || &error($text{'lookup_ehostname'});

# Recursively find hosts
$conf = &get_config();
@hosts = &find_recursive("host", $conf);

# Check to see if the host contains 6 hex bytes for a Mac address
if ($in{'host'} =~ /:|\-|\./) {
	(my $justbytes = $in{'host'}) =~ s/[^A-Fa-f0-9]//g;
	if ($justbytes =~ /^[0-9a-f]{12}$/i) {
		# Treat this host as a mac address with arbitrary formatting
		$in{'host'} = join(':', unpack("(A2)*", $justbytes) );
		}
	}

# Look for a match
%access = &get_module_acl();
foreach $h (@hosts) {
	local $can_view = &can('r', \%access, $h);
	next if !$can_view && $access{'hide'};
	local $fixed = &find("fixed-address", $h->{'members'});
	local $hard = &find("hardware", $h->{'members'});
	if (&search_re($h->{'values'}->[0], $in{'host'}) ||
	    $fixed && &search_re($fixed->{'values'}->[0], $in{'host'}) ||
	    $hard && &search_re($hard->{'values'}->[1], $in{'host'})) {
		push(@foundhosts, $h);
		}
	}

# Go to the host if only 1 match found
if(scalar(@foundhosts)==1) {
	$host=@foundhosts[0];
        ($gidx, $uidx, $sidx) = &find_parents($host);
        &redirect("edit_host.cgi?idx=$host->{'index'}".
                  (defined($gidx) ? "&gidx=$gidx" : "").
                  (defined($uidx) ? "&uidx=$uidx" : "").
                  (defined($sidx) ? "&sidx=$sidx" : ""));
        }
# List multiple matching hosts
elsif(scalar(@foundhosts) > 1) {
	$desc = &text('ehost_hostlist', $in{'host'} );
	&ui_print_header($desc, "Matches", "" );
	foreach $h (@foundhosts) {
		($gidx, $uidx, $sidx) = &find_parents($h);
		local $params="idx=$h->{'index'}".
                  (defined($gidx) ? "&gidx=$gidx" : "").
                  (defined($uidx) ? "&uidx=$uidx" : "").
                  (defined($sidx) ? "&sidx=$sidx" : "");
		printf("<a href=\"edit_host.cgi?%s\">%s</a><br/>\n",
		    $params, $h->{'values'}->[0] );
		}
	}
# Show an error if no matches
else {
	&error(&text('lookup_ehost', $in{'host'}));
	}
