#!/usr/local/bin/perl
# edit_log.cgi
# Show a form for creating or editing a log

require './logrotate-lib.pl';
&ReadParse();
$conf = &get_config();
if ($in{'global'}) {
	&ui_print_header(undef, $text{'global_title'}, "", "global");
	$lconf = $conf;
	}
elsif ($in{'new'}) {
	&ui_print_header(undef, $text{'edit_title2'}, "", "create");
	$log = $conf->[$in{'clone'}], $lconf = $log->{'members'}
	    if ($in{'clone'});
	}
else {
	&ui_print_header(undef, $text{'edit_title1'}, "", "edit");
	$log = $conf->[$in{'idx'}];
	$lconf = $log->{'members'};
	}

print &ui_form_start("save_log.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("idx", $in{'idx'}),"\n";
print &ui_hidden("global", $in{'global'}),"\n";

if (!$in{'global'}) {
	print &ui_table_start($text{'edit_header'}, "width=100%", 2);
	print &ui_table_row($text{'edit_file'},
			    &ui_textarea("file",
				join("\n", @{$log->{'name'}}), 3, 60)." ".
			    &file_chooser_button("file"));
	}
else {
	print &ui_table_start($text{'global_header'}, "width=100%", 2);
	}

$period = &get_period($lconf);
$defperiod = &get_period($conf) if (!$in{'global'});
$dptext = $text{"period_".$defperiod} || $text{'period_never'};
print &ui_table_row($text{'edit_sched'},
		    &ui_select("sched", $period,
				[ [ '', &deftext($dptext)  ],
				  [ 'daily', $text{'period_daily'} ],
				  [ 'weekly', $text{'period_weekly'} ],
				  [ 'monthly', $text{'period_monthly'} ] ]));

$size = &find_value("size", $lconf);
print &ui_table_row($text{'edit_size'},
		    &ui_opt_textbox("size", $size, 10,
				    &deftext(&find_default("size") ||
					     $text{'period_never'})).
		    " ".$text{'period_bytes'});

$minsize = &find_value("minsize", $lconf);
print &ui_table_row($text{'edit_minsize'},
		    &ui_opt_textbox("minsize", $minsize, 10,
				    &deftext(&find_default("minsize") ||
					     $text{'edit_nominsize'})).
		    " ".$text{'period_bytes'});

print &ui_table_hr();

$rotate = &find_value("rotate", $lconf);
print &ui_table_row($text{'edit_rotate'},
		    &ui_opt_textbox("rotate", $rotate, 5,
				    &deftext(&find_default("rotate"))));

&yesno_option("compress", "nocompress", $lconf);
&yesno_option("delaycompress", "nodelaycompress", $lconf);
&yesno_option("copytruncate", "nocopytruncate", $lconf);
&yesno_option("ifempty", "notifempty", $lconf);
&yesno_option("missingok", "nomissingok", $lconf);

print &ui_table_hr();

$create = &find_value("create", $lconf);
$nocreate = &find("nocreate", $lconf);
($mode, $user, $group) = split(/\s+/, $create);
$dcr = &find_default("create");
@crinputs = ( "createmode", "createuser", "creategroup" );
print &ui_table_row($text{'edit_create'},
    &ui_radio("create", defined($create) ? 2 : $nocreate ? 1 : 0,
	      [ [ 2, &text('edit_createas',
		   &ui_textbox("createmode", $mode, 4, !defined($create)),
		   &ui_user_textbox("createuser", $user, 0,
				    !defined($create)),
		   &ui_group_textbox("creategroup", $group, 0,
				     !defined($create)))."<br>",
		   &js_disable_inputs([ ], \@crinputs, "onClick") ],
		[ 1, $text{'edit_createno'}."<br>",
		  &js_disable_inputs(\@crinputs, [ ], "onClick") ],
		[ 0, &deftext($dcr ne '' ? $dcr :
		      defined($dcr) ? $text{'edit_createsame'} :
				$text{'edit_createno'}),
		  &js_disable_inputs(\@crinputs, [ ], "onClick") ] ]));

$olddir = &find_value("olddir", $lconf);
$noolddir = &find("noolddir", $lconf);
print &ui_table_row($text{'edit_olddir'},
    &ui_radio("olddir", $olddir ? 2 : $noolddir ? 1 : 0,
	      [ [ 2, $text{'edit_olddirto'}." ".
		     &ui_textbox("olddirto", $olddir, 30, !$olddir)." ".
		     &file_chooser_button("olddirto", 1)."<br>",
		  &js_disable_inputs([ ], [ "olddirto" ], "onClick") ],
		[ 1, $text{'edit_olddirsame'}."<br>",
		  &js_disable_inputs([ "olddirto" ], [ ], "onClick") ],
		[ 0, &deftext(&find_default("olddir") ||
			      $text{'edit_olddirsame'}),
		  &js_disable_inputs([ "olddirto" ], [ ], "onClick") ] ]));

$ext = &find_value("extension", $lconf);
print &ui_table_row($text{'edit_ext'},
    &ui_opt_textbox("ext", $ext, 10,
		    &deftext(&find_default("ext"))));

&yesno_option("dateext", "nodateext", $lconf);

print &ui_table_hr();

$mail = &find_value("mail", $lconf);
$nomail = &find("nomail", $lconf);
$mmode = $mail ? 2 : $nomail ? 1 : 0;
print &ui_table_row($text{'edit_mail'},
	    &ui_radio("mail", $mmode,
		      [ [ 2, $text{'edit_mailto'}." ".
			     &ui_textbox("mailto", $mail, 30, $mmode != 2).
			     "<br>",
			     &js_disable_inputs([ ], [ "mailto" ], "onClick") ],
			[ 1, $text{'edit_mailno'}."<br>",
			  &js_disable_inputs([ "mailto" ], [ ], "onClick") ],
			[ 0, &deftext(&find_default("mail") ||
				      $text{'edit_mailno'}),
			  &js_disable_inputs([ "mailto" ], [ ], "onClick") ] ]));

$mailfirst = &find("mailfirst", $lconf);
$maillast = &find("maillast", $lconf);
print &ui_table_row($text{'edit_mailfl'},
		    &ui_radio("mailfirst", $mailfirst ? 2 : $maillast ? 1 : 0,
			      [ [ 2, $text{'edit_mailfirst'}."<br>" ],
				[ 1, $text{'edit_maillast'}."<br>" ],
				[ 0, &deftext(defined(
					&find_default("mailfirst")) ?
						$text{'edit_mailfirst'} :
						$text{'edit_maillast'}) ] ]));

if (&compare_version_numbers(&get_logrotate_version(), 3.6) < 0) {
	$errors = &find_value("errors", $lconf);
	print &ui_table_row($text{'edit_errors'},
			    &ui_opt_textbox("errors", $errors, 30,
				    &deftext(&find_default("errors") ||
					     $text{'edit_errorsno'})."<br>",
				    $text{'edit_errorsto'}));
	}

print &ui_table_hr();

$pre = &find_value("prerotate", $lconf);
print &ui_table_row($text{'edit_pre'},
		    &ui_textarea("pre", $pre, 3, 60));

$post = &find_value("postrotate", $lconf);
print &ui_table_row($text{'edit_post'},
		    &ui_textarea("post", $post, 3, 60));

if (&compare_version_numbers(&get_logrotate_version(), 3.4) >= 0) {
	&yesno_option("sharedscripts", "nosharedscripts", $lconf);
	}

print &ui_table_end();
if ($in{'global'}) {
	print &ui_form_end([ [ 'save', $text{'save'} ] ], "100%");
	}
elsif ($in{'new'}) {
	print &ui_form_end([ [ 'create', $text{'create'} ] ], "100%");
	}
else {
	print &ui_form_end([ [ 'save', $text{'save'} ],
			     [ 'now', $text{'edit_now'} ],
			     [ 'delete', $text{'delete'} ] ], "100%");

	print &ui_form_start("edit_log.cgi",
	    undef, undef, undef, 'ui_form ui_table_end_submit_right');
	print &ui_hidden("clone", $in{'idx'});
	print &ui_hidden("new", 1);
	print &ui_submit($text{'edit_clone'});
	print &ui_form_end();
	}

&ui_print_footer("", $text{'index_return'});

# yesno_option(name1, name2, &conf)
sub yesno_option
{
local $y = &find($_[0], $_[2]);
local $n = &find($_[1], $_[2]);
local $yd = &find_default($_[0]);
local $nd = &find_default($_[1]);
print &ui_table_row($text{'edit_'.$_[0]},
		    &ui_radio($_[0], $y ? 2 : $n ? 1 : 0,
			      [ [ 2, $text{'yes'} ],
			 	[ 1, $text{'no'} ],
			 	[ 0, &deftext(defined($yd) ? $text{'yes'} : $text{'no'}) ] ]), 1);
}

# find_default(name, [global])
sub find_default
{
if ($in{'global'} || $_[1]) {
	# Return global hard-coded default
	return $global_default{$_[0]};
	}
else {
	# Look at global first
	local $rv = &find_value($_[0], $conf);
	return $rv if (defined($rv));
	return &find_default($_[0], 1);
	}
}

sub deftext
{
return $_[0] ? &text('edit_default', $_[0]) : $text{'default'};
}
