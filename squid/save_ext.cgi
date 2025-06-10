#!/usr/local/bin/perl
# save_ext.cgi
# Create, update or delete an external auth program

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
&error_setup($text{'ext_err'});
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
my $conf = &get_config();
my @exts = &find_config("external_acl_type", $conf);
my $ext = $conf->[$in{'index'}] if (!$in{'new'});

my $logext;
if ($in{'delete'}) {
	# Just delete it (as long as there are no ACL references)
	my @used = grep { $_->{'values'}->[1] eq 'external' &&
		          $_->{'values'}->[2] eq $ext->{'values'}->[0] }
		        &find_config("acl", $conf);
	&error($text{'ext_eused'}) if (@used);
	splice(@exts, &indexof($ext, @exts), 1);
	$logext = $ext;
	}
else {
	# Validate and store inputs
	$in{'name'} =~ /^\S+$/ || &error($text{'ext_ename'});
	my @vals;
	if (!$ext || $in{'name'} ne $ext->{'values'}->[0]) {
		# Check for a clash
		my ($clash) = grep { $_->{'values'}->[0] eq $in{'name'} }
				      @exts;
		&error($text{'ext_eclash'}) if ($clash);
		}
	push(@vals, $in{'name'});
	foreach my $on ('ttl', 'negative_ttl', 'children', 'cache') {
		if (!$in{$on.'_def'}) {
			$in{$on} =~ /^\d+$/ || &error($text{'ext_e'.$on}." ".$on);
			push(@vals, $on."=".$in{$on});
			}
		}
	$in{'format'} =~ /^\S+/ || &error($text{'ext_eformat'});
	push(@vals, $in{'format'});
	$in{'program'} =~ /^(\S+)/ && &has_command("$1") ||
		&error($text{'ext_eprogram'});
	push(@vals, $in{'program'});

	# Create or update
	my $newext = { 'name' => 'external_acl_type',
		       'values' => \@vals };
	$logext = $newext;
	if ($ext) { $exts[&indexof($ext, @exts)] = $newext; }
	else { push(@exts, $newext); }

	if ($ext && $in{'name'} ne $ext->{'values'}->[0]) {
		# Fix any ACLs that referred to this external type
		my @acls = &find_config("acl", $conf);
		foreach my $a (@acls) {
			if ($a->{'values'}->[1] eq 'external' &&
			    $a->{'values'}->[2] eq $ext->{'values'}->[0]) {
				$a->{'values'}->[2] = $in{'name'};
				}
			}
		&save_directive($conf, "acl", \@acls);
		}
	}

&save_directive($conf, "external_acl_type", \@exts);
&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'delete'} ? 'delete' : $ext ? 'modify' : 'create',
	    'ext', $logext->{'values'}->[0]);
&redirect("edit_acl.cgi?mode=external");

