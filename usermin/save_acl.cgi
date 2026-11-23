#!/usr/local/bin/perl
# save_acl.cgi
# Change visible usermin modules

require './usermin-lib.pl';
$access{'acl'} || &error($text{'acl_ecannot'});
&ReadParse();
&lock_file(&usermin_acl_filename());
@mods = split(/\0/, $in{'mod'});
my %installed = map { $_->{'dir'}, 1 } &list_modules();
foreach my $mod (@mods) {
	$installed{$mod} && &can_use_module($mod) || &error($text{'acl_ecannot'});
	}
# Preserve the enabled modules that this operator cannot manage.
my %old;
&read_usermin_acl(undef, \%old);
push(@mods, grep { !&can_use_module($_) } @{$old{'user'} || [ ]});
&save_usermin_acl("user", \@mods);
&unlock_file(&usermin_acl_filename());
&webmin_log("acl", undef, undef, \%in);
&redirect("");

