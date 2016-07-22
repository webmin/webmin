#!/usr/local/bin/perl
# Enable two-factor authentication

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'twofactor_err'});
&get_miniserv_config(\%miniserv);

# Validate inputs
if ($in{'twofactor_provider'}) {
	($prov) = grep { $_->[0] eq $in{'twofactor_provider'} }
		       &list_twofactor_providers();
	$prov || &error($text{'twofactor_eprovider'});
	$vfunc = "validate_twofactor_apikey_".$in{'twofactor_provider'};
	$err = defined(&$vfunc) && &$vfunc(\%in, \%miniserv);
	&error($err) if ($err);
	}
else {
	# Don't disable if any users have twofactor enabled
	&foreign_require("acl");
	@twos = grep { $_->{'twofactor_provider'} && $_->{'twofactor_id'} }
		     &acl::list_users();
	if (@twos) {
		&error(&text('twofactor_eusers',
			     join(" ", map { $_->{'name'} } @twos)));
		}
	}

# Save settings
&lock_file($ENV{'MINISERV_CONFIG'});
$miniserv{'twofactor_provider'} = $in{'twofactor_provider'};
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

$msg = $text{'restart_done'}."<p>\n";
if ($in{'twofactor_provider'}) {
	$msg .= &text('twofactor_enrolllink',
		      "../acl/twofactor_form.cgi")."<p>\n";
	$mfunc = "message_twofactor_apikey_".$in{'twofactor_provider'};
	if (defined(&$mfunc)) {
		$msg .= &$mfunc(\%miniserv)."<p>\n";
		}
	elsif ($prov->[2]) {
		$msg .= &text('twofactor_url', $prov->[1], $prov->[2])."<p>\n";
		}
	}
&show_restart_page($text{'twofactor_title'}, $msg);

&webmin_log("twofactor", undef, undef, \%in);
