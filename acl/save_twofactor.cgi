#!/usr/local/bin/perl
# Activate or de-activate twofactor

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access, $base_remote_user);
&foreign_require("webmin");
&error_setup($text{'twofactor_err'});
&ReadParse();

my %miniserv;
&get_miniserv_config(\%miniserv);

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

if ($in{'enable'}) {
	# Validate enrollment inputs
	my $vfunc = "webmin::parse_twofactor_form_".
		    $miniserv{'twofactor_provider'};
	my $details;
	if (defined(&{\&{$vfunc}})) {
		$details = &{\&{$vfunc}}(\%in, $user);
		&error($details) if (!ref($details));
		}

	&ui_print_header(undef, $text{'twofactor_title'}, "");
	my ($prov) = grep { $_->[0] eq $miniserv{'twofactor_provider'} }
		       &webmin::list_twofactor_providers();

	# Register user
	print &text('twofactor_enrolling', $prov->[1]),"<br>\n";
	my $efunc = "webmin::enroll_twofactor_".$miniserv{'twofactor_provider'};
	my $err = &{\&{$efunc}}($details, $user);
	if ($err) {
		# Failed!
		print &text('twofactor_failed', $err),"<p>\n";
		}
	else {
		print &text('twofactor_done', $user->{'twofactor_id'}),"<p>\n";

		# Print provider-specific message
		my $mfunc = "webmin::message_twofactor_".
			    $miniserv{'twofactor_provider'};
		if (defined(&{\&{$mfunc}})) {
			print &{\&{$mfunc}}($user);
			}

		# Save user
		$user->{'twofactor_provider'} = $miniserv{'twofactor_provider'};
		&modify_user($user->{'name'}, $user);
		&reload_miniserv();
		&webmin_log("twofactor", "user", $user->{'name'},
			    { 'provider' => $user->{'twofactor_provider'},
			      'id' => $user->{'twofactor_id'} });
		}

	&ui_print_footer("", $text{'index_return'});
	}
elsif ($in{'disable'}) {
	# Turn off for this user
	$user->{'twofactor_provider'} = undef;
	$user->{'twofactor_id'} = undef;
	$user->{'twofactor_apikey'} = undef;
	&modify_user($user->{'name'}, $user);
	&reload_miniserv();
	&webmin_log("onefactor", "user", $user->{'name'});
	&redirect("");
	}
else {
	&error($text{'twofactor_ebutton'});
	}
