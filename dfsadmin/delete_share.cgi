#!/usr/local/bin/perl
# delete_share.cgi
# Delete a share

require './dfs-lib.pl';
$access{'view'} && &error($text{'ecannot'});
&ReadParse();
@shlist = &list_shares();
$share = $shlist[$in{'idx'}];
&lock_file($config{'dfstab_file'});
&delete_share($share);
&unlock_file($config{'dfstab_file'});
&webmin_log("delete", "share", $share->{'dir'});
&redirect("");

