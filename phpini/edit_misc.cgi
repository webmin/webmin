#!/usr/local/bin/perl
# Show options related to other options

require './phpini-lib.pl';
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$conf = &get_config($in{'file'});

&ui_print_header("<tt>$in{'file'}</tt>", $text{'misc_title'}, "");

# Build list of timezones
my %tzlist;
&foreign_require("time");
if (defined(&time::list_timezones)) {
	foreach $t (&time::list_timezones()) {
		$tzlist{$t->[0]} = { 'comment' => $t->[1] };
		}
	}

print &ui_form_start("save_misc.cgi", "post");
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_table_start($text{'misc_header'}, "width=100%", 4);

# Tag styles
print &ui_table_row($text{'misc_short'},
		    &onoff_radio("short_open_tag"));
print &ui_table_row($text{'misc_asp'},
		    &onoff_radio("asp_tags"));

# Output options
print &ui_table_row($text{'misc_zlib'},
		    &onoff_radio("zlib.output_compression"));
print &ui_table_row($text{'misc_flush'},
		    &onoff_radio("implicit_flush"));

# URL open options
print &ui_table_row($text{'misc_fopen'},
		    &onoff_radio("allow_url_fopen"));

print &ui_table_hr();

# Email sending options
$smtp = &find_value("SMTP", $conf);
print &ui_table_row($text{'misc_smtp'},
		    &ui_opt_textbox("smtp", $smtp, 20, $text{'misc_none'}));
$port = &find_value("smtp_port", $conf);
print &ui_table_row($text{'misc_port'},
		    &ui_opt_textbox("smtp_port", $port, 5, $text{'default'}));

$sendmail = &find_value("sendmail_path", $conf);
print &ui_table_row($text{'misc_sendmail'},
		    &ui_opt_textbox("sendmail_path", $sendmail, 60,
				    $text{'misc_none'}), 3);


print &ui_table_hr();

# Include open options
print &ui_table_row($text{'misc_include'},
	&onoff_radio("allow_url_include"));

# CGI Fix Path options
print &ui_table_row($text{'misc_path'},
	&onoff_radio("cgi.fix_pathinfo"));

# PHP Timezone Dropdown
$tzlist{''}{'comment'} = $text{'default'} if not exists $tzlist{''};
$curr_timezone = &find_value("date.timezone", $conf);
$tzlist{$curr_timezone}{'comment'} = "Custom timezone" if not exists $tzlist{$curr_timezone};
print &ui_table_row(&hlink($text{'misc_timezone'}, "misc_timezone"),
	&ui_select("date.timezone", $curr_timezone,
		   [ map { $z = $tzlist{$_};
			   [ $_, $_.($z->{'comment'} ?
				     " ($z->{'comment'})" : "")  ] }
			 (sort keys %tzlist) ], 1, 0, 0, 0), 3);

# Default charset
$charset = &find_value("default_charset", $conf);
print &ui_table_row($text{'misc_charset'},
		    &ui_opt_textbox("default_charset", $charset, 20,
				    $text{'default'}));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("list_ini.cgi?file=".&urlize($in{'file'}),
		 $text{'list_return'});
