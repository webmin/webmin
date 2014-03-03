#!/usr/local/bin/perl
# edit_log.cgi
# Display a form for adding a new logfile or editing an existing one.
# Allows you to set the schedule on which the log is analysed

use strict;
use warnings;
our (%text, %config, %gconfig, %access, $module_name, %in, $remote_user);
require './webalizer-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ReadParse();
$access{'view'} && &error($text{'edit_ecannot'});
my $lconf;
if ($in{'new'}) {
	$access{'add'} || &error($text{'edit_ecannot'});
	&ui_print_header(undef, $text{'edit_title1'}, "");
	$lconf = { };
	}
else {
	&can_edit_log($in{'file'}) || &error($text{'edit_ecannot'});
	&ui_print_header(undef, $text{'edit_title2'}, "");
	$lconf = &get_log_config($in{'file'});
	}

print &ui_form_start("save_log.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("oldfile", $in{'file'});
print &ui_table_start($text{'edit_header'}, "width=100%", 2);

# Log file path
if ($in{'new'}) {
	print &ui_table_row($text{'edit_file'},
		&ui_filebox("file", undef, 60));
	}
else {
	print &ui_table_row($text{'edit_file'},
		"<tt>$in{'file'}</tt>");
	print &ui_hidden("file", $in{'file'});
	}

# Other log files that will be included
if (!$in{'new'}) {
	my @all = &all_log_files($in{'file'});
	if (@all > 1 && !$config{'skip_old'}) {
		print &ui_table_row($text{'edit_files'},
			join("<br>\n", @all));
		}
	}

# Log file format type
if ($in{'new'}) {
	print &ui_table_row($text{'edit_type'},
		&ui_select("type", undef,
			[ map { [ $_, $text{'index_type'.$_} ] } (1, 2, 3) ]));
	}
else {
	print &ui_table_row($text{'edit_type'},
		$text{'index_type'.$in{'type'}});
	print &ui_hidden("type", $in{'type'});
	}

# Output directory
print &ui_table_row($text{'edit_dir'},
	&ui_filebox("dir", $lconf->{'dir'}, 60, 0, undef, undef, 1));

# Run as user
if ($access{'user'} eq '*') {
	# User that webalizer runs as can be chosen
	print &ui_table_row($text{'edit_user'},
		&ui_user_textbox("user", $lconf->{'user'} || "root", 20));
	}
else {
	# User is fixed
	print &ui_table_row($text{'edit_user'},
		!$in{'new'} && $lconf->{'dir'} ? $lconf->{'user'} || "root" :
                $access{'user'} eq "" ? $remote_user : $access{'user'});
	}

# Always re-process logs?
print &ui_table_row($text{'edit_over'},
	&ui_yesno_radio("over", $lconf->{'over'} ? 1 : 0));

# Webalizer config file
my $cfile = &config_file_name($in{'file'});
my $cmode = -l $cfile ? 2 : -r $cfile ? 1 : 0;
print &ui_table_row($text{'edit_conf'},
	&ui_radio("cmode", $cmode,
		  [ [ 0, $text{'edit_cmode0'} ],
		    [ 1, $text{'edit_cmode1'} ],
		    [ 2, $text{'edit_cmode2'}." ".
			 &ui_filebox("cfile",
				$cmode == 2 ? readlink($cfile) : "", 40) ] ]));

# Clear log files after run?
print &ui_table_row($text{'edit_clear'},
	&ui_yesno_radio("clear", $lconf->{'clear'} ? 1 : 0));

# Run on schedule?
print &ui_table_row($text{'edit_sched'},
	&ui_radio("sched", $lconf->{'sched'} ? 1 : 0,
		  [ [ 0, $text{'edit_sched0'} ],
		    [ 1, $text{'edit_sched1'} ] ]));

if ($lconf->{'mins'} eq '') {
	$lconf->{'mins'} = $lconf->{'hours'} = 0;
	$lconf->{'days'} = $lconf->{'months'} = $lconf->{'weekdays'} = '*';
	}
print &cron::get_times_input($lconf, 0, undef, "");
print &ui_table_end();

my @b;
if ($in{'new'}) {
	push(@b, [ undef, $text{'create'} ]);
	}
else {
	push(@b, [ undef, $text{'save'} ]);
	push(@b, [ 'global', $text{'edit_global'} ]) if ($cmode);
	if ($lconf->{'dir'}) {
		push(@b, [ 'run', $text{'edit_run'} ]);
		}
	if ($lconf->{'dir'} && -r "$lconf->{'dir'}/index.html") {
		push(@b, [ 'view', $text{'edit_view'} ]);
		}
	if ($in{'custom'}) {
		push(@b, [ 'delete', $text{'delete'} ]);
		}
	}
print &ui_form_end(\@b);

&ui_print_footer("", $text{'index_return'});

