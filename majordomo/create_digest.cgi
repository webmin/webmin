#!/usr/local/bin/perl
# create_digest.cgi
# Create a new digest list

require './majordomo-lib.pl';
require 'ctime.pl';
%access = &get_module_acl();
$access{'create'} || &error($text{'digest_ecannot'});
&ReadParse();
$conf = &get_config();
$ldir = &perl_var_replace(&find_value("listdir", $conf), $conf);
$program_dir = $config{'smrsh_program_dir'} ? $config{'smrsh_program_dir'}
				            : $config{'program_dir'};
$wrapper_path = $config{'wrapper_path'} ? $config{'wrapper_path'}
				        : "$program_dir/wrapper";
&error_setup($text{'digest_err'});

# Validate inputs
$in{'name'} =~ /^\S+$/ || &error($text{'create_ename'});
$in{'name'} = lc($in{'name'});
if (&get_list($in{'name'}, $conf)) {
	&error(&text('create_eexists', $in{'name'}));
	}
$aliases_files = &get_aliases_file();
@aliases = &foreign_call($aliases_module, "list_aliases", $aliases_files);
foreach $a (@aliases) {
	if ($a->{'enabled'} && lc($a->{'name'}) eq lc($in{'name'})) {
		&error(&text('create_ealias', $in{'name'}));
		}
	}
$in{'owner'} =~ /^\S+$/ ||
	&error($text{'create_eowner'});
$in{'password'} =~ /^\S+$/ ||
	&error($text{'create_epassword'});
$in{'mode'} != 0 || $in{'days'} =~ /^\d+$/ ||
	&error("Invalid or missing number of days");
$in{'mode'} != 1 || $in{'lines'} =~ /^\d+$/ ||
	&error("Invalid or missing number of lines");
$in{'info'} =~ s/\r//g;
$in{'footer'} =~ s/\r//g;

# Create list members file
&lock_file("$ldir/$in{'name'}");
&open_tempfile(MEMS, ">$ldir/$in{'name'}");
&close_tempfile(MEMS);
&set_permissions("$ldir/$in{'name'}");
&unlock_file("$ldir/$in{'name'}");

# Have majordomo create the new config file, by fooling the wrapper
# into thinking it has received an email with a config command
$lfile = "$ldir/$in{'name'}.config";
&lock_file($lfile);
open(WRAPPER, "|$wrapper_path majordomo >/dev/null 2>&1");
print WRAPPER "From: root\n\n";
print WRAPPER "config $in{'name'} $in{'password'}\n\n";
close(WRAPPER);
sleep(3);

# create the .info file
$list = &get_list_config($lfile);
chop($ctime = ctime(time()));
$updated = "[Last updated on: $ctime]\n";
&lock_file("$ldir/$in{'name'}.info");
&open_tempfile(INFO, ">$ldir/$in{'name'}.info");
if (&find_value("date_info", $list) eq "yes") {
	&print_tempfile(INFO, $updated);
	}
&print_tempfile(INFO, $in{'info'});
&close_tempfile(INFO);
&set_permissions("$ldir/$in{'name'}.info");
&unlock_file("$ldir/$in{'name'}.info");

# create the archive directory
$adir = &perl_var_replace(&find_value("filedir", $conf), $conf);
$aext = &perl_var_replace(&find_value("filedir_suffix", $conf), $conf);
if ($adir && $aext) {
	&lock_file("$adir/$in{'name'}$aext");
	mkdir("$adir/$in{'name'}$aext", 0755);
	&set_permissions("$adir/$in{'name'}$aext");
	&unlock_file("$adir/$in{'name'}$aext");
	}

# Create the digest directories if needed
$ddir = &perl_var_replace(&find_value("digest_work_dir", $conf), $conf);
$fdir = &perl_var_replace(&find_value("filedir", $conf), $conf);
$fpfx = &perl_var_replace(&find_value("filedir_suffix", $conf), $conf);
&mkdir_heir("$ddir/$in{'name'}");
&mkdir_heir("$fdir/$in{'name'}$fpfx");

# Create aliases for the new list
&foreign_call($aliases_module, "lock_alias_files", $aliases_files);
&newlist_alias($in{'list'}."-digestify", "|$wrapper_path digest -r -C -l $in{'name'} $in{'name'}-outgoing");
&newlist_alias($in{'name'}, $in{'list'});
&newlist_alias($in{'name'}."-outgoing", ":include:$ldir/$in{'name'}");
&newlist_alias("owner-".$in{'name'}, $in{'owner'});
&newlist_alias("owner-".$in{'name'}."-outgoing", $in{'owner'});
&newlist_alias($in{'name'}."-owner", $in{'owner'});
&newlist_alias($in{'name'}."-approval", $in{'owner'});
&newlist_alias($in{'name'}."-request", "|$wrapper_path ".
				       "majordomo -l $in{'name'}", 1);

# Add the digestify alias for the source list
foreach $a (&foreign_call($aliases_module, "list_aliases", $aliases_files)) {
	if ($a->{'name'} eq "$in{'list'}-list") {
		push(@{$a->{'values'}}, $in{'list'}."-digestify");
		&foreign_call($aliases_module, "modify_alias", $a, $a);
		}
	}
&foreign_call($aliases_module, "unlock_alias_files", $aliases_files);

# Update the new config file
&save_list_directive($list, $lfile, "description", $in{'desc'});
&save_list_directive($list, $lfile, "digest_name", $in{'desc'});
&save_list_directive($list, $lfile, "digest_issue", 1);
&save_list_directive($list, $lfile, "digest_volume", 1);
&save_list_directive($list, $lfile, "admin_passwd", $in{'password'});
&save_list_directive($list, $lfile, "approve_passwd", $in{'password'});
&save_list_directive($list, $lfile, "message_footer", $in{'footer'}, 1)
	if ($in{'footer'});
if ($in{'mode'} == 0) {
	&save_list_directive($list, $lfile, "digest_maxdays", $in{'days'});
	&save_list_directive($list, $lfile, "digest_maxlines", "");
	}
else {
	&save_list_directive($list, $lfile, "digest_maxdays", "");
	&save_list_directive($list, $lfile, "digest_maxlines", $in{'lines'});
	}
&flush_file_lines();
&unlock_file($lfile);
&webmin_log("create", "digest", $in{'name'}, \%in);

# add to this user's ACL
if ($access{'lists'} ne '*') {
	$access{'lists'} .= " $in{'name'}";
	&save_module_acl(\%access);
	}
&redirect("edit_list.cgi?name=$in{'name'}");

# newlist_alias(name, value, last)
sub newlist_alias
{
local $al = { 'name' => $_[0],
	      'values' => [ $_[1] ],
	      'enabled' => 1 };
&foreign_call($aliases_module, "create_alias", $al, $aliases_files, !$_[2]);
}

# mkdir_heir(dir)
sub mkdir_heir
{
if (!-d $_[0]) {
	local $d = $_[0];
	$d =~ s/\/[^\/]+$//;
	&mkdir_heir($d);
	mkdir($_[0], 0755);
	&set_permissions($_[0]);
	}
}
