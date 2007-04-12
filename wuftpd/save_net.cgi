#!/usr/local/bin/perl
# save_net.cgi
# Save networking options

require './wuftpd-lib.pl';
&error_setup($text{'net_err'});
&ReadParse();

&lock_file($config{'ftpaccess'});
$conf = &get_ftpaccess();

# Save TCP windows
for($i=0; defined($tsize = $in{"tsize_$i"}); $i++) {
	next if (!$tsize);
	$tsize =~ /^\d+$/ || &error(&text('net_etsize', $tsize));
	push(@tcpwindow, { 'name' => 'tcpwindow',
		           'values' => [ $tsize, $in{"tclass_$i"} ] } );
	}
&save_directive($conf, 'tcpwindow', \@tcpwindow);

# Save PASV options
for($i=0; defined($aip = $in{"aip_$i"}); $i++) {
	$anet = $in{"anet_$i"}; $acidr = $in{"acidr_$i"};
	next if (!$aip);
	&check_ipaddress($aip) || &error(&text('net_eip', $aip));
	&check_ipaddress($anet) || &error(&text('net_enet', $anet));
	$acidr =~ /^\d+$/ && $acidr <= 32 || &error(&text('net_ecidr', $acidr));
	push(@passive, { 'name' => 'passive',
			 'values' => [ 'address', $aip, "$anet/$acidr" ] } );
	}
for($i=0; defined($pmin = $in{"pmin_$i"}); $i++) {
	$pmax = $in{"pmax_$i"}; $pnet = $in{"pnet_$i"};
	$pcidr = $in{"pcidr_$i"};
	next if ($pmin eq "" || $pmax eq "");
	$pmin =~ /^\d+$/ || &error(&text('net_eport', $pmin));
	$pmax =~ /^\d+$/ || &error(&text('net_eport', $pmax));
	&check_ipaddress($pnet) || &error(&text('net_enet', $pnet));
	$pcidr =~ /^\d+$/ && $pcidr <= 32 || &error(&text('net_ecidr', $pcidr));
	push(@passive,
		{ 'name' => 'passive',
		  'values' => [ 'ports', "$pnet/$pcidr", $pmin, $pmax ] } );
	}
&save_directive($conf, 'passive', \@passive);

&flush_file_lines();
&unlock_file($config{'ftpaccess'});
&webmin_log("net", undef, undef, \%in);
&redirect("");

