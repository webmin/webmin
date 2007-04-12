#!/usr/local/bin/perl
# change_syslet.cgi
# Save syslet auto-download options

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'syslet_err'});

&lock_file("$config_directory/config");
@base = split(/\s+/, $in{'syslet_base'});
foreach $b (@base) {
	$b =~ /^http:\/\/([A-Za-z0-9\.\-]+)(:\d+)?\/(\S*)/ ||
		&error($text{'syslet_ebase'});
	}
$gconfig{'syslet_base'} = join(" ", @base);
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
if ($in{'auto'}) {
	$miniserv{'error_handler_404'} = '/eazel_download_module.cgi';
	}
elsif ($miniserv{'error_handler_404'} eq '/eazel_download_module.cgi') {
	$miniserv{'error_handler_404'} = '';
	}
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

&webmin_log("syslet", undef, undef, \%in);
&show_restart_page();


