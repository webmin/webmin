# gnupg-lib.pl
# Functions for managing gnupg keys, signing, encrypting and so on

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
no warnings 'redefine';
use WebminCore;
our ($module_name, %config, $user_module_config_directory, %text);

if (!$module_name) {
	# Only do this if we are the primary library for the usermin gnupg mod
	&init_config();
	&switch_to_remote_user();
	&create_user_config_dirs();
	}
&foreign_require("proc", "proc-lib.pl");

our $gpgpath = $config{'gpg'} || "gpg";

# list_keys()
# Returns an array of all GnuPG keys
sub list_keys
{
my (@rv, %kmap);
&clean_language();
open(GPG, "$gpgpath --list-keys 2>/dev/null |");
while(<GPG>) {
	if (/^pub\s+(\S+)\/(\S+)\s+(\S+)\s+(.*)\s+<(\S+)>/ ||
	    /^pub\s+(\S+)\/(\S+)\s+(\S+)\s+(.*)/) {
		my $k = { 'size' => $1,
			     'key' => $2,
			     'date' => $3,
			     'name' => $4 ? [ $4 ] : [ ],
			     'email' => $5 ? [ $5 ] : $4 ? [ "" ] : [ ],
			     'index' => scalar(@rv) };
		if ($k->{'name'}->[0] &&
		    $k->{'name'}->[0] =~ /\[(expires|expired):\s+(\S+)\]/) {
			# Expiry date, the actual name
			$k->{'expires'} = $2;
			$k->{'expired'} = 1 if ($1 eq 'expired');
			shift(@{$k->{'name'}});
			}
		$kmap{$k->{'key'}} = $k;
		while(1) {
			$_ = <GPG>;
			last if ($_ !~ /\S/);
			if (/^sub\s+(\S+)\/(\S+)\s+/) {
				push(@{$k->{'key2'}}, $2);
				}
			elsif (/^uid\s+\[[^\]]+\]\s+(.*)\s+<(\S+)>/ ||
			       /^uid\s+(.*)\s+<(\S+)>/ ||
			       /^uid\s+(.*)/) {
				push(@{$k->{'name'}}, $1);
				push(@{$k->{'email'}}, $2);
				}
			}
		push(@rv, $k);
		}
	}
close(GPG);
open(GPG, "$gpgpath --list-secret-keys 2>/dev/null |");
while(<GPG>) {
	if (/^sec\s+(\S+)\/(\S+)\s+(\S+)\s+(.*)/ && $kmap{$2}) {
		$kmap{$2}->{'secret'}++;
		}
	}
close(GPG);
&reset_environment();
return @rv;
}

# list_keys_sorted()
# Returns a list of all keys, sorted by name
sub list_keys_sorted
{
return sort { lc($a->{'name'}->[0]) cmp lc($b->{'name'}->[0]) }
	    &list_keys();
}

# list_secret_keys()
# List list_keys, but only returns secret ones
sub list_secret_keys
{
return grep { $_->{'secret'} } &list_keys();
}

# key_fingerprint(&key)
sub key_fingerprint
{
my $fp;
local $_;
&clean_language();
open(GPG, "$gpgpath --fingerprint \"$_[0]->{'name'}->[0]\" 2>/dev/null |");
while(<GPG>) {
	if (/fingerprint\s+=\s+(.*)/) {
		$fp = $1;
		}
	}
close(GPG);
&reset_environment();
return $fp;
}

# get_passphrase(&key)
sub get_passphrase
{
open(PASS, "$user_module_config_directory/pass.$_[0]->{'key'}") ||
  open(PASS, "$user_module_config_directory/pass") || return undef;
my $pass = <PASS>;
close(PASS);
chop($pass);
return $pass;
}

# put_passphrase(pass, &key)
sub put_passphrase
{
my $fh;
&open_tempfile($fh, ">$user_module_config_directory/pass.$_[1]->{'key'}");
&print_tempfile($fh, $_[0],"\n");
&close_tempfile($fh);
chmod(0700, "$user_module_config_directory/pass.$_[1]->{'key'}");
}

