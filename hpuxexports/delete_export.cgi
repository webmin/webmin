#!/usr/local/bin/perl
# delete_share.cgi
# Delete a share

require './hpuxexports-lib.pl';
&ReadParse();
&delete_export($in{directory});
&redirect("");

