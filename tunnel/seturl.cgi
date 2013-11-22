#!/usr/local/bin/perl
# Sets the URL cookie

require './tunnel-lib.pl';
&ReadParse();
&error_setup($text{'seturl_err'});

if ( $in{'url'} =~ m/^(http|https):\/\/(\S+)$/ ) {
    $schema = $1."://";
    $host = $2;
    $url = $2;

    # check: http://aa.com
    # check: http://aa.com/bb.html
    # check: http://aa.com/bb/cc.html
    $url =~ s/\/?[^\/]*\/*$//;

    # empty? append / at the end
    if ( $url eq '' ) {
        $in{'url'} = "$schema$host/";
    }
} else {
    &error($text{'seturl_eurl'});
}

#$in{'url'} =~ /^(http|https):\/\/(\S+)$/ || &error($text{'seturl_eurl'});
&redirect("link.cgi/$in{'url'}");

