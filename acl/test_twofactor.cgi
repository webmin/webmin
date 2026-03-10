#!/usr/local/bin/perl
# Validate a user-supplied two-factor token

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %access, $base_remote_user);
&foreign_require("webmin");
&error_setup($text{'twofactor_terr'});
&ReadParse();

# Get the user
my @users = &list_users();
my $user;
if ($in{'user'}) {
	&can_edit_user($in{'user'}) || &error($text{'edit_euser'});
	($user) = grep { $_->{'name'} eq $in{'user'} } @users;
	}
else {
	($user) = grep { $_->{'name'} eq $base_remote_user } @users;
	}
$user || &error($text{'twofactor_euser'});
$user->{'twofactor_provider'} || &error($text{'twofactor_etestuser'});
my @provs = &webmin::list_twofactor_providers();
my ($prov) = grep { $_->[0] eq $user->{'twofactor_provider'} } @provs;

# Call the validation function
&ui_print_header(undef, $text{'twofactor_title'}, "");

print &text('twofactor_testing', $prov->[1]),"<br>\n";
my $func = "webmin::validate_twofactor_".$user->{'twofactor_provider'};
my $err = &{\&{$func}}($user->{'twofactor_id'}, $in{'test'},
		       $user->{'twofactor_apikey'});
if ($err) {
	print &text('twofactor_testfailed', $err),"<p>\n";

	print &ui_form_start("save_twofactor.cgi");
	print &ui_hidden("user", $in{'user'}) if ($in{'user'});
	print &ui_form_end([ [ "disable", $text{'twofactor_testdis'} ] ]);
	}
else {
	print $text{'twofactor_testok'},"<p>\n";
	}

&ui_print_footer("", $text{'index_return'});
