#!/usr/local/bin/perl
# change_access.cgi
# Update IP allow and deny parameters

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'access_err'});

$raddr = $ENV{'REMOTE_ADDR'};
@hosts = split(/\s+/, $in{"ip"});
if ($in{"access"}) {
	push(@hosts, "LOCAL") if ($in{'local'});
	if (!@hosts) { &error($text{'access_enone'}); }
	foreach $h (@hosts) {
		$err = &valid_allow($h);
		&error($err) if ($err);
		push(@ip, $h);
		}
	if ($in{"access"} == 1 && !&ip_match($raddr, @ip) ||
	    $in{"access"} == 2 && &ip_match($raddr, @ip)) {
		&error(&text('access_eself', $raddr));
		}
	}

eval "use Authen::Libwrap qw(hosts_ctl STRING_UNKNOWN)";
if (!$@ && $in{'libwrap'}) {
	# Check if the current address would be denied
	if (!hosts_ctl("webmin", STRING_UNKNOWN, $raddr, STRING_UNKNOWN)) {
		&error(&text('access_eself', $raddr));
		}
	}

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
delete($miniserv{"allow"});
delete($miniserv{"deny"});
if ($in{"access"} == 1) { $miniserv{"allow"} = join(' ', @hosts); }
elsif ($in{"access"} == 2) { $miniserv{"deny"} = join(' ', @hosts); }
$miniserv{"known_ips"} = $miniserv{"allow"} || $miniserv{"deny"} ||
        (!@hosts && $in{"access"} == 0 ? "" : $miniserv{"known_ips"});
$miniserv{'libwrap'} = $in{'libwrap'};
$miniserv{'alwaysresolve'} = $in{'alwaysresolve'};
if ($in{'trust'} == 2) {
	$miniserv{'trust_real_ip'} = 1;
	$miniserv{'no_trust_ssl'} = 0;
	}
elsif ($in{'trust'} == 1) {
	$miniserv{'trust_real_ip'} = 1;
	$miniserv{'no_trust_ssl'} = 1;
	}
else {
	$miniserv{'trust_real_ip'} = 0;
	$miniserv{'no_trust_ssl'} = 1;
	}
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});
&show_restart_page();
&webmin_log("access", undef, undef, \%in);