# encrypt_data(data, &result, &key|&keys, ascii)
# Encrypts some data with the given public key and returns the result, and
# returns an error message or undef on failure
sub encrypt_data
{
my $srcfile = &transname();
my @keys = ref($_[2]) eq 'ARRAY' ? @{$_[2]} : ( $_[2] );
my $rcpt = join(" ", map { "--recipient \"$_->{'name'}->[0]\"" } @keys);
&write_entire_file($srcfile, $_[0]);
my $dstfile = &transname();
my $ascii = $_[3] ? "--armor" : "";
my $comp = $config{'compress'} eq '' ? "" :
		" --compress-algo $config{'compress'}";
&clean_language();
my $cmd = "$gpgpath --output $dstfile $rcpt $ascii $comp --encrypt $srcfile";
my ($fh, $fpid) = &foreign_call("proc", "pty_process_exec", $cmd);
while(1) {
	my $rv = &wait_for($fh, "anyway");
	if ($rv == 0) {
		syswrite($fh, "yes\n", length("yes\n"));
		}
	elsif ($rv < 0) {
		last;
		}
	}
close($fh);
&reset_environment();
unlink($srcfile);
my $dst = &read_entire_file($dstfile);
unlink($dstfile);
if ($dst) {
	${$_[1]} = $dst;
	return undef;
	}
else {
	return $wait_for_input;
	}
}

# decrypt_data(data, &result)
# Decrypts some data encrypted for the current GnuPG user, and puts the results
# into &result. Returns an error message or undef on success.
sub decrypt_data
{
my $srcfile = &transname();
&write_entire_file($srcfile, $_[0]);
my $dstfile = &transname();
&clean_language();
my $cmd = "$gpgpath --output $dstfile --decrypt $srcfile";
my ($fh, $fpid) = &foreign_call("proc", "pty_process_exec", $cmd);
my ($error, $seen_pass, $pass, $key, $keyid);
while(1) {
	my $rv = &wait_for($fh, "passphrase:", "key,\\s+ID\\s+(\\S+),", "failed.*\\n", "error.*\\n", "invalid.*\\n", "signal caught.*\\n");
	if ($rv == 0) {
		last if ($seen_pass++);
		sleep(1);
		syswrite($fh, "$pass\n", length("$pass\n"));
		}
	elsif ($rv == 1) {
		$keyid = $matches[1];
		($key) = grep { &indexof($matches[1], @{$_->{'key2'}}) >= 0 }
			      &list_secret_keys();
		$pass = &get_passphrase($key) if ($key);
		}
	elsif ($rv > 1) {
		$error++;
		last;
		}
	elsif ($rv < 0) {
		last;
		}
	}
close($fh);
&reset_environment();
unlink($srcfile);
my $dst = &read_entire_file($dstfile);
unlink($dstfile);
if (!$keyid) {
	return $text{'gnupg_ecryptid'};
	}
elsif (!$key) {
	return &text('gnupg_ecryptkey', "<tt>$keyid</tt>");
	}
elsif (!defined($pass)) {
	return &text('gnupg_ecryptpass', $key->{'name'}->[0]).". ".
	    &text('gnupg_canset', "/gnupg/edit_key.cgi?key=$key->{'key'}").".";
	}
elsif ($error || $seen_pass > 1) {
	return "<pre>$wait_for_input</pre>";
	}
else {
	${$_[1]} = $dst;
	return undef;
	}
}

