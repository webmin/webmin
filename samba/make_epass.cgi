#!/usr/local/bin/perl
# make_epass.cgi
# Create or update the samba password file from the list of Unix users

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pmpass'}")
		unless $access{'maint_makepass'};
# make
&ui_print_header(undef, $text{'mkpass_title'}, "");
&error_setup($text{'mkpass_convfail'});
$| = 1;

if ($config{'smb_passwd'} =~ /^(.*)\/([^\/]+)$/) {
	mkdir($1, 0700);
	}
&lock_file($config{'smb_passwd'});
@ulist = &list_users();
map { $suser{$_->{'name'}} = $_ } @ulist;

print "$text{'mkpass_msg'}<p>\n";
@skip = split(/[ \t,]/ , $in{"skip_list"});
@include = split(/[ \t,]/ , $in{"include_list"});
print &ui_columns_start([ $text{'mkpass_user'}, $text{'mkpass_action'} ]);
setpwent();
while(@uinfo = getpwent()) {
	# Get new and existing user details
	local ($c1, $c2, $m);
	local $huinfo = &html_escape($uinfo[0]);
	$uexists{$uinfo[0]}++;
	local $su = $suser{$uinfo[0]};

	# Check if this user would be skipped
	if ($in{'who'} == 1 && &check_user_list(\@uinfo, \@skip) ||
	    $in{'who'} == 0 && !&check_user_list(\@uinfo, \@include)) {
		$skipcount++;
		}

	elsif ($su && $in{"update"}) {
		if ($su->{'opts'}) {
			# new-style user
			if ($uinfo[2] == $su->{'uid'}) {
				$m = $text{'mkpass_same'};
				}
			else {
				$su->{'uid'} = $uinfo[2];
				$su->{'real'} = $uinfo[6];
				&modify_user($su);
				$m = $text{'mkpass_update'};
				$c1 = "<i>"; $c2 = "</i>";
				$modified++;
				}
			}
		else {
			# old-style user
			if ($uinfo[2] == $su->{'uid'} &&
			    $uinfo[6] eq $su->{'real'} &&
			    $uinfo[7] eq $su->{'home'} &&
			    $uinfo[8] eq $su->{'shell'}) {
				$m = $text{'mkpass_same'};
				}
			else {
				$su->{'uid'} = $uinfo[2];
				$su->{'real'} = $uinfo[6];
				$su->{'home'} = $uinfo[7];
				$su->{'shell'} = $uinfo[8];
				&modify_user($su);
				$m = $text{'mkpass_update'};
				$c1 = "<i>"; $c2 = "</i>";
				$modified++;
				}
			}
		}
	elsif ($in{"add"} && !$su) {
		local $nu = { 'name' => $uinfo[0],
			      'uid' => $uinfo[2] };
		local @flags = ("U");
		$c1 = "<b>"; $c2 = "</b>";
		$m = $text{'mkpass_add'};
		if ($in{'newmode'} == 0) {
			$nu->{'pass1'} = "NO PASSWORDXXXXXXXXXXXXXXXXXXXXX";
			$nu->{'pass2'} = $nu->{'pass1'};
			push(@flags, "N");
			}
		else {
			$nu->{'pass1'} = $nu->{'pass2'} = ("X" x 32);
			if ($in{'newmode'} == 2) {
				$setpass{$uinfo[0]} = $in{'newpass'};
				}
			else { push(@flags, "D"); }
			}
		if ($samba_version < 2) {
			$nu->{'real'} = $uinfo[6];
			$nu->{'home'} = $uinfo[7];
			$nu->{'shell'} = $uinfo[8];
			}
		else {
			$nu->{'opts'} = \@flags;
			}
		&create_user($nu, $in{'newmode'} == 2 ? $in{'newpass'} : undef);
		$created++;
		}
	if ($m) {
		print &ui_columns_row([
			&html_escape($uinfo[0]),
			$c1.$m.$c2 ]);
		}
	}
endpwent() if ($gconfig{'os_type'} ne 'hpux');

# Delete missing users, if needed
if ($in{"delete"}) {
	foreach $u (@ulist) {
		if (!$uexists{$u->{'name'}}) {
			# delete this samba user..
			&delete_user($u);
			print &ui_columns_row([
			    &html_escape($u->{'name'}),
			    "<font color=#ff0000>$text{'mkpass_del'}</font>",
			    ]);
			$deleted++;
			}
		}
	}
print &ui_columns_end();
if ($skipcount) {
	print &text('mkpass_skipcount', $skipcount),"<p>\n";
	}

# Update the passwords of new users
foreach $u (keys %setpass) {
	&set_password($u, $setpass{$u}) ||
		&error($text{'mkpass_passfail'});
	}
&unlock_file($config{'smb_passwd'});
&webmin_log("epass", undef, undef, { 'modified' => $modified,
				     'created' => $created,
				     'deleted' => $deleted } );

&ui_print_footer("", $text{'index_sharelist'});

# check_user_list(&uinfo, &list)
# Checks if some user matches a username / UID list
sub check_user_list
{
local ($uinfo, $skip) = @_;
local $skipme = 0;
foreach my $s (@$skip) {
	if ($s eq $uinfo->[0]) { $skipme++; }
	elsif ($s =~ /^(\d+)$/ && $s == $uinfo->[2]) { $skipme++; }
	elsif ($s =~ /^(\d+)\-(\d+)$/ &&
	       $uinfo->[2] >= $1 && $uinfo->[2] <= $2) { $skipme++; }
	elsif ($s =~ /^(\d+)\-$/ && $uinfo->[2] >= $1) { $skipme++; }
	elsif ($s =~ /^\-(\d+)$/ && $uinfo->[2] <= $1) { $skipme++; }
	elsif ($s =~ /^\@(.*)$/) {
		local @ginfo = getgrnam($1);
		local @mems = split(/\s+/, $ginfo[3]);
		$skipme++ if ($uinfo->[3] == $ginfo[2] ||
			      &indexof($uinfo->[0], @mems) >= 0);
		}
	}
return $skipme;
}
