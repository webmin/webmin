#!/usr/local/bin/perl
# alias_setup.cgi
# Create the majordomo and majordomo-owner aliases

require './majordomo-lib.pl';
&ReadParse();
$aliases_files = &get_aliases_file();
$program_dir = $config{'smrsh_program_dir'} ? $config{'smrsh_program_dir'}
				            : $config{'program_dir'};
$wrapper_path = $config{'wrapper_path'} ? $config{'wrapper_path'}
				        : "$program_dir/wrapper";
&error_setup($text{'alias_err'});
if ($in{'owner_a'}) {
	$in{'owner'} =~ /^\S+$/ || &error($text{'alias_eowner'});
	$owner = { 'enabled' => 1,
		   'name' => $in{'owner_a'},
		   'values' => [ $in{'owner'} ] };
	&foreign_call($aliases_module, "create_alias", $owner, $aliases_files);
	}
$email = { 'enabled' => 1,
	   'name' => $in{'email_a'},
	   'values' => [ "|$wrapper_path majordomo" ] };
&foreign_call($aliases_module, "create_alias", $email, $aliases_files);
&redirect("");

