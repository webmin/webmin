#!/usr/local/bin/perl
# Create, update or delete a TLS key and cert

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in, %config);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'tls_ecannot'});
&supports_tls() || &error($text{'tls_esupport'});
&ReadParse();
&error_setup($in{'new'} ? $text{'tls_cerr'} :
	     $in{'delete'} ? $text{'tls_derr'} : $text{'tls_err'});

# Get the TLS config being edited
my $parent = &get_config_parent();
my $conf = &get_config();
my @tls = &find("tls", $conf);
my $tls;
if (!$in{'new'}) {
	($tls) = grep { $_->{'values'}->[0] eq $in{'oldname'} } @tls;
	$tls || &error($text{'tls_egone'});
	}

&lock_file(&make_chroot($config{'named_conf'}));
if ($in{'delete'}) {
	# Just remove this one TLS key, if unused
	my @users = &find_tls_users($conf, $tls->{'values'}->[0]);
	@users && &error($text{'tls_eusers'});
	&save_directive($parent, [ $tls ], [ ]);
	}
else {
	# Validate inputs
	$in{'name'} =~ /^[a-z0-9\-\_]+$/i || &error($text{'tls_ename'});
	-r $in{'key'} || &error($text{'tls_ekey'});
	-r $in{'cert'} || &error($text{'tls_ecert'});
	if (!$in{'ca_def'}) {
		-r $in{'ca'} || &error($text{'tls_eca'});
		}
	&foreign_require("webmin");
	&webmin::validate_key_cert($in{'key'}, $in{'cert'});
	if (!$in{'ca_def'}) {
		&webmin::validate_key_cert($in{'key'}, $in{'ca'});
		}

	if ($in{'new'}) {
		# Create the TLS object
		$tls = { 'name' => 'tls',
			 'values' => [ $in{'name'} ],
			 'type' => 1,
			 'members' => [
			   { 'name' => 'key-file',
			     'values' => [ $in{'key'} ]
			   },
			   { 'name' => 'cert-file',
			     'values' => [ $in{'cert'} ]
			   },
			 ]
		       };
		if (!$in{'ca_def'}) {
			push(@{$tls->{'members'}},
			     { 'name' => 'ca-file',
                               'values' => [ $in{'ca'} ]
                             });
			}
		&save_directive($parent, [ ], [ $tls ]);
		}
	else {
		# Update the existing object
		$tls->{'values'}->[0] = $in{'name'};
		&save_directive($parent, [ $tls ], [ $tls ]);
		&save_directive($tls, "key-file",
				[ { 'name' => 'key-file',
				    'values' => [ $in{'key'} ] } ]);
		&save_directive($tls, "cert-file",
				[ { 'name' => 'cert-file',
				    'values' => [ $in{'cert'} ] } ]);
		&save_directive($tls, "ca-file", $in{'ca_def'} ? [ ] :
				[ { 'name' => 'ca-file',
				    'values' => [ $in{'ca'} ] } ]);
		}
	}
&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log($in{'new'} ? 'create' : $in{'delete'} ? 'delete' : 'modify',
	    'tls', $tls->{'values'}->[0]);
&redirect("list_tls.cgi");

