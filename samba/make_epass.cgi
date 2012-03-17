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
print "<table border width=100%><tr><td bgcolor=#c0c0c0><pre>\n";
setpwent();
while(@uinfo = getpwent()) {
	# Get new and existing user details
	local ($c1, $c2, $m);
	local $huinfo = &html_escape($uinfo[0]);
	$uexists{$uinfo[0]}++;
	local $su = $suser{$uinfo[0]};

	# Check if this user would be skipped
	local $skipme;
	foreach $s (@skip) {
		if ($s eq $uinfo[0]) { $skipme++; }
		elsif ($s =~ /^(\d+)$/ && $s == $uinfo[2]) { $skipme++; }
		elsif ($s =~ /^(\d+)\-(\d+)$/ &&
		       $uinfo[2] >= $1 && $uinfo[2] <= $2) { $skipme++; }
		elsif ($s =~ /^(\d+)\-$/ && $uinfo[2] >= $1) { $skipme++; }
		elsif ($s =~ /^\-(\d+)$/ && $uinfo[2] <= $1) { $skipme++; }
		elsif ($s =~ /^\@(.*)$/) {
			local @ginfo = getgrnam($1);
			local @mems = split(/\s+/, $ginfo[3]);
			$skipme++ if ($uinfo[3] == $ginfo[2] ||
				      &indexof($uinfo[0], @mems) >= 0);
			}
		}
	if ($skipme) {
		$m = "$huinfo $text{'mkpass_skip'}";
		}

	elsif ($su && $in{"update"}) {
		if ($su->{'opts'}) {
			# new-style user
			if ($uinfo[2] == $su->{'uid'}) {
				$m = "$huinfo $text{'mkpass_same'}";
				}
			else {
				$su->{'uid'} = $uinfo[2];
				$su->{'real'} = $uinfo[6];
				&modify_user($su);
				$m = "$huinfo $text{'mkpass_update'}";
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
				$m = "$huinfo $text{'mkpass_same'}";
				}
			else {
				$su->{'uid'} = $uinfo[2];
				$su->{'real'} = $uinfo[6];
				$su->{'home'} = $uinfo[7];
				$su->{'shell'} = $uinfo[8];
				&modify_user($su);
				$m = "$huinfo $text{'mkpass_update'}";
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
		$m = "$huinfo being added";
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
		&create_user($nu);
		$created++;
		}
	if ($m) { printf "$c1%-40.40s$c2%s", $m, ++$c%2 ? "" : "\n"; }
	}
endpwent() if ($gconfig{'os_type'} ne 'hpux');

# Delete missing users, if needed
if ($in{"delete"}) {
	foreach $u (@ulist) {
		if (!$uexists{$u->{'name'}}) {
			# delete this samba user..
			$m = &html_escape($u->{'name'})." $text{'mkpass_del'}";
			&delete_user($u);
			printf "<b><font color=#ff0000>%-40.40s</font></b>%s",
				$m, ++$c%2 ? "" : "\n";
			$deleted++;
			}
		}
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

print "</pre></td></tr></table>\n";
&ui_print_footer("", $text{'index_sharelist'});

