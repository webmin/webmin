#!/usr/local/bin/perl
# save_acls.cgi
# Update all the acl directives

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'acls_ecannot'});
&error_setup($text{'acls_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
$conf = &get_config();
for($i=0; defined($name = $in{"name_$i"}); $i++) {
	next if (!$name);
	$name =~ /^\S+$/ || &error(&text('acls_ename', $name));
	@vals = split(/\s+/, $in{"values_$i"});
	push(@acls, { 'name' => 'acl',
		      'values' => [ $name ],
		      'type' => 1,
		      'members' => [ map { { 'name' => $_ } } @vals ] });
	}

&save_directive(&get_config_parent(), 'acl', \@acls, 0, 0, 1);
&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log("acls", undef, undef, \%in);
&redirect("");

