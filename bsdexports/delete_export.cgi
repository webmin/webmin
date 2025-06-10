#!/usr/local/bin/perl
# delete_export.cgi
# Delete an existing export

require './bsdexports-lib.pl';
&ReadParse();
&lock_file($config{'exports_file'});
@exps = &list_exports();
&delete_export($exps[$in{'index'}]);
&unlock_file($config{'exports_file'});
&redirect("");

