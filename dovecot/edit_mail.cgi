#!/usr/local/bin/perl
# Show mail file options

require './dovecot-lib.pl';
&ui_print_header(undef, $text{'mail_title'}, "");
$conf = &get_config();

print &ui_form_start("save_mail.cgi", "post");
print &ui_table_start($text{'mail_header'}, "width=100%", 4);

# Mail file location. Old versions used default_mail_env, new uses mail_location
$envmode = 4;
if (&find("default_mail_env", $conf, 2)) {
	$env = &find_value("default_mail_env", $conf);
	}
elsif (&find("mail_path", $conf, 2)) {
	$env = &find_value("mail_path", $conf);
	}
else {
	$env = &find_value("mail_location", $conf);
	}
if ($env =~ s/:INDEX=([^:]+)//) {
	$index = $1;
	}
elsif (&find("mail_index_path", $conf, 2)) {
	$index = &find_value("mail_index_path", $conf);
	}
if ($env =~ s/:CONTROL=([^:]+)//) {
	$control = $1;
	}
elsif (&find("mail_control_path", $conf, 2)) {
	$control = &find_value("mail_control_path", $conf);
	}
for($i=0; $i<@mail_envs; $i++) {
	$envmode = $i if ($mail_envs[$i] eq $env);
	}
print &ui_table_row($text{'mail_env'},
	&ui_radio("envmode", $envmode,
		[ ( map { [ $_, $text{'mail_env'.$_}."<br>" ] } (
			&version_atleast("2.4") ? (0) : (0 .. 3)) ),
		  [ 4, &text('mail_env4',
			&ui_textbox("other", $envmode == 4 ? $env : undef, 40)) ] ],
		), 3);

# Mail file format
if (&version_atleast("2.4")) {
	$driver = &find_value("mail_driver", $conf);
	print &ui_table_row($text{'mail_driver'},
		&ui_radio("driver", $driver,
			   [ [ "", $text{'mail_driver_def'} ],
			     [ "auto", $text{'mail_driver_auto'} ],
			     [ "mbox", $text{'mail_driver_mbox'} ],
			     [ "maildir", $text{'mail_driver_maildir'} ],
			     [ "dbox", $text{'mail_driver_dbox'} ],
			     [ "imapc", $text{'mail_driver_imapc'} ],
			     [ "pop3c", $text{'mail_driver_auto'} ] ]));
	}

# Index files location
$indexmode = $index eq 'MEMORY' ? 1 :
	     $index ? 2 : 0;
print &ui_table_row($text{'mail_index'},
	&ui_radio("indexmode", $indexmode,
	  [ [ 0, $text{'mail_index0'}."<br>" ],
	    [ 1, $text{'mail_index1'}."<br>" ],
	    [ 2, &text('mail_index2',
		  &ui_textbox("index", $indexmode == 2 ? $index : "", 40)) ]
	  ]), 3);

# Control files location
print &ui_table_row($text{'mail_control'},
	&ui_radio("controlmode", $control ? 1 : 0,
	  [ [ 0, $text{'mail_index0'}."<br>" ],
	    [ 1, &text('mail_index2',
		  &ui_textbox("control", $control, 40)) ] ]), 3);

print &ui_table_hr();

# Idle interval
$idle = &find_value("mailbox_idle_check_interval", $conf);
$idle_never = $idle =~ /520\s+weeks/;
print &ui_table_row($text{'mail_idle'},
	&ui_radio("idle", $idle eq '' ? 0 : $idle_never ? 1 : 2,
		  [ [ 1, $text{'mail_never'} ],
		    [ 2, &ui_textbox("idlei", $idle && !$idle_never ? int($idle) : "", 10).
			 " ".$text{'mail_secs'} ],
		    [ 0, &getdef("mailbox_idle_check_interval",
				 [ [ 0, $text{'mail_never'} ] ]) ] ]), 3);

# Full FS access
@opts = ( [ "yes", $text{'yes'} ], [ "no", $text{'no'} ] );
$full = &find_value("mail_full_filesystem_access", $conf);
print &ui_table_row($text{'mail_full'},
	&ui_radio("full", $full,
	  [ @opts,
	    [ "", &getdef("mail_full_filesystem_access", \@opts) ] ]), 3);

# CRLF save mode
$crlf = &find_value("mail_save_crlf", $conf);
@opts = ( [ "yes", $text{'yes'} ], [ "no", $text{'no'} ] );
print &ui_table_row($text{'mail_crlf'},
	&ui_radio("crlf", $crlf,
	  [ @opts,
	    [ "", &getdef("mail_save_crlf", \@opts) ] ]), 3);

# Allow changing of files
$dirty = &find("mbox_dirty_syncs", $conf, 2) ?
		"mbox_dirty_syncs" : "maildir_check_content_changes";
$change = &find_value($dirty, $conf);
print &ui_table_row($text{'mail_change'},
	&ui_radio("change", $change,
	  [ @opts,
	    [ "", &getdef($dirty, \@opts) ] ]), 3);

# Permissions on files
if (&version_below("2")) {
	$umask = &find_value("umask", $conf);
	print &ui_table_row($text{'mail_umask'},
		&ui_opt_textbox("umask", $umask, 5, &getdef("umask")), 3);
	}

# Allow POP3 last command
if (&find("pop3_enable_last", $conf, 2)) {
	$last = &find_value("pop3_enable_last", $conf);
	@opts = ( [ 'yes', $text{'yes'} ], [ 'no', $text{'no'} ] );
	print &ui_table_row($text{'mail_last'},
		&ui_radio("pop3_enable_last", $last,
		  [ [ '', &getdef("pop3_enable_last", \@opts) ],
		    @opts ]), 3);
	}

# Index lock method
if (&find("lock_method", $conf, 2)) {
	$method = &find_value("lock_method", $conf);
	@opts = map { [ $_, $text{'mail_'.$_} ] } &list_lock_methods(1);
	print &ui_table_row($text{'mail_lock'},
		&ui_select("lock_method", $method,
			   [ @opts,
			     [ '', &getdef("lock_method", \@opts) ] ],
			   1, 0, 1), 3);
	}

# Mailbox lock methods
@opts = map { [ $_, $text{'mail_'.$_} ] } &list_lock_methods(0);
foreach $l ("mbox_read_locks", "mbox_write_locks") {
	next if (!&find($l, $conf, 2));
	$def = &find_value($l, $conf, 1);
	$defmsg = join(", ", map { $text{'mail_'.$_} || $_ }
				 split(/\s+/, $def));
	$defmsg = " ($defmsg)" if ($defmsg);
	$method = &find_value($l, $conf);
	$defsel = &ui_radio($l."_def", $method ? 0 : 1,
			    [ [ 1, $text{'default'}.$defmsg ],
			      [ 0, $text{'mail_sel'} ] ]);
	$methsel = "";
	@methods = split(/\s+/, $method);
	for(my $i=0; $i<@opts; $i++) {
		$methsel .= &ui_select($l."_".$i, $methods[$i],
				       [ [ '', "&lt;$text{'mail_none'}&gt;" ],
					 @opts ], 1, 0, 1);
		}
	print &ui_table_row($text{'mail_'.$l},
			    $defsel."<br>\n".$methsel, 3);
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

