#!/usr/local/bin/perl
# Build EOL data JSON file

do "./web-lib-funcs.pl";
do "./webmin/os-eol-lib.pl";
&eol_build_all_os_data("./os_eol.json");
