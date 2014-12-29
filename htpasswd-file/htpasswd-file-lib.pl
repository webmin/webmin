# htpasswd-file-lib.pl
# Functions for reading and writing a .htpasswd format file
# XXX md5 and old password

use strict;
use warnings;
BEGIN { push(@INC, ".."); };
use WebminCore;
our (%access, $module_name, %config, %gconfig, %list_authusers_cache,
     %list_authgroups_cache, $null_file);
if (!$module_name) {
	&init_config();
	%access = &get_module_acl();
	}
do 'md5-lib.pl';
our $htdigest_command = &has_command("htdigest") || &has_command("htdigest2");

# list_users([file])
# Returns an array of user and password details from the given file
sub list_users
{
my ($file) = @_;
$file ||= $config{'file'};
if (!defined($list_authusers_cache{$file})) {
	$list_authusers_cache{$file} = [ ];
	local $_;
	my $lnum = 0;
	my $count = 0;
	if (open(HTPASSWD, $file)) {
		while(<HTPASSWD>) {
			if (/^(#?)\s*([^:]+):(\S*)/) {
				push(@{$list_authusers_cache{$file}},
					  { 'user' => $2,
					    'pass' => $3,
					    'enabled' => !$1,
					    'file' => $file,
					    'line' => $lnum,
					    'index' => $count++ });
				}
			$lnum++;
			}
		close(HTPASSWD);
		}
	}
return $list_authusers_cache{$file};
}

# list_digest_users([file])
# Returns an array of user, domain and password details from the given file
sub list_digest_users
{
my ($file) = @_;
$file ||= $config{'file'};
if (!defined($list_authusers_cache{$file})) {
	$list_authusers_cache{$file} = [ ];
	local $_;
	my $lnum = 0;
	my $count = 0;
	if (open(HTPASSWD, $file)) {
		while(<HTPASSWD>) {
			if (/^(#?)\s*(\S+):(\S+):(\S*)/) {
				push(@{$list_authusers_cache{$file}},
					  { 'user' => $2,
					    'dom' => $3,
					    'pass' => $4,
					    'enabled' => !$1,
					    'digest' => 1,
					    'file' => $file,
					    'line' => $lnum,
					    'index' => $count++ });
				}
			$lnum++;
			}
		close(HTPASSWD);
		}
	}
return $list_authusers_cache{$file};
}

# modify_user(&user)
sub modify_user
{
my $lref = &read_file_lines($_[0]->{'file'});
if ($_[0]->{'digest'}) {
	$lref->[$_[0]->{'line'}] = ($_[0]->{'enabled'} ? "" : "#").
			   "$_[0]->{'user'}:$_[0]->{'dom'}:$_[0]->{'pass'}";
	}
else {
	$lref->[$_[0]->{'line'}] = ($_[0]->{'enabled'} ? "" : "#").
				   "$_[0]->{'user'}:$_[0]->{'pass'}";
	}
&flush_file_lines($_[0]->{'file'});
}

# create_user(&user, [file])
sub create_user
{
$_[0]->{'file'} = $_[1] || $config{'file'};
my $lref = &read_file_lines($_[0]->{'file'});
$_[0]->{'line'} = @$lref;
if ($_[0]->{'digest'}) {
	push(@$lref, ($_[0]->{'enabled'} ? "" : "#").
		     "$_[0]->{'user'}:$_[0]->{'dom'}:$_[0]->{'pass'}");
	}
else {
	push(@$lref, ($_[0]->{'enabled'} ? "" : "#").
		     "$_[0]->{'user'}:$_[0]->{'pass'}");
	}
&flush_file_lines($_[0]->{'file'});
$list_authusers_cache{$_[0]->{'file'}} ||= [ ];
$_[0]->{'index'} = @{$list_authusers_cache{$_[0]->{'file'}}};
push(@{$list_authusers_cache{$_[0]->{'file'}}}, $_[0]);
}

# delete_user(&user)
sub delete_user
{
my $lref = &read_file_lines($_[0]->{'file'});
splice(@$lref, $_[0]->{'line'}, 1);
&flush_file_lines($_[0]->{'file'});
splice(@{$list_authusers_cache{$_[0]->{'file'}}}, $_[0]->{'index'}, 1);
map { $_->{'line'}-- if ($_->{'line'} > $_[0]->{'line'}) }
    @{$list_authusers_cache{$_[0]->{'file'}}};
}

# encrypt_password(string, [old], md5mode)
sub encrypt_password
{
my ($str, $old, $mode) = @_;
$mode ||= 0;
&seed_random();
if ($mode == 1) {
	# MD5
	return &encrypt_md5($str, $old);
	}
elsif ($mode == 2) {
	# SHA1
	return &encrypt_sha1($str);
	}
elsif ($mode == 3) {
	# Digest
	return &digest_password(undef, undef, $str);
	}
else {
	# Crypt
	if ($gconfig{'os_type'} eq 'windows' && &has_command("htpasswd")) {
		# Call htpasswd program
		my $qp = quotemeta($str);
		my $out = &backquote_command(
			"htpasswd -n -b foo $qp 2>&1 <$null_file");
		if ($out =~ /^foo:(\S+)/) {
			return $1;
			}
		else {
			&error("htpasswd failed : $out");
			}
		}
	else {
		# Use built-in encryption code
		my $salt = $old ||
			   chr(int(rand(26))+65).chr(int(rand(26))+65);
		return &unix_crypt($str, $salt);
		}
	}
}

# digest_password(user, realm, pass)
# Encrypts a password in the format used by htdigest
sub digest_password
{
my ($user, $dom, $pass) = @_;
my $temp = &tempname();
eval "use Digest::MD5";
if (!$@) {
	# Use the digest::MD5 module to do the encryption directly
	return Digest::MD5::md5_hex("$user:$dom:$pass");
	}
else {
	# Shell out to htdigest command
	&foreign_require("proc", "proc-lib.pl");
	my ($fh, $fpid) = &proc::pty_process_exec("$htdigest_command -c $temp ".quotemeta($dom)." ".quotemeta($user));
	&wait_for($fh, "password:");
	&sysprint($fh, "$pass\n");
	&wait_for($fh, "password:");
	&sysprint($fh, "$pass\n");
	&wait_for($fh);
	close($fh);
	my $tempusers = &list_digest_users($temp);
	unlink($temp);
	return $tempusers->[0]->{'pass'};
	}
}

# list_groups(file)
# Returns an array of group details from the given file
sub list_groups
{
my $file = $_[0];
if (!defined($list_authgroups_cache{$file})) {
	$list_authgroups_cache{$file} = [ ];
	local $_;
	my $lnum = 0;
	my $count = 0;
	open(HTPASSWD, $file);
	while(<HTPASSWD>) {
		if (/^(#?)\s*(\S+):\s*(.*)/) {
			push(@{$list_authgroups_cache{$file}},
				  { 'group' => $2,
				    'enabled' => !$1,
				    'members' => [ split(/\s+/, $3) ],
				    'file' => $file,
				    'line' => $lnum,
				    'index' => $count++ });
			}
		$lnum++;
		}
	close(HTPASSWD);
	}
return $list_authgroups_cache{$file};
}

# modify_group(&group)
sub modify_group
{
my $lref = &read_file_lines($_[0]->{'file'});
$lref->[$_[0]->{'line'}] = ($_[0]->{'enabled'} ? "" : "#").
			   "$_[0]->{'group'}: ".
			   join(" ", @{$_[0]->{'members'}});
&flush_file_lines();
}

# create_group(&group, [file])
sub create_group
{
$_[0]->{'file'} = $_[1] || $config{'file'};
my $lref = &read_file_lines($_[0]->{'file'});
$_[0]->{'line'} = @$lref;
push(@$lref, ($_[0]->{'enabled'} ? "" : "#").
	      "$_[0]->{'group'}: ".
	      join(" ", @{$_[0]->{'members'}}));
&flush_file_lines();
$_[0]->{'index'} = @{$list_authgroups_cache{$_[0]->{'file'}}};
push(@{$list_authgroups_cache{$_[0]->{'file'}}}, $_[0]);
}

# delete_group(&group)
sub delete_group
{
my $lref = &read_file_lines($_[0]->{'file'});
splice(@$lref, $_[0]->{'line'}, 1);
&flush_file_lines();
splice(@{$list_authgroups_cache{$_[0]->{'file'}}}, $_[0]->{'index'}, 1);
map { $_->{'line'}-- if ($_->{'line'} > $_[0]->{'line'}) }
    @{$list_authgroups_cache{$_[0]->{'file'}}};
}


1;

