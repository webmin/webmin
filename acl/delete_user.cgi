#!/usr/local/bin/perl
# delete_user.cgi
# Delete a webmin user

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access, $base_remote_user);
&ReadParse();
&error_setup($text{'delete_err'});
$access{'delete'} || &error($text{'delete_ecannot'});
&can_edit_user($in{'user'}) || &error($text{'delete_euser'});
&used_for_anonymous($in{'user'}) && &error($text{'delete_eanonuser'});
if ($base_remote_user eq $in{'user'}) {
	&error($text{'delete_eself'});
	}
&delete_user($in{'user'});
&delete_from_groups($in{'user'});
&reload_miniserv();
&webmin_log("delete", "user", $in{'user'});
&redirect("");

