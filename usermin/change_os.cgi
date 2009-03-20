#!/usr/local/bin/perl
# change_os.cgi
# Change OS settings

require './usermin-lib.pl';
$access{'os'} || &error($text{'acl_ecannot'});
&ReadParse();

&lock_file($usermin_config);
&get_usermin_config(\%uconfig);
&get_usermin_miniserv_config(\%miniserv);
$osfile = "$miniserv{'root'}/os_list.txt";
if ($in{'update'}) {
	# Automatically detect
	%osinfo = &webmin::detect_operating_system($osfile);
	$uconfig{'real_os_type'} = $osinfo{'real_os_type'};
	$uconfig{'real_os_version'} = $osinfo{'real_os_version'};
	$uconfig{'os_type'} = $osinfo{'os_type'};
	$uconfig{'os_version'} = $osinfo{'os_version'};
	}
elsif ($in{'type'} ne $uconfig{'real_os_type'} ||
       $in{'version'} ne $uconfig{'real_os_version'} ||
       $in{'itype'} ne $uconfig{'os_type'} ||
       $in{'iversion'} ne $uconfig{'os_version'}) {
	# Manually change
	$uconfig{'real_os_type'} = $in{'type'};
	$in{'version'} || &error($text{'os_eversion'});
	$uconfig{'real_os_version'} = $in{'version'};
	($os) = grep { $_->{'realtype'} eq $in{'type'} }
		     &webmin::list_operating_systems($osfile);
	$uconfig{'os_type'} = $in{'itype'};
	$in{'iversion'} || &error($text{'os_eiversion'});
	$uconfig{'os_version'} = $in{'iversion'};
	}
$uconfig{'path'} = join(":", split(/[\r\n]+/, $in{'path'}));
$uconfig{'ld_path'} = join(":", split(/[\r\n]+/, $in{'ld_path'}));
&put_usermin_config(\%uconfig);
&unlock_file($usermin_config);

&lock_file($usermin_miniserv_config);
foreach $e (keys %miniserv) {
	delete($miniserv{$e}) if ($e =~ /^env_(\S+)$/ &&
				  $1 ne "WEBMIN_CONFIG" && $1 ne "WEBMIN_VAR");
	}
for($i=0; defined($n = $in{"name_$i"}); $i++) {
	next if (!$n);
	$miniserv{'env_'.$n} = $in{"value_$i"}
		if ($n ne "WEBMIN_CONFIG" && $n ne "WEBMIN_VAR");
	}
$miniserv{'perllib'} = join(':', split(/\r?\n/, $in{'perllib'}));
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);
&restart_usermin_miniserv();

&webmin_log("os", undef, undef, \%in);
&redirect("");

