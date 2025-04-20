#!/usr/local/bin/perl
# Clean up leftover Webmin temp files and locks, if configured

require './cron-lib.pl';
&cleanup_temp_files();
