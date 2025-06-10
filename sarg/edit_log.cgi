#!/usr/local/bin/perl
# Show options for source log file

require './sarg-lib.pl';

$conf = &get_config();
&ui_print_header(undef, $text{'log_title'}, "");
print &ui_form_start("save_log.cgi", "post");
print &ui_table_start($text{'log_header'}, "width=100%", 4);
$config_prefix = "log_";

if (&foreign_check("squid")) {
	&foreign_require("squid", "squid-lib.pl");
	local $sconf = &squid::get_config();
	$squid_log = &squid::find_value("access_log", $sconf);
	if (-d $squid::config{'log_dir'}) {
		$squid_log ||= "$squid::config{'log_dir'}/access.log";
		}
	}
$log = &find_value("access_log", $conf);
$lmode = !$log ? 0 : $log eq $squid_log ? 1 : 2;
$defstr = &find("access_log", $conf, 2);
$def = $defstr && $defstr->{'value'} ? " ($defstr->{'value'})" : undef;
print &ui_table_row($text{'log_access_log'},
		    &ui_radio("access_log_def", $lmode,
			      [ [ 0, $text{'default'}.$def."<br>" ],
				$squid_log ? ( [ 1, &text('log_squid', $squid_log)."<br>" ] ) : ( ),
				[ 2, $text{'log_other'} ] ])." ".
		    &ui_textbox("access_log", $lmode == 2 ? $log : "",
				40), 3);
print &ui_hidden("squid_log", $squid_log);

print &config_opt_textbox($conf, "output_dir", 40, 3);
print &config_opt_textbox($conf, "lastlog", 5, 3, $text{'log_unlimit'});
print &config_opt_textbox($conf, "useragent_log", 40, 3);
print &config_opt_textbox($conf, "squidguard_log_path", 40, 3);

print &config_opt_textbox($conf, "output_email", 30, 3,
			  $text{'log_nowhere'});
print &config_opt_textbox($conf, "mail_utility", 15, 3,
			  $text{'default'}." (mailx)");

print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'save'} ] ], "100%");
&ui_print_footer("", $text{'index_return'});

