#!/usr/local/bin/perl
# Hide one webmin.com notification

require './webmin-lib.pl';
our ($hidden_announce_file, %in);
&ReadParse();

&lock_file($hidden_announce_file);
&read_file($hidden_announce_file, \%hide);
$hide{$in{'id'}} = 1;
&write_file($hidden_announce_file, \%hide);
&unlock_file($hidden_announce_file);

&redirect("/");
