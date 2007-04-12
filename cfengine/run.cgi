#!/usr/local/bin/perl
# run.cgi
# Run cfengine on this host

require './cfengine-lib.pl';
&ReadParse();
&ui_print_unbuffered_header(undef, $text{'run_title'}, "");

# Construct the command
$cmd = "$config{'cfengine'} -f $cfengine_conf";
$cmd .= " -v" if ($in{'verbose'});
$cmd .= " --dry-run" if ($in{'dry'});
$cmd .= " -i" if ($in{'noifc'});
$cmd .= " -m" if ($in{'nomnt'});
$cmd .= " -s" if ($in{'nocmd'});
$cmd .= " -t" if ($in{'notidy'});
$cmd .= " -X" if ($in{'nolinks'});

print "<p><b>",&text('run_exec', "<tt>$cmd</tt>"),"</b><br>\n";
print "<pre>";
$ENV{'CFINPUTS'} = $config{'cfengine_dir'};
open(CMD, "$cmd 2>&1 </dev/null |");
while(<CMD>) {
	print &html_escape($_);
	}
close(CMD);
&additional_log("exec", undef, $cmd);
print "</pre>\n";
&webmin_log("run");

&ui_print_footer("", $text{'index_return'});

