#!/usr/local/bin/perl
# save_dns.cgi
# Save DNS client configuration

require './net-lib.pl';
$access{'dns'} == 2 || &error($text{'dns_ecannot'});
&error_setup($text{'dns_err'});
&ReadParse();
$old_fqdn = &get_system_hostname(); # Fully-Qualified Domain Name
$old_pqdn = &get_system_hostname(1); # Partially Qualified Domain Name (short name)
$old_hostname = &get_hostname();

$in{'hostname'} =~ /^[A-Za-z0-9\.\-]+$/ ||
	&error(&text('dns_ehost', &html_escape($in{'hostname'})));
$dns = { };

$new_pqdn = $in{'hostname'};
$new_pqdn =~ s/\..*$//;

for($i=0; defined($ns = $in{"nameserver_$i"}); $i++) {
	$ns = $in{"nameserver_$i"};
	$ns =~ s/^\s+//; $ns =~ s/\s+$//;
	if ($ns) {
		my $nns = $ns;
		# Just remove scope identifier (%interface) for simplicity
		$nns =~ s/\%.*$//;
		&check_ipaddress_any($nns) ||
			&error(&text('dns_ens', &html_escape($ns)));
		push(@{$dns->{'nameserver'}}, $nns);
		}
	}
if ($in{'name0'}) {
    my $i = 0 ;
    my $namekey="name$i";
    while ($in{$namekey}) {
	$dns->{'name'}[$i] = $in{$namekey};
	my $nskey = "nameserver$i";
	my $j = -1;
	while (++$j < $max_dns_servers) {
	    $ns = $in{"${nskey}_$j"};
	    $ns =~ s/^\s+//; $ns =~ s/\s+$//;
	    if ($ns) {
		&check_ipaddress_any($ns) ||
		    &error(&text('dns_ens', &html_escape($ns)));
		push(@{$dns->{$nskey}}, $ns);
	    }
	}
	$i++;
	$namekey="name$i";
    }
}
if (!$in{'domain_def'}) {
	@dlist = split(/\s+/, $in{'domain'});
	foreach $d (@dlist) {
		$d =~ /^[A-Za-z0-9\.\-]+$/ ||
			&error(&text('dns_edomain', &html_escape($d)));
		$new_fqdn = "$new_pqdn.$d" if !$new_fqdn;
		push(@{$dns->{'domain'}}, $d);
		}
	@dlist || &error($text{'dns_esearch'});
	}
&parse_order($dns);
&save_dns_config($dns);
&save_hostname($in{'hostname'});

if ($in{'hosts'} && ($in{'hostname'} ne $old_hostname || $new_fqdn ne $old_fqdn)) {
	# Update hostname/fqdn/pqdn in /etc/hosts too
	@hosts = &list_hosts();
	foreach $h (@hosts) {
		local $found = 0;
		foreach $n (@{$h->{'hosts'}}) {
			if (lc($n) eq lc($old_hostname)) {
				$n = $in{'hostname'};
				$found++;
				}
			elsif (lc($n) eq lc($old_fqdn) && $new_fqdn) {
				$n = $new_fqdn;
				$found++;
				}
			elsif (lc($n) eq lc($old_pqdn)) {
				$n = $new_pqdn;
				$found++;
				}
			}
		&modify_host($h) if ($found);
		}

	# Update in ipnodes too
	@ipnodes = &list_ipnodes();
	foreach $h (@ipnodes) {
		local $found = 0;
		foreach $n (@{$h->{'ipnodes'}}) {
			if (lc($n) eq lc($old_hostname)) {
				$n = $in{'hostname'};
				$found++;
				}
			elsif (lc($n) eq lc($old_fqdn) && $new_fqdn) {
				$n = $new_fqdn;
				$found++;
				}
			elsif (lc($n) eq lc($old_pqdn)) {
				$n = $new_pqdn;
				$found++;
				}
			}
		&modify_ipnode($h) if ($found);
		}
	}

if (&foreign_installed("postfix") && $in{'hostname'} ne $old_hostname) {
	# Update postfix mydestination too
	&foreign_require("postfix");
	&postfix::lock_postfix_files();
	@mydests = split(/[ ,]+/, &postfix::get_current_value("mydestination"));
	$idx = &indexoflc($old_hostname, @mydests);
	if ($idx >= 0) {
		$mydests[$idx] = $in{'hostname'};
		&postfix::set_current_value("mydestination",
					    join(", ", @mydests));
		}
	$idx = &indexoflc($old_pqdn, @mydests);
	if ($idx >= 0) {
		$mydests[$idx] = $new_pqdn;
		&postfix::set_current_value("mydestination",
					    join(", ", @mydests));
		}

	# Update postfix myorigin
	$myorigin = &postfix::get_current_value("myorigin");
	if ($myorigin eq $old_hostname) {
		&postfix::set_current_value("myorigin",
					    $in{'hostname'});
		}

	# Update postfix myhostname
	$myhostname = &postfix::get_current_value("myhostname");
	if ($myhostname eq $old_hostname) {
		&postfix::set_current_value("myhostname",
					    $in{'hostname'});
		}

	&postfix::unlock_postfix_files();
	if (&postfix::is_postfix_running()) {
		&postfix::reload_postfix();
		}
	}

&webmin_log("dns", undef, undef, \%in);
&redirect("");