# sign_data(data, \&result, &key, mode)
# Signs the given data and returns the result. Mode 0 = binary signature
# mode 1 = ascii signature at end, mode 2 = ascii signature only
sub sign_data
{
my $srcfile = &transname();
&write_entire_file($srcfile, $_[0]);
my $dstfile = &transname();
my $cmd;
if ($_[3] == 0) {
	$cmd = "$gpgpath --output $dstfile --default-key $_[2]->{'key'} --sign $srcfile";
	}
elsif ($_[3] == 1) {
	$cmd = "$gpgpath --output $dstfile --default-key $_[2]->{'key'} --clearsign $srcfile";
	}
elsif ($_[3] == 2) {
	$cmd = "$gpgpath --armor --output $dstfile --default-key $_[2]->{'key'} --detach-sig $srcfile";
	}
&clean_language();
my ($fh, $fpid) = &foreign_call("proc", "pty_process_exec", $cmd);
&reset_environment();
my ($error, $seen_pass);
my $pass = &get_passphrase($_[2]);
if (!defined($pass)) {
	return $text{'gnupg_esignpass'}.". ".
	    &text('gnupg_canset', "/gnupg/edit_key.cgi?key=$_[2]->{'key'}").".";
	}
while(1) {
	my $rv = &wait_for($fh, "passphrase:", "failed", "error");
	if ($rv == 0) {
		last if ($seen_pass++);
		sleep(1);
		syswrite($fh, "$pass\n", length("$pass\n"));
		}
	elsif ($rv > 0) {
		$error++;
		last;
		}
	elsif ($rv < 0) {
		last;
		}
	}
close($fh);
unlink($srcfile);
my $dst = &read_entire_file($dstfile);
unlink($dstfile);
if ($error || $seen_pass > 1) {
	return "<pre>$wait_for_input</pre>";
	}
else {
	${$_[1]} = $dst;
	return undef;
	}
}

# verify_data(data, [signature])
# Verifies the signature on some data, and returns a status code and a message
# code 0 = verified successfully, message contains signer
# code 1 = verified successfully but no trust chain, message contains signer
# code 2 = failed to verify, message contains signer
# code 3 = do not have signers public key, message contains ID
# code 4 = verification totally failed, message contains reason
sub verify_data
{
my $datafile = &transname();
&write_entire_file($datafile, $_[0]);
my $cmd;
my $sigfile;
if (!$_[1]) {
	$cmd = "$gpgpath --verify $datafile";
	}
else {
	$sigfile = &transname();
	&write_entire_file($sigfile, $_[1]);
	$cmd = "$gpgpath --verify $sigfile $datafile";
	}
#local ($fh, $fpid) = &foreign_call("proc", "pty_process_exec", $cmd);
#&wait_for($fh);
#close($fh);
#local $out = $wait_for_input;
&clean_language();
my $out = &backquote_command("$cmd 2>&1 </dev/null") || "";
&reset_environment();
unlink($datafile);
unlink($sigfile) if ($sigfile);
if ($out =~ /BAD signature from "(.*)"/i) {
	return (2, $1);
	}
elsif ($out =~ /key ID (\S+).*\n.*not found/i) {
	return (3, $1);
	}
elsif ($out =~ /Good signature from "(.*)"/i) {
	my $signer = $1;
	if ($out =~ /warning/) {
		return (1, $signer);
		}
	else {
		return (0, $signer);
		}
	}
else {
	return (4, $out);
	}
}

# read_entire_file(file)
sub read_entire_file
{
my ($rv, $buf);
open(FILE, $_[0]) || return undef;
while(read(FILE, $buf, 1024) > 0) {
	$rv .= $buf;
	}
close(FILE);
return $rv;
}

# write_entire_file(file, data)
sub write_entire_file
{
my $fh;
&open_tempfile($fh, ">$_[0]");
&print_tempfile($fh, $_[1]);
&close_tempfile($fh);
}

# get_trust_level(&key)
# Returns the trust level of a key
sub get_trust_level
{
&clean_language();
my $cmd = "$gpgpath --edit-key \"$_[0]->{'name'}->[0]\"";
my ($fh, $fpid) = &foreign_call("proc", "pty_process_exec", $cmd);
my $rv = &wait_for($fh, "trust:\\s+(.)", "command>");
my $tr;
if ($rv == 0) {
	$tr = $matches[1] eq "q" ? 1 : $matches[1] eq "n" ? 2 :
	      $matches[1] eq "m" ? 3 : $matches[1] eq "f" ? 4 : 0;
	}
else {
	$tr = -1;
	}
syswrite($fh, "quit\n", length("quit\n"));
close($fh);
&reset_environment();
return $tr;
}

