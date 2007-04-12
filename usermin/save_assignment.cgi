#!/usr/local/bin/perl

require './usermin-lib.pl';
$access{'assignment'} || &error($text{'acl_ecannot'});
&ReadParse();

&lock_file("$config{'usermin_dir'}/webmin.cats");
@modules = &list_modules();
foreach $module (keys %in){
	local ($minfo) = grep { $_->{'dir'} eq $module } @modules;
	next if (!$minfo);
	if ($minfo->{'realcategory'} ne $in{$module}) {
		$cats{$module} = $in{$module};
		}
	}
&write_file("$config{'usermin_dir'}/webmin.cats", \%cats);
&unlock_file("$config{'usermin_dir'}/webmin.cats");
&webmin_log("assignment", undef, undef, \%in);
&flush_modules_cache();

&redirect("");
