#!/usr/local/bin/perl
# Save SSL options

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'cnf_ecannot'});
&error_setup($text{'ssl_err'});
&ReadParse();

# Get the mysqld section
foreach my $l (&get_all_mysqld_files()) {
	&lock_file($l);
	}
$conf = &get_mysql_config();
($mysqld) = grep { $_->{'name'} eq 'mysqld' } @$conf;
$mysqld || &error($text{'cnf_emysqld'});

if ($in{'gen'}) {
	# Generate new SSL cert and key in new files
	my $dir = $config{'my_cnf'};
	$dir =~ s/\/([^\/]+)$//;
	my $cert = $dir."/mysql-ssl.cert";
	-r $cert && &error(&text('ssl_ecertexists', $cert));
	my $key = $dir."/mysql-ssl.key";
	-r $key && &error(&text('ssl_ekeyexists', $key));
	&foreign_require("webmin");
	$opts = { 'commonName_def' => 1,
		  'size_def' => 1,
		  'days' => 1825,
		  'countryName' => 'US' };
	$err = &webmin::parse_ssl_key_form($opts, $key, $cert);
	&error($err) if ($err);
	&save_directive($conf, $mysqld, "ssl_cert", [ $cert ]);
	&save_directive($conf, $mysqld, "ssl_key", [ $key ]);
	my $myuser = &find_value("user", $mysqld->{'members'});
	$myuser ||= 'mysql';
	&set_ownership_permissions($myuser, undef, 0600, $key, $cert);
	}
else {
	# Save SSL options
	my $cert = [ ];
	if (!$in{'cert_def'}) {
		-r $in{'cert'} || &error($text{'ssl_ecert'});
		$cert = [ $in{'cert'} ];
		}
	&save_directive($conf, $mysqld, "ssl_cert", $cert);

	my $key = [ ];
	if (!$in{'key_def'}) {
		-r $in{'key'} || &error($text{'ssl_ekey'});
		$key = [ $in{'key'} ];
		}
	&save_directive($conf, $mysqld, "ssl_key", $key);

	my $ca = [ ];
	if (!$in{'ca_def'}) {
		-r $in{'ca'} || &error($text{'ssl_eca'});
		$ca = [ $in{'ca'} ];
		}
	&save_directive($conf, $mysqld, "ssl_ca", $ca);

	&save_directive($conf, $mysqld, "require_secure_transport", 
			$in{'req'} ? [ "on" ] : [ ]);
	}

# Write out file
foreach my $l (&get_all_mysqld_files()) {
	&flush_file_lines($l, undef, 1);
	&unlock_file($l);
	}
if (($in{'restart'} || $in{'gen'}) && &is_mysql_running() > 0) {
	&stop_mysql();
	$err = &start_mysql();
	&error($err) if ($err);
	}
&webmin_log($in{'gen'} ? "genssl" : "ssl");
&redirect("");

