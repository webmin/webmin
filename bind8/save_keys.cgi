#!/usr/local/bin/perl
# save_keys.cgi
# Update all the key directives
use strict;
use warnings;
our (%access, %text, %in, %config);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'keys_ecannot'});
&error_setup($text{'keys_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
my $conf = &get_config();
my @old = &find("key", $conf);
my $id;
my @keys;
for(my $i=0; defined($id = $in{"id_$i"}); $i++) {
	next if (!$id);
	$id =~ /^\S+$/ || &error(&text('keys_ekey', $id));
	$in{"secret_$i"} =~ /^\S+$/ || &error(&text('keys_esecret', $id));
	my $k = { 'name' => 'key',
		     'type' => 1 };
	$k->{'members'} = $old[$i] ? $old[$i]->{'members'} : [ ];
	$k->{'values'} = [ $id ];
	&save_directive($k, "algorithm", [ { 'name' => 'algorithm',
				'values' => [ $in{"alg_$i"} ] } ], 1, 1);
	&save_directive($k, "secret", [ { 'name' => 'secret',
				'values' => [ $in{"secret_$i"} ] } ], 1, 1);
	push(@keys, $k);
	}
&save_directive(&get_config_parent(), 'key', \@keys, 0);
&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log("keys", undef, undef, \%in);
&redirect("");

