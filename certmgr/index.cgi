#!/usr/local/bin/perl
# index.cgi
# Upload and load kernel modules

require './certmgr-lib.pl';

if (! -d $config{'ssl_cert_dir'} ) { system("mkdir -p -m 0755 $config{'ssl_cert_dir'}"); }
if (! -d $config{'ssl_csr_dir'} ) { system("mkdir -p -m 0755 $config{'ssl_csr_dir'}"); }
if (! -d $config{'ssl_key_dir'} ) { system("mkdir -p -m 0700 $config{'ssl_key_dir'}"); }

&header($text{'index_title'}, "", "intro", 1, 1);

print <<EOF;
<hr>
<table border>
<tr $tb> <td align=center><b>$text{'index_header'}</b></td> </tr>
<tr $cb> <td><table width=100%><tr>
EOF
foreach $p (@pages) {
	next if (!$access{$p});
	$txt = $text{'index_'.$p};
	print "<tr> <td><a href=$p.cgi><img src=images/$p.gif border=0></a>\n";
	print "</td><td><a href=$p.cgi>$txt</a></td></tr>\n";
	}
print "</table></td></tr></table>\n";
print &ui_hr();

&footer("/", $text{'index_index'});
