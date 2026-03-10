#!/usr/local/bin/perl
# up.cgi
# Attempt to open a connection that was not started automatically

require './ipsec-lib.pl';
&ReadParse();
$| = 1;
$theme_no_table++;
&ui_print_header(undef, $text{'up_title'}, "");

# Validate connection name against configured connections
my @conf = &get_config();
my %ok_conns = map { $_->{'value'}, 1 }
	       grep { $_->{'name'} eq 'conn' && $_->{'value'} ne '%default' }
	       @conf;
$ok_conns{$in{'conn'}} || &error($text{'save_ename'});

# Try to connect
$cmd = "$config{'ipsec'} auto --up ".quotemeta($in{'conn'});
print "<b>",&text('up_cmd', "<tt>$cmd</tt>"),"</b>\n";
print "<pre>";
&foreign_require("proc", "proc-lib.pl");
&proc::safe_process_exec_logged($cmd, 0, 0, STDOUT, undef, 1);
print "</pre>\n";

# Save connection in config
&lock_file("$module_config_directory/config");
$config{'conn'} = $in{'conn'};
&write_file("$module_config_directory/config", \%config);
&unlock_file("$module_config_directory/config");
if (!$?) {
	&webmin_log("up", undef, $in{'conn'});
	}

&ui_print_footer("", $text{'index_return'});

