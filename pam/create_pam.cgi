#!/usr/local/bin/perl
# create_pam.cgi
# Create a new PAM service

require './pam-lib.pl';
&ReadParse();
&error_setup($text{'create_err'});

# Create the empty file
$in{'name'} =~ /^\S+$/ || &error($text{'create_ename'});
$f = "$config{'pam_dir'}/$in{'name'}";
&lock_file($f);
&open_tempfile(FILE, ">$f");
&print_tempfile(FILE, "#%PAM-1.0\n");
&print_tempfile(FILE, "# description: $in{'desc'}\n") if ($in{'desc'});
&close_tempfile(FILE);
chmod(0644, $f);

# Create extra PAM modules
if ($in{'mods'} == 1) {
	# Setup for unix authentication
	&create_module($in{'name'}, { 'type' => 'auth',
				      'control' => 'required',
				      'module' => 'pam_pwdb.so',
				      'args' => 'shadow nullok' });
	&create_module($in{'name'}, { 'type' => 'account',
				      'control' => 'required',
				      'module' => 'pam_pwdb.so' });
	&create_module($in{'name'}, { 'type' => 'password',
				      'control' => 'required',
				      'module' => 'pam_pwdb.so',
				      'args' => 'shadow nullok use_authtok' });
	&create_module($in{'name'}, { 'type' => 'session',
				      'control' => 'required',
				      'module' => 'pam_pwdb.so' });
	}
elsif ($in{'mods'} == 2) {
	# Setup to deny access
	&create_module($in{'name'}, { 'type' => 'auth',
				      'control' => 'required',
				      'module' => 'pam_deny.so' });
	&create_module($in{'name'}, { 'type' => 'account',
				      'control' => 'required',
				      'module' => 'pam_deny.so' });
	&create_module($in{'name'}, { 'type' => 'password',
				      'control' => 'required',
				      'module' => 'pam_deny.so' });
	&create_module($in{'name'}, { 'type' => 'session',
				      'control' => 'required',
				      'module' => 'pam_deny.so' });
	}

&unlock_file($f);
&webmin_log("create", "pam", $in{'name'}, { 'name' => $in{'name'},
					    'file' => $f });
&redirect("");

