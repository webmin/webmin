#!/usr/local/bin/perl
# Set OS to automatically detected version

require './webmin-lib.pl';
&ReadParse();

%osinfo = &detect_operating_system();
&apply_new_os_version(\%osinfo);

&webmin_log("os");
&redirect(get_referer_relative());
