#!/usr/local/bin/perl
# Show mail file options

require './dovecot-lib.pl';
&ui_print_header(undef, $text{'mail_title'}, "");
$conf = &get_config();

print &ui_form_start("save_mail.cgi", "post");
print &ui_table_start($text{'mail_header'}, "width=100%", 4);

# Mail file location. Old versions used default_mail_env, new uses mail_location
$envmode = 4;
if (&find("mail_location", $conf, 2)) {
	$env = &find_value("mail_location", $conf);
	}
else {
	$env = &find_value("default_mail_env", $conf);
	}
if ($env =~ s/:INDEX=([^:]+)//) {
	$index = $1;
	}
if ($env =~ s/:CONTROL=([^:]+)//) {
	$control = $1;
	}
for($i=0; $i<@mail_envs; $i++) {
	$envmode = $i if ($mail_envs[$i] eq $env);
	}
print &ui_table_row($text{'mail_env'},
	&ui_radio("envmode", $envmode,
		[ ( map { [ $_, $text{'mail_env'.$_}."<br>" ] } (0.. 3) ),
		  [ 4, &text('mail_env4',
			&ui_textbox("other", $envmode == 4 ? $env : undef, 40)) ] ],
		), 3);

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

# Check interval
$check = &find_value("mailbox_check_interval", $conf);
print &ui_table_row($text{'mail_check'},
	&ui_radio("check", $check eq '' ? 0 : $check == 0 ? 1 : 2,
		  [ [ 1, $text{'mail_never'} ],
		    [ 2, &ui_textbox("checki", $check ? $check : "", 10).
			 " ".$text{'mail_secs'} ],
		    [ 0, &getdef("mailbox_check_interval",
				 [ [ 0, $text{'mail_never'} ] ]) ] ]), 3);

# Idle interval
$idle = &find_value("mailbox_idle_check_interval", $conf);
print &ui_table_row($text{'mail_idle'},
	&ui_radio("idle", $idle eq '' ? 0 : $idle == 0 ? 1 : 2,
		  [ [ 1, $text{'mail_never'} ],
		    [ 2, &ui_textbox("idlei", $idle ? $idle : "", 10).
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
$umask = &find_value("umask", $conf);
print &ui_table_row($text{'mail_umask'},
	&ui_opt_textbox("umask", $umask, 5, &getdef("umask")), 3);

# UIDL format
if (&find("pop3_uidl_format", $conf, 2)) {
	$uidl = &find_value("pop3_uidl_format", $conf);
	@opts = ( $uidl ? ( ) : ( [ "", $text{'mail_uidl_none'} ] ),
		  [ "%v.%u", $text{'mail_uidl_dovecot'} ],
		  [ "%08Xv%08Xu", $text{'mail_uidl_uw'} ],
		  [ "%f", $text{'mail_uidl_courier0'} ],
		  [ "%u", $text{'mail_uidl_courier1'} ],
		  [ "%v-%u", $text{'mail_uidl_courier2'} ],
		  [ "%Mf", $text{'mail_uidl_tpop3d'} ] );
	($got) = grep { $_->[0] eq $uidl } @opts;
	print &ui_table_row($text{'mail_uidl'},
		&ui_select("pop3_uidl_format", $got ? $uidl : "*",
			   [ @opts, [ "*", $text{'mail_uidl_other'} ] ])."\n".
		&ui_textbox("pop3_uidl_format_other", $got ? "" : $uidl, 10),
		3);
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

