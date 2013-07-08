#!/usr/local/bin/perl
# edit_defaults.cgi
# Display a form for editing default options

require './xinetd-lib.pl';
&ui_print_header(undef, $text{'defs_title'}, "");

foreach $xi (&get_xinetd_config()) {
	if ($xi->{'name'} eq 'defaults') {
		$defs = $xi;
		}
	}
$q = $defs->{'quick'};

print &ui_form_start("save_defaults.cgi", "post");
print &ui_hidden("idx", $defs->{'index'});
print &ui_table_start($text{'defs_header'}, "width=100%", 4);

# Allow access from
print &ui_table_row($text{'serv_from'},
	&ui_radio("from_def", $q->{'only_from'} ? 0 : 1,
		  [ [ 1, $text{'serv_from_def'} ],
		    [ 0, $text{'serv_from_sel'} ] ])."<br>\n".
	&ui_textarea("from", join("\n", @{$q->{'only_from'}}), 4, 20));

# Deny access from
print &ui_table_row($text{'serv_access'},
	&ui_radio("access_def", $q->{'no_access'} ? 0 : 1,
		  [ [ 1, $text{'serv_access_def'} ],
		    [ 0, $text{'serv_access_sel'} ] ])."<br>\n".
	&ui_textarea("access", join("\n", @{$q->{'no_access'}}), 4, 20));

print &ui_table_hr();

# Logging type
$lt = $q->{'log_type'}->[0] eq 'SYSLOG' ? 1 :
      $q->{'log_type'}->[0] eq 'FILE' ? 2 : 0;

# Default
@table = ( [ 0, $text{'defs_log_def'} ] );

# Log to syslog
&foreign_require("syslog");
push(@table, [ 1, $text{'defs_facility'},
       &ui_select("facility", $lt == 1 ? $q->{'log_type'}->[1] : "",
		  [ split(/\s+/, $syslog::config{'facilities'}) ]).
       " ".$text{'defs_level'}." ".
       &ui_select("level", $lt == 1 ? $q->{'log_type'}->[2] : "",
		  [ [ "", $text{'default'} ],
		    &syslog::list_priorities() ]) ]);

# Log to file
push(@table, [ 2, $text{'defs_file'},
	&ui_textbox("file", $lt == 2 ? $q->{'log_type'}->[1] : "", 60)." ".
	&file_chooser_button("file")."<br>\n".
	$text{'defs_soft'}." ".
	&ui_bytesbox("soft", $lt == 2 ? $q->{'log_type'}->[2] : "").
	" ".$text{'defs_hard'}." ".
	&ui_bytesbox("hard", $lt == 2 ? $q->{'log_type'}->[3] : "") ]);

print &ui_table_row($text{'defs_log'},
	&ui_radio_table("log_mode", $lt, \@table), 3);

# On success log
print &ui_table_row($text{'defs_success'},
	&ui_select("success", $q->{'log_on_success'},
		   [ map { [ $_, $text{'defs_success_'.lc($_)} ] }
			 ('PID', 'HOST', 'USERID', 'EXIT', 'DURATION') ],
		   5, 1));

# On failed connection log
print &ui_table_row($text{'defs_failure'},
	&ui_select("failure", $q->{'log_on_failure'},
		   [ map { [ $_, $text{'defs_failure_'.lc($_)} ] }
			 ('HOST', 'USERID', 'ATTEMPT') ], 5, 1));
			 
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

