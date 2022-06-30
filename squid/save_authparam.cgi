#!/usr/local/bin/perl
# save_authparam.cgi
# Save authentication program options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config, $auth_program,
     $auth_database, $module_root_directory, $module_config_directory);
require './squid-lib.pl';
$access{'authparam'} || &error($text{'authparam_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
my $conf = &get_config();
&error_setup($text{'authparam_err'});

if ($squid_version >= 2.5) {
	my @auth = &find_config("auth_param", $conf);

	# Save basic authentication options
	if ($in{'b_auth_mode'} == 0) {
		&save_auth(\@auth, "basic", "program");
		}
	elsif ($in{'b_auth_mode'} == 2) {
		&copy_source_dest("$module_root_directory/squid-auth.pl",
				  "$module_config_directory/squid-auth.pl");
		&save_auth(\@auth, "basic", "program", "$auth_program $auth_database");
		&system_logged("chmod a+rx $auth_program $auth_database");
		}
	else {
		&check_error(\&check_prog, $in{'b_auth'});
		&save_auth(\@auth, "basic", "program", $in{'b_auth'});
		}
	if ($in{'b_children_def'}) {
		&save_auth(\@auth, "basic", "children");
		}
	else {
		$in{'b_children'} =~ /^\d+$/ ||
			&error(&text('sprog_emsg5', $in{'b_children'}));
		&save_auth(\@auth, "basic", "children", $in{'b_children'});
		}
	if ($in{'b_ttl_def'}) {
		&save_auth(\@auth, "basic", "credentialsttl");
		}
	else {
		$in{'b_ttl'} =~ /^\d+$/ ||
			&error(&text('sprog_emsg10', $in{'b_ttl'}));
		&save_auth(\@auth, "basic", "credentialsttl",
				 $in{'b_ttl'}." ".$in{'b_ttl_u'});
		}
	if ($in{'b_realm_def'}) {
		&save_auth(\@auth, "basic", "realm");
		}
	else {
		&save_auth(\@auth, "basic", "realm", $in{'b_realm'});
		}
	if ($in{'b_aittl_def'}) {
		&save_directive($conf, "authenticate_ip_ttl",[ ]);
		}
	else {
		$in{'b_aittl'} =~ /^\d+$/ ||
			&error(&text('sprog_emsg10', $in{'b_aittl'}));
		my @baittl= ( $in{'b_aittl'}." ".$in{'b_aittl_u'} );
		&save_directive($conf, "authenticate_ip_ttl",
			[ { 'name' => 'authenticate_ip_ttl',
			'values' => \@baittl }]);
		}

	# Save digest authentication options
	if ($in{'d_auth_mode'} == 0) {
		&save_auth(\@auth, "digest", "program");
		}
	else {
		&check_error(\&check_prog, $in{'d_auth'});
		&save_auth(\@auth, "digest", "program", $in{'d_auth'});
		}
	if ($in{'d_children_def'}) {
		&save_auth(\@auth, "digest", "children");
		}
	else {
		$in{'d_children'} =~ /^\d+$/ ||
			&error(&text('sprog_emsg5', $in{'d_children'}));
		&save_auth(\@auth, "digest", "children", $in{'d_children'});
		}
	if ($in{'d_realm_def'}) {
		&save_auth(\@auth, "digest", "realm");
		}
	else {
		&save_auth(\@auth, "digest", "realm", $in{'d_realm'});
		}

	# Save NTLM authentication options
	if ($in{'n_auth_mode'} == 0) {
		&save_auth(\@auth, "ntlm", "program");
		}
	else {
		&check_error(\&check_prog, $in{'n_auth'});
		&save_auth(\@auth, "ntlm", "program", $in{'n_auth'});
		}
	if ($in{'n_children_def'}) {
		&save_auth(\@auth, "ntlm", "children");
		}
	else {
		$in{'n_children'} =~ /^\d+$/ ||
			&error(&text('sprog_emsg5', $in{'n_children'}));
		&save_auth(\@auth, "ntlm", "children", $in{'n_children'});
		}
	if ($in{'n_reuses_def'}) {
		&save_auth(\@auth, "ntlm", "max_challenge_reuses");
		}
	else {
		$in{'n_reuses'} =~ /^\d+$/ ||
			&error(&text('authparam_ereuses', $in{'n_reuses'}));
		&save_auth(\@auth, "ntlm", "max_challenge_reuses",
			   $in{'n_reuses'});
		}
	if ($in{'n_ttl_def'}) {
		&save_auth(\@auth, "ntlm", "max_challenge_lifetime");
		}
	else {
		$in{'n_ttl'} =~ /^\d+$/ ||
			&error(&text('authparam_elifetime', $in{'n_ttl'}));
		&save_auth(\@auth, "ntlm", "max_challenge_lifetime",
				 $in{'n_ttl'}." ".$in{'n_ttl_u'});
		}

	&save_directive($conf, "auth_param", \@auth, undef, "acl");
	}
elsif ($squid_version >= 2) {
	if ($in{'auth_mode'} == 0) {
		&save_directive($conf, "authenticate_program", [ ]);
		}
	elsif ($in{'auth_mode'} == 2) {
		&copy_source_dest("$module_root_directory/squid-auth.pl",
				  "$module_config_directory/squid-auth.pl");
		&save_directive($conf, "authenticate_program",
			[ { 'name' => 'authenticate_program',
			    'values' => [ "$auth_program $auth_database" ] } ]);
		&system_logged("chmod a+rx $auth_program $auth_database");
		}
	else {
		&check_error(\&check_prog, $in{'auth'});
		&save_directive($conf, "authenticate_program",
				[ { 'name' => 'authenticate_program',
				    'values' => [ $in{'auth'} ] } ]);
		}
	&save_opt("authenticate_children", \&check_children, $conf);

        &save_opt("proxy_auth_realm", undef, $conf);

	if ($squid_version >= 2.4) {
		&save_opt_time("authenticate_ttl", $conf);
		&save_opt_time("authenticate_ip_ttl", $conf);
		}
	}

&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("authparam", undef, undef, \%in);
&redirect("");

sub check_prog
{
$_[0] =~ /^(\/\S+)/ || return &text('sprog_emsg2', $_[0]);
return -x $1 ? undef : &text('sprog_emsg3',$_[0]); 
}

sub check_children
{
return $_[0] =~ /^\d+$/ ? undef : &text('sprog_emsg5',$_[0]);
}

# save_auth(&auth, type, name, [value])
sub save_auth
{
my ($old) = grep { $_->{'values'}->[0] eq $_[1] &&
		   $_->{'values'}->[1] eq $_[2] } @{$_[0]};
if ($old && @_ > 3) {
	# Replace value
	$old->{'values'} = [ $_[1], $_[2], $_[3] ];
	}
elsif (@_ > 3) {
	# Adding
	push(@{$_[0]}, { 'name' => 'auth_param',
			 'values' => [ $_[1], $_[2], $_[3] ] });
	}
elsif ($old) {
	# Removing
	@{$_[0]} = grep { $_ ne $old } @{$_[0]};
	}
}
