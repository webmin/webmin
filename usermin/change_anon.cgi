#!/usr/local/bin/perl
# change_anon.cgi
# Update list of anonymously accessible modules

require './usermin-lib.pl';
&ReadParse();
&get_usermin_miniserv_config(\%miniserv);
&error_setup($text{'anon_err'});

# Check inputs
&read_acl(undef, \%acl);
for($i=0; defined($in{"url_$i"}); $i++) {
	next if (!$in{"url_$i"});
	$in{"url_$i"} =~ /^\/\S+$/ || &error(&text('anon_eurl', $in{"url_$i"}));
	getpwnam($in{"user_$i"}) || &error(&text('anon_euser', $in{"url_$i"}));
	push(@anon, $in{"url_$i"}."=".$in{"user_$i"});
	}

&lock_file($usermin_miniserv_config);
$miniserv{'anonymous'} = join(" ", @anon);
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);
&restart_usermin_miniserv();
&webmin_log("anon", undef, undef, \%in);
&redirect("");