# delete_key(&key)
# Delete one public or secret key
sub delete_key
{
my ($key) = @_;
if ($key->{'secret'}) {
	&clean_language();
	my $cmd = "$gpgpath --delete-secret-key \"$key->{'name'}->[0]\"";
	my ($fh, $fpid) = &foreign_call("proc", "pty_process_exec", $cmd);
	&wait_for($fh, "\\?");
	syswrite($fh, "y\n");
	&wait_for($fh, "\\?");
	syswrite($fh, "y\n");
	sleep(1);
	close($fh);
	&reset_environment();
	}
&clean_language();
my $cmd = "$gpgpath --delete-key \"$key->{'name'}->[0]\"";
my ($fh, $fpid) = &foreign_call("proc", "pty_process_exec", $cmd);
&wait_for($fh, "\\?");
syswrite($fh, "y\n");
sleep(1);
close($fh);
&reset_environment();
}

# default_email_address()
# Returns the current user's email address, or undef if not possible
sub default_email_address
{
if (&foreign_check("mailbox")) {
	&foreign_require("mailbox", "mailbox-lib.pl");
	my ($fromaddr) = &mailbox::split_addresses(
			&mailbox::get_preferred_from_address());
	if ($fromaddr) {
		return $fromaddr->[0];
		}
	}
return undef;
}

# fetch_gpg_key(id)
# Imports a key by ID from the configured keyserver. Returns 0 on success,
# 1 on failure, 2 if there was no change, 3 if the import appeared to succeed
# but the key isn't visible.
sub fetch_gpg_key
{
my ($id) = @_;
my $out = &backquote_command(
	"$gpgpath --keyserver ".quotemeta($config{'keyserver'}).
	" --recv-key ".quotemeta($id)." 2>&1 </dev/null") || "";
my @keys = &list_keys();
my ($key) = grep { lc($_->{'key'}) eq lc($id) } @keys;
if ($?) {
	return wantarray ? (1, $out) : 1;
	}
elsif ($out =~ /not\s+changed/) {
	return wantarray ? (2, $key) : 2;
	}
else {
	if ($key) {
		return (0, $key);
		}
	else {
		return (3, $out);
		}
	}
}

# search_gpg_keys(word)
# Searches the configured keyserver for GPG keys matching some name or email
# address, and returns them as a list of hash refs
sub search_gpg_keys
{
my ($word) = @_;
my $cmd = "$gpgpath --keyserver ".quotemeta($config{'keyserver'}).
	     " --search-keys ".quotemeta($word);
my ($fh, $fpid) = &foreign_call("proc", "pty_process_exec", $cmd);
my @rv;
while(1) {
	$wait_for_input = undef;
	my $rv = &wait_for($fh, "N.ext, or Q.uit");
	if ($rv < 0) { last; }
	my $count = 0;
	my $key;
	foreach my $l (split(/\r?\n/, $wait_for_input)) {
		if ($l =~ /^\(\d+\)\s+(\d+)\s+bit\s+(\S+)\s+key\s+(\S+)/) {
			# Key with no name .. skip!
			}
		elsif ($l =~ /^\(\d+\)\s+(\S.*)\s+<(\S+)>/ ||
		       $l =~ /^\(\d+\)\s+(\S.*)/) {
			# First name and email for a key
			$key = { 'name' => [ $1 ],
				 'email' => [ $2 ] };
			$key->{'name'} =~ s/\s+$//;
			push(@rv, $key);
			$count++;
			}
		elsif ($l =~ /^\s+(\S.*)\s+<(\S+)>/ && $key) {
			# Additional name and email
			push(@{$key->{'name'}}, $1);
			push(@{$key->{'email'}}, $2);
			}
		elsif ($l =~ /\s+(\d+)\s+bit\s+(\S+)\s+key\s+(\S+),\s+created:\s+(\S+)/ && $key) {
			# Size and ID
			$key->{'size'} = $1;
			$key->{'key'} = $3;
			$key->{'date'} = $4;
			if ($l =~ /revoked/) {
				$key->{'revoked'} = 1;
				}
			$key = undef;
			}
		}
	if ($count) {
		&sysprint($fh, "N\n");
		}
	else {
		last;
		}
	}
close($fh);
return @rv;
}

1;

