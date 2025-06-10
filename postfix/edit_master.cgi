#!/usr/local/bin/perl
# Edit or create a server process

require './postfix-lib.pl';
$access{'master'} || &error($text{'master_ecannot'});
&ReadParse();
$master = &get_master_config();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'master_create'}, "");
	$prog = { 'enabled' => 1,
		  'type' => 'inet',
		  'private' => '-',
		  'unpriv' => '-',
		  'chroot' => '-',
		  'wakeup' => '-',
		  'maxprocs' => '-',
		};
	}
else {
	($prog) = grep { $_->{'name'} eq $in{'name'} &&
			 $_->{'type'} eq $in{'type'} &&
			 $_->{'enabled'} == $in{'enabled'} } @$master;
	$prog || &error($text{'master_egone'});
	&ui_print_header(undef, $text{'master_edit'}, "");
	}

print &ui_form_start("save_master.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_hidden("oldtype", $in{'type'}),"\n";
print &ui_hidden("oldenabled", $in{'enabled'}),"\n";
print &ui_table_start($text{'master_header'}, "width=100%", 4);

print &ui_table_row($text{'master_type'},
	    &ui_select("type", $prog->{'type'},
		[ [ "inet", $text{'master_inet'} ],
		  [ "unix", $text{'master_unix'} ],
		  [ "fifo", $text{'master_fifo'} ] ]));

print &ui_table_row($text{'master_enabled'},
		    &ui_yesno_radio("enabled", int($prog->{'enabled'})));

if ($prog->{'name'} =~ s/^(\S+)://) {
	$host = $1;
	}
print &ui_table_row($text{'master_name2'},
		    &ui_textbox("name", $prog->{'name'}, 20));

print &ui_table_row($text{'master_host'},
		    &ui_opt_textbox("host", $host, 15, $text{'master_any'}));

print &ui_table_row($text{'master_command'},
		    &ui_textbox("command", $prog->{'command'}, 80), 3);

print &ui_table_hr();

print &ui_table_row($text{'master_private2'},
		    &ui_radio("private", $prog->{'private'},
			[ [ "y", $text{'yes'} ],
			  [ "n", $text{'no'} ],
			  [ "-", $text{'master_defyes'} ] ]));

print &ui_table_row($text{'master_unpriv2'},
		    &ui_radio("unpriv", $prog->{'unpriv'},
			[ [ "y", $text{'yes'} ],
			  [ "n", $text{'no'} ],
			  [ "-", $text{'master_defyes'} ] ]));

print &ui_table_row($text{'master_chroot2'},
		    &ui_radio("chroot", $prog->{'chroot'},
			[ [ "y", $text{'yes'} ],
			  [ "n", $text{'no'} ],
			  [ "-", $text{'master_defyes'} ] ]));

$wmode = $prog->{'wakeup'} eq '-' ? 0 :
	 $prog->{'wakeup'} eq '0' ? 1 : 2;
$wused = $prog->{'wakeup'} =~ s/\?$//;
print &ui_table_row($text{'master_wakeup'},
    &ui_radio("wakeup", $wmode,
	[ [ 0, $text{'default'} ],
	  [ 1, $text{'master_unlimit'} ],
	  [ 2, &text('master_wtime',
	&ui_textbox("wtime", $wmode == 2 ? $prog->{'wakeup'} : "", 6)) ] ]).
        " (".&ui_checkbox("wused", 1, $text{'master_wused'}, $wused).")", 3);

$pmode = $prog->{'maxprocs'} eq '-' ? 0 :
	 $prog->{'maxprocs'} eq '0' ? 1 : 2;
print &ui_table_row($text{'master_max2'},
    &ui_radio("maxprocs", $pmode,
	[ [ 0, $text{'default'} ],
	  [ 1, $text{'master_unlimit'} ],
	  [ 2, &text('master_procs',
	&ui_textbox("procs", $pmode == 2 ? $prog->{'maxprocs'} : "", 6)) ] ]),
		3);

print &ui_table_end();
print &ui_form_end([
	$in{'new'} ? ( [ "create", $text{'create'} ] )
	   : ( [ "save", $text{'save'} ], [ "delete", $text{'delete'} ] ) ] );

&ui_print_footer("master.cgi", $text{'master_return'},
		 "", $text{'index_return'});

