#!/usr/local/bin/perl
# save_pass.cgi
# Save inputs from conf_pass.cgi

require './samba-lib.pl';
&ReadParse();
&lock_file($config{'smb_conf'});
$global = &get_share("global");

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcp'}") unless $access{'conf_pass'};

&error_setup($text{'savepass_fail'});
$nopass = (`$config{samba_password_program} 2>&1 </dev/null` =~ /encryption not selected/);
if ($in{encrypt_passwords} eq "yes" && $nopass) {
	&error($text{'savepass_nopass'});
	}
&setval("encrypt passwords", $in{encrypt_passwords}, "no");

&setval("null passwords", $in{null_passwords}, "no");

if (!$in{passwd_program_def} && !$in{passwd_program}) {
	&error($text{'savepass_passwd'});
	}
&setval("passwd program", $in{passwd_program_def}?"":$in{passwd_program}, "");

&setval("unix password sync", $in{'unix_password_sync'}, "no");

if ($in{passwd_chat_def}) { &delval("passwd chat"); }
else {
	for($i=0; defined($in{"chat_recv_$i"}); $i++) {
		push(@chat, $in{"chat_recv_$i"});
		push(@chat, $in{"chat_send_$i"});
		}
	$clast = -1;
	for($i=0; $i<@chat; $i++) {
		if ($chat[$i] =~ /\S/) { $clast = $i; }
		}
	if ($clast < 0) {
		&error($text{'savepass_chat'});
		}
	@chat = @chat[0 .. $clast];
	@chat = map { /^$/ ? "." : /^\S+$/ ? $_ : "\"$_\""; } @chat;
	&setval("passwd chat", join(' ', @chat));
	}

$mapfile = &getval("username map");
if ($in{username_map_def}) { &delval("username map"); }
else {
	if (!$mapfile) {
		$config{smb_conf} =~ /^(.*)\/[^\/]+$/;
		$mapfile = "$1/user.map";
		}
	&setval("username map", $mapfile);
	for($i=0; defined($in{"umap_unix_$i"}); $i++) {
		if ($in{"umap_unix_$i"} =~ /\S/ && $in{"umap_win_$i"} =~ /\S/) {
			if ($in{"umap_win_$i"} =~ /\s/) {
				push(@umap, $in{"umap_unix_$i"}."=\"".
					    $in{"umap_win_$i"}."\"");
				}
			else {
				push(@umap, $in{"umap_unix_$i"}."=".
					    $in{"umap_win_$i"});
				}
			}
		}
	&open_lock_tempfile(UMAP, "> $mapfile");
	foreach $line (@umap) {
		&print_tempfile(UMAP, "$line\n");
		}
	&close_tempfile(UMAP);
	}

if ($global) { &modify_share("global", "global"); }
else { &create_share("global"); }
&unlock_file($config{'smb_conf'});
&webmin_log("pass", undef, undef, \%in);
&redirect("");

