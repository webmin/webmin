#!/usr/local/bin/perl
# save_vserv.cgi
# Save virtual server options such as the port and address

require './apache-lib.pl';
&ReadParse();
$access{'vaddr'} || &error($text{'vserv_ecannot'});
$conf = &get_config();
($vmembers, $vconf) = &get_virtual_config($in{'virt'});
&can_edit_virt($vconf) || &error($text{'virt_ecannot'});

if ($in{'delete'}) {
	# Delete a virtual server
	%vnames = map { $_, 1 } &virt_acl_name($vconf);
	&lock_file($vconf->{'file'});
	&before_changing();
	&save_directive_struct($vconf, undef, $conf, $conf);
	&delete_file_if_empty($vconf->{'file'});
	&flush_file_lines();
	&unlock_file($vconf->{'file'});

	&after_changing();

	# Remove from acls
	&read_acl(undef, \%wusers);
	foreach $u (keys %wusers) {
		%uaccess = &get_module_acl($u);
		if ($uaccess{'virts'} ne '*') {
			$uaccess{'virts'} = join(' ', grep { !$vnames{$_} }
					      split(/\s+/, $uaccess{'virts'}));
			&save_module_acl(\%uaccess, $u);
			}
		}
	&webmin_log("virt", "delete", &virtual_name($vconf, 1));
	&redirect("");
	}
else {
	# Update virtual server and directives
	&error_setup($text{'vserv_err'});

	# Check address
	if (defined($in{'addrs'})) {
		local @addrs = split(/\s+/, $in{'addrs'});
		@addrs || &error($text{'vserv_eaddrs'});
		foreach $a (@addrs) {
			local $ac = $a;
			$ac =~ s/:(\d+)$//;
			$ac eq '*' || $ac eq '_default_' ||
			    gethostbyname($ac) ||
				&error(&text('vserv_eaddr2', $ac));
			}
		$addr = join(" ", @addrs);
		}
	else {
		if ($in{'addr_def'} == 1) {
			if ($httpd_modules{'core'} >= 1.2)
				{ $addr = "_default_"; }
			else { $addr = "*"; }
			}
		elsif ($in{'addr_def'} == 2) {
			$addr = "*";
			}
		elsif ($in{'addr'} !~ /\S/) {
			&error($text{'vserv_eaddr1'});
			}
		elsif (!gethostbyname($in{'addr'})) {
			&error(&text('vserv_eaddr2', $in{'addr'}));
			}
		else {
			$addr = $in{'addr'};
			}
		}

	# Check port
	if ($in{'port_mode'} == 0) { $port = ""; }
	elsif ($in{'port_mode'} == 1) { $port = ":*"; }
	elsif ($in{'port'} !~ /^\d+$/) {
		&error(&text('vserv_eport', $in{'port'}));
		}
	else { $port = ":$in{'port'}"; }

	# Check document root
	if (!$in{'root_def'}) {
		(-d $in{'root'}) ||
			&error(&text('vserv_eroot', $in{'root'}));
		$root = $in{'root'};
		$root = "\"$root\"" if ($root =~ /\s/);
		}

	# Check server name
	if (!$in{'name_def'}) {
		$in{'name'} =~ /^\S+$/ ||
			&error(&text('vserv_ename', $in{'name'}));
		$name = $in{'name'};
		}

	# Update <VirtualHost> directive
	&lock_file($vconf->{'file'});
	&before_changing();
	$vconf->{'value'} = "$addr$port";
	&save_directive_struct($vconf, $vconf, $conf, $conf, 1);

	# Update DocumentRoot and ServerName
	&save_directive("DocumentRoot", $root ? [ $root ] : [ ],
			$vconf->{'members'}, $conf);
	&save_directive("ServerName", $name ? [ $name ] : [ ],
			$vconf->{'members'}, $conf);

	# write out file
	&flush_file_lines();
	&after_changing();
	&unlock_file($vconf->{'file'});
	&webmin_log("virt", "save", &virtual_name($vconf, 1), \%in);
	&redirect("");
	}

