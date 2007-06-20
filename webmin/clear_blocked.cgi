#!/usr/local/bin/perl
# Re-start Webmin to clear blocks

require './webmin-lib.pl';

&show_restart_page($text{'blocked_title'}, $text{'blocked_restarting'});


