#!/usr/local/bin/perl
# save_net.cgi
# Save inputs from conf_net.cgi

require './samba-lib.pl';
&ReadParse();
&lock_file($config{'smb_conf'});
$global = &get_share("global");

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcs'}") unless $access{'conf_smb'};

&error_setup($text{'savesmb_fail'});
&setval("workgroup", $in{workgroup_def} ? "" : $in{workgroup}, "");

if ($in{'wins'} == 0) {
	&delval("wins server");
	&setval("wins support", "true");
	}
elsif ($in{'wins'} == 1) {
	&setval("wins support", "false");
	&setval("wins server", $in{'wins_server'}, "");
	}
else {
	&delval("wins server");
	&setval("wins support", "false");
	}

if ($in{server_string_def} == 1) {
	&delval("server string");
	}
else {
	&setval("server string",
		$in{server_string_def} == 2 ? "" : $in{server_string}, "NONE");
	}

&setval("netbios name", $in{'netbios_name'}, "");

&setval("netbios aliases", $in{'netbios_aliases'}, "");

&setval("default", $in{default}, "");

&setval("auto services", join(' ', split(/\0/, $in{auto_services})), "");

if (!$in{max_disk_size_def} && $in{max_disk_size} !~ /^\d+$/) {
	&error(&text('savesmb_size', $in{max_disk_size}));
	}
&setval("max disk size", $in{max_disk_size_def} ? 0 : $in{max_disk_size}, 0);

&setval("message command", $in{message_command}, "");

$in{os_level} =~ /^\d+$/ ||
	&error(&text('savesmb_oslevel', $in{os_level}));
&setval("os level", $in{os_level}, 0);

&setval("protocol", $in{protocol}, "");

&setval("preferred master", $in{preferred_master}, "auto");

&setval("security", $in{security}, "");

if ($in{security} eq "server" && $in{password_server} !~ /\S/) {
	&error($text{'savesmb_server'});
	}
&setval("password server", $in{password_server}, "");

if ($in{remote_def}) { &delval("remote announce"); }
else {
	for($i=0; defined($in{"remote_ip$i"}); $i++) {
		if ($in{"remote_ip$i"} !~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)/)
			{ next; }
		push(@rem, $in{"remote_ip$i"} .
		   ($in{"remote_wg$i"} =~ /\S/ ? "/".$in{"remote_wg$i"} : ""));
		}
	&setval("remote announce", join(' ', @rem), "");
	}

if ($global) { &modify_share("global", "global"); }
else { &create_share("global"); }
&unlock_file($config{'smb_conf'});
&webmin_log("smb", undef, undef, \%in);
&redirect("");

