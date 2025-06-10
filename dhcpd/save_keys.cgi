#!/usr/bin/perl
# $Id: save_keys.cgi,v 1.2 2005/04/16 14:30:21 jfranken Exp $
# File added 2005-04-15 by Johannes Franken <jfranken@jfranken.de>
# Distributed under the terms of the GNU General Public License, v2 or later
#
# * Save key directives to configfile

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
&lock_all_files();
$conf = &get_config();

$client = &get_parent_config();

@old = &find("key", $conf);
for($i=0; defined($id = $in{"id_$i"}); $i++) {
	next if (!$id);
	$id =~ /^\S+$/ || &error(&text('keys_ekey', $id));
	$in{"secret_$i"} =~ /^\S+$/ || &error(&text('keys_esecret', $id));
	local $k = { 'name' => 'key',
		     'type' => 1 };
	$k->{'members'} = $old[$i] ? $old[$i]->{'members'} : [ ];
	$k->{'values'} = [ $id ];
	&save_directive($k, "algorithm", [ { 'name' => 'algorithm',
				'values' => [ $in{"alg_$i"} ] } ], 1, 1);
	&save_directive($k, "secret", [ { 'name' => 'secret',
				'values' => [ $in{"secret_$i"} ] } ], 1, 1);
	push(@keys, $k);

	}
&save_directive($client, 'key', \@keys, 0);
&flush_file_lines();
&unlock_all_files();
&webmin_log("keys", undef, undef, \%in);
&redirect("");

