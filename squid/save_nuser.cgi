#!/usr/local/bin/perl
# save_nuser.cgi
# Save, create or delete a proxy user

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config, $module_name);
require './squid-lib.pl';
if ($config{'crypt_conf'} == 1) {
	eval "use Digest::MD5";
	if ($@) {
        	&error(&text('eauth_nomd5', $module_name));
		}
	}

$access{'proxyauth'} || &error($text{'eauth_ecannot'});
&ReadParse();
my $conf = &get_config();
my $file = &get_auth_file($conf);
&lock_file($file);
my @users = &list_auth_users($file);

my $user = $users[$in{'index'}];
if ($in{'delete'}) {
	&replace_file_line($file, $user->{'line'});
	}
else {
	&error_setup($text{'suser_ftsu'});
	$in{'user'} =~ /^[^:\s]+$/ || &error($text{'suser_emsg1'});
	my ($same) = grep { $_->{'user'} eq $in{'user'} } @users;
	my $cmt = $in{'enabled'} ? "" : "#";
	if ($in{'new'}) {
		!$same || &error($text{'suser_etaken'});
		my $pass = &encryptpwd($in{'pass'}, undef);
		my $fh = "FILE";
		&open_tempfile($fh, ">>$file");
		&print_tempfile($fh, "$cmt$in{'user'}:$pass\n");
		&close_tempfile($fh);
		}
	else {
		!$same || $same->{'user'} eq $user->{'user'} ||
			 &error($text{'suser_etaken'});
		my $pass = $in{'pass_def'} ? $user->{'pass'}
					: &encryptpwd($in{'pass'}, undef);
		&replace_file_line($file, $user->{'line'},
				   "$cmt$in{'user'}:$pass\n");
		}
	}
&unlock_file($file);
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'user', $in{'user'} ? $in{'user'} : $user->{'user'});
&redirect("edit_nauth.cgi");

sub encryptpwd {
  my ($pass, $salt) = @_;
  if ($config{'crypt_conf'}) {
    my $pwd = $_[0];
    my $encryptpwd = new MD5;
    $encryptpwd->add($pwd);
    $pwd = encode_base64($encryptpwd->hexdigest());
    chomp($pwd);
    $pwd = "\$$pwd\$";
    return $pwd;
    }
    else {
      $salt ||= substr(time(), -2);
      my $pwd = &unix_crypt($pass, $salt);
      return $pwd;
      }
  }
