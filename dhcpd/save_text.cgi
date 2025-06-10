#!/usr/bin/perl
# $Id: save_text.cgi,v 1.2 2005/04/16 14:30:21 jfranken Exp $
# File added 2005-04-15 by Johannes Franken <jfranken@jfranken.de>
# Distributed under the terms of the GNU General Public License, v2 or later
#
# * Save passed text to dhcpd.conf

require './dhcpd-lib.pl';
&ReadParseMime();
$access{'noconfig'} && &error($text{'text_ecannot'});
$conf = &get_config();

$file=$config{'dhcpd_conf'};
&lock_file($file);
$in{'text'} =~ s/\r//g;
$in{'text'} .= "\n" if ($in{'text'} !~ /\n$/);
&open_tempfile(FILE, ">$file");
&print_tempfile(FILE, $in{'text'});
&close_tempfile(FILE);
&unlock_file($file);
&webmin_log("text", undef, $conf->[$in{'index'}]->{'value'},
	    { 'file' => $file });
&redirect("");

