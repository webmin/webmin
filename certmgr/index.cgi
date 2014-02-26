#!/usr/local/bin/perl
# index.cgi
# Upload and load kernel modules

require './certmgr-lib.pl';

if (! -d $config{'ssl_cert_dir'} ) { system("mkdir -p -m 0755 $config{'ssl_cert_dir'}"); }
if (! -d $config{'ssl_csr_dir'} ) { system("mkdir -p -m 0755 $config{'ssl_csr_dir'}"); }
if (! -d $config{'ssl_key_dir'} ) { system("mkdir -p -m 0700 $config{'ssl_key_dir'}"); }

&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
print &ui_table_start($text{'index_header'}, undef, 2);
foreach $p (@pages) {
	next if (!$access{$p});
	$txt = $text{'index_'.$p};
        print &ui_columns_row([ &ui_link("$p.cgi", "<img src='images/$p.gif' border=0>"), &ui_link("$p.cgi", $txt) ], ["valign=middle width=5%","valign=middle style='padding-right:10px;'"]);
    }
print ui_table_end();

&ui_print_footer("/", $text{'index_index'});
