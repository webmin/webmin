#!/usr/local/bin/perl
# Re-start Webmin

require './usermin-lib.pl';

&restart_usermin_miniserv();
&redirect("");


