#!/usr/local/bin/perl
# Save GRUB 2 password protection settings.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%in, %text);

&ReadParse();
&error_setup($text{'security_err'});
my %access = &get_module_acl();
&error("$text{'eacl_np'} $text{'eacl_psecurity'}") if (!$access{'security'});

# The enable flag is deliberately boolean; all other fields normalize below.
defined($in{'enabled'}) && $in{'enabled'} =~ /^[01]\z/ ||
	&error($text{'security_err'});
foreach my $field (qw(user password password2 hash)) {
	$in{$field} = "" if (!defined($in{$field}));
	}
$in{'hash'} =~ s/^\s+|\s+\z//g;

# Read current state so disabling an existing script still triggers regenerate.
my $current = &grub2_read_security_config();
my $err = &grub2_save_security_config({
	'enabled' => $in{'enabled'},
	'user' => $in{'user'},
	'password' => $in{'password'},
	'password2' => $in{'password2'},
	'hash' => $in{'hash'},
});
&error($err) if ($err);
# A changed password script is included by grub-mkconfig, so refresh the menu.
&grub2_mark_regenerate_needed()
	if ($in{'enabled'} || $current->{'exists'});
&webmin_log("security", undef, $in{'enabled'} ? "enabled" : "disabled");
&redirect("index.cgi");
