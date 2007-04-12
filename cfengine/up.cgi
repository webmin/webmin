#!/usr/local/bin/perl
# up.cgi
# Move an entire section up in the config file

require './cfengine-lib.pl';
&ReadParse();
$conf = $in{'cfd'} ? &get_cfd_config() : &get_config();
$sw1 = $conf->[$in{'idx'}];
$sw2 = $conf->[$in{'idx'}-1];
&swap_directives($conf, $sw1, $sw2);

&flush_file_lines();
&redirect($in{'cfd'} ? "edit_cfd.cgi" : "");

