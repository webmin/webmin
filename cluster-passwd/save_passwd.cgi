#!/usr/local/bin/perl
# save_passwd.cgi
# Change a user's password

require './cluster-passwd-lib.pl';
&foreign_require("useradmin", "user-lib.pl");
&error_setup($text{'passwd_err'});
&ReadParse();
@hosts = &cluster_useradmin::list_useradmin_hosts();
@ulist = &get_all_users(\@hosts);
($user) = grep { $_->{'user'} eq $in{'user'} } @ulist;
$user || &error($passwd::text{'passwd_euser'});
&can_edit_passwd($user) || &error($passwd::text{'passwd_ecannot'});

# Validate inputs
if ($access{'old'} == 1 ||
    $access{'old'} == 2 && $user->{'user'} ne $remote_user) {
	&useradmin::validate_password($in{'old'}, $user->{'pass'}) ||
		&error($passwd::text{'passwd_eold'});
	}
if ($access{'repeat'}) {
	$in{'new'} eq $in{'repeat'} || &error($passwd::text{'passwd_erepeat'});
	}
$err = &useradmin::check_password_restrictions(
	$in{'new'}, $user->{'user'}, $user);
&error($err) if ($err);

# Output header
$| = 1;
$theme_no_table++;
&ui_print_header(undef, $text{'passwd_title'}, "");

# Do it on all servers
&modify_on_hosts(\@hosts, $user->{'user'}, $in{'new'},
		 ($access{'others'} == 1 ||
		  $access{'others'} == 2 && $in{'others'}), \&print_func);

# Log the change
delete($user->{'plainpass'});
delete($user->{'pass'});
&webmin_log("passwd", undef, $user->{'user'}, $user);

&ui_print_footer($in{'one'} ? ( "/", $text{'index'} )
			    : ( "", $passwd::text{'index_return'} ));

# print_func(mode, message)
sub print_func
{
if ($_[0] == -1) {
	print "<b>$_[1]</b><p>\n";
	print "<ul>\n";
	}
elsif ($_[0] == -2) {
	print "$_[1]<br>\n";
	}
elsif ($_[0] == -3) {
	print "$_[1]<p>\n";
	}
elsif ($_[0] == -4) {
	print "</ul>\n";
	}
elsif ($_[0] > 0) {
	print "$_[1]<p>\n";
	print "</ul>\n";
	}
}
