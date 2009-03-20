#!/usr/local/bin/perl
# change_os.cgi
# Change OS settings

require './webmin-lib.pl';
&ReadParse();

&lock_file("$config_directory/config");
if ($in{'update'}) {
	# Automatically detect
	%osinfo = &detect_operating_system();
	$gconfig{'real_os_type'} = $osinfo{'real_os_type'};
	$gconfig{'real_os_version'} = $osinfo{'real_os_version'};
	$gconfig{'os_type'} = $osinfo{'os_type'};
	$gconfig{'os_version'} = $osinfo{'os_version'};
	}
elsif ($in{'type'} ne $gconfig{'real_os_type'} ||
       $in{'version'} ne $gconfig{'real_os_version'} ||
       $in{'itype'} ne $gconfig{'os_type'} ||
       $in{'iversion'} ne $gconfig{'os_version'}) {
	# Manually change
	$gconfig{'real_os_type'} = $in{'type'};
	$in{'version'} || &error($text{'os_eversion'});
	$gconfig{'real_os_version'} = $in{'version'};
	($os) = grep { $_->{'realtype'} eq $in{'type'} }
		     &list_operating_systems();
	$gconfig{'os_type'} = $in{'itype'};
	$in{'iversion'} || &error($text{'os_eiversion'});
	$gconfig{'os_version'} = $in{'iversion'};
	}
$gconfig{'path'} = join($path_separator, split(/[\r\n]+/, $in{'path'}));
$gconfig{'syspath'} = !$in{'syspath'};
if ($gconfig{'ld_env'}) {
	$gconfig{'ld_path'} = join($path_separator,
				   split(/[\r\n]+/, $in{'ld_path'}));
	}
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
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
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

&show_restart_page();
&webmin_log("os", undef, undef, \%in);
