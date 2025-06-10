#!/usr/local/bin/perl
# build.cgi
# Rebuild NIS tables

require './nis-lib.pl';
&ReadParse();
&apply_table_changes();
&redirect("edit_tables.cgi?table=$in{'table'}");

