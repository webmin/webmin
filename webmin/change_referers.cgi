#!/usr/local/bin/perl
# change_referers.cgi
# Change referer checking settings

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'referers_err'});

&lock_file("$config_directory/config");
$gconfig{'referer'} = $in{'referer'};
@refs = split(/\s+/, $in{'referers'});
foreach my $r (@refs) {
	$r =~ /^[a-z0-9\.\-\_]+$/ ||
		&error(&text('referers_ehost', &html_escape($r)));
	}
$gconfig{'referers'} = join(" ", @refs);
$gconfig{'referers_none'} = int(!$in{'referers_none'});
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");
&webmin_log('referers', undef, undef, \%in);

&redirect("");

