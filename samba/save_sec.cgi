#!/usr/local/bin/perl
# save_sec.cgi
# Save secuirty options for a share

require './samba-lib.pl';
&ReadParse();
&lock_file($config{'smb_conf'});
&get_share($in{old_name});

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pusec'}")
	        unless &can('rwsS', \%access, $in{old_name});
# save				
&error_setup($text{'savesec_fail'});
&delval("read only");
&setval("writeable", $in{writeable});
if ($in{guest} == 0) {
	&delval("public"); &delval("guest only");
	}
elsif ($in{guest} == 1) {
	&setval("public", "yes"); &delval("guest only");
	}
else {
	&setval("public", "yes"); &setval("guest only", "yes");
	}
&setval("valid users",
	join(',', &split_input($in{'valid_users_u'}),
		  &split_input($in{'valid_users_g'}, '@')));
&setval("invalid users",
	join(',', &split_input($in{'invalid_users_u'}),
		  &split_input($in{'invalid_users_g'}, '@')));
&setval("user",
	join(',', &split_input($in{'user_u'}),
		  &split_input($in{'user_g'}, '@')));
&setval("read list",
	join(',', &split_input($in{'read_list_u'}),
		  &split_input($in{'read_list_g'}, '@')));
&setval("write list",
	join(',', &split_input($in{'write_list_u'}),
		  &split_input($in{'write_list_g'}, '@')));
if (!$in{allow_hosts_def} && $in{allow_hosts} =~ /\S/) {
	&setval("allow hosts", $in{allow_hosts});
	}
else { &delval("allow hosts"); }
if (!$in{deny_hosts_def} && $in{deny_hosts} =~ /\S/) {
	&setval("deny hosts", $in{deny_hosts});
	}
else { &delval("deny hosts"); }
&setval("guest account", $in{guest_account});
&setval("only user", $in{only_user});
&setval("revalidate", $in{revalidate});

&modify_share($in{old_name}, $in{old_name});
&unlock_file($config{'smb_conf'});
&webmin_log("save", "sec", $in{old_name}, \%in);
if (&istrue("printable") || $in{'printer'})
	{ &redirect("edit_pshare.cgi?share=".&urlize($in{old_name})); }
else
	{ &redirect("edit_fshare.cgi?share=".&urlize($in{old_name})); }

# split_input(string, [prepend])
sub split_input
{
local @rv;
local $str = $_[0];
# remove '@' if smb.conf was manually edited
$str =~ s/(@)+//g;
while($str =~ /^\s*(\S*"[^"]+"\S*)(.*)$/ || $str =~ /^\s*(\S+)(.*)$/) {
	push(@rv, $_[1].$1);
	$str = $2;
	}
return @rv;
}

