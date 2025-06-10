#!/usr/local/bin/perl
# edit_log.cgi
# Display a form for editing or creating a new log destination

require './syslog-lib.pl';
&ReadParse();
$access{'noedit'} && &error($text{'edit_ecannot'});
$access{'syslog'} || &error($text{'edit_ecannot'});
$conf = &get_config();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "");
	$log = { 'active' => '1',
		 'sync' => 1,
		 'file' => -d '/var/log' ? '/var/log/' :
			   -d '/var/adm' ? '/var/adm/' : undef };
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "");
	$log = $conf->[$in{'idx'}];
	&can_edit_log($log) || &error($text{'edit_ecannot2'});
	}

# Log destination section
print &ui_form_start("save_log.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'edit_header1'}, "width=100%", 2);

# Log destination, starting with file
@dopts = ( [ 0, $text{'edit_file'},
	     &ui_textbox("file", $log->{'file'}, 40)." ".
	     &file_chooser_button("file")." ".
	     ($config{'sync'} ? "<br>".&ui_checkbox("sync", 1,
				$text{'edit_sync'}, $log->{'sync'}) : "") ]);

# Named pipe
if ($config{'pipe'} == 1) {
	push(@dopts, [ 1, $text{'edit_pipe'},
		       &ui_textbox("pipe", $log->{'pipe'}, 40)." ".
		       &file_chooser_button("pipe") ]);
	}
elsif ($config{'pipe'} == 2) {
	push(@dopts, [ 1, $text{'edit_pipe2'},
		       &ui_textbox("pipe", $log->{'pipe'}, 40) ]);
	}

# Socket file
if ($config{'socket'}) {
	push(@dopts, [ 5, $text{'edit_socket'},
		       &ui_textbox("socket", $log->{'socket'}, 40)." ".
		       &file_chooser_button("socket") ]);
	}

# Send to users
push(@dopts, [ 3, $text{'edit_users'},
	       &ui_textbox("users", join(" ", @{$log->{'users'}}), 40)." ".
	       &user_chooser_button("users", 1) ]);

# All users
push(@dopts, [ 4, $text{'edit_allusers'} ]);

# Remote host
push(@dopts, [ 2, $text{'edit_host'},
	       &ui_textbox("host", $log->{'host'}, 30) ]);

print &ui_table_row($text{'edit_logto'},
	&ui_radio_table("mode", $log->{'file'} ? 0 :
				$log->{'pipe'} ? 1 :
				$log->{'socket'} ? 5 :
				$log->{'host'} ? 2 :
				$log->{'users'} ? 3 :
				$log->{'all'} ? 4 : -1, \@dopts));

# Log active?
print &ui_table_row($text{'edit_active'},
	&ui_yesno_radio("active", $log->{'active'}));

if ($config{'tags'}) {
	# Tag name
	print &ui_table_row($text{'edit_tag'},
	    &ui_select("tag", $log->{'section'}->{'tag'},
		[ map { [ $_->{'index'},
			  $_->{'tag'} eq '*' ? $text{'all'} : $_->{'tag'} ] }
		      grep { $_->{'tag'} } @$conf ]));
	}

print &ui_table_end();

# Log selection section
print &ui_table_start($text{'edit_header2'}, "width=100%", 2);

@facil = split(/\s+/, $config{'facilities'});
$table = &ui_columns_start([ $text{'edit_facil'}, $text{'edit_pri'} ], 100);
$i = 0;
foreach $s (@{$log->{'sel'}}, ".none") {
	($f, $p) = split(/\./, $s);
	$p =~ s/warn$/warning/;
	$p =~ s/panic$/emerg/;
	$p =~ s/error$/err/;

	# Facility column
	local $facil;
	$facil .= &ui_radio("fmode_$i", $f =~ /,/ ? 1 : 0,
	   [ [ 0, &ui_select("facil_$i", $f =~ /,/ ? undef : $f,
		     [ [ undef, '&nbsp;' ],
		       [ '*', $text{'edit_all'} ],
		       @facil ], 1, 0, 1) ],
	     [ 1, $text{'edit_many'}." ".
		  &ui_textbox("facils_$i",
			$f =~ /,/ ? join(" ", split(/,/, $f)) : '', 25) ] ]);

	# Priorities range selector
	if ($config{'pri_dir'} == 1) {
		# Linux style
		$psel = &ui_select("pdir_$i",
		    $p eq '*' || $p eq 'none' ? '' :
		      $p =~ /^=/ ? '=' :
		      $p =~ /^![^=]/ ? '!' :
		      $p =~ /^!=/ ? '!=' : '',
		    [ [ '', $text{'edit_pdir0'} ],
		      [ '=', $text{'edit_pdir1'} ],
		      [ '!', $text{'edit_pdir2'} ],
		      [ '!=', $text{'edit_pdir3'} ] ]);
		$p =~ s/^[!=]*//;
		}
	elsif ($config{'pri_dir'} == 2) {
		# FreeBSD style
		local $pfx = $p =~ /^([<=>]+)/ ? $1 : undef;
		$psel = &ui_select("pdir_$i",
		    $p eq '*' || $p eq 'none' ||
		      $pfx eq '>=' || $pfx eq '=>' || !$pfx ? '' :
		    $pfx eq '<=' || $pfx eq '=<' ? '<=' :
		    $pfx eq '<>' || $pfx eq '><' ? '<>' : $pfx,
		    [ [ '', '&gt;=' ],
		      [ '>', '&gt;' ],
		      [ '<=', '&lt;=' ],
		      [ '<', '&lt;' ],
		      [ '<>', '&lt;&gt;' ] ], 1, 0, 1);
		$p =~ s/^[<=>]*//;
		}
	else {
		# No range selection allowed
		$psel = $text{'edit_pdir0'};
		}

	# Priorities column
	local $pri;
	local $pmode = $p eq 'none' ? 0 : $p eq '*' ? 1 : 2;
	$pri .= &ui_radio("pmode_$i", $pmode,
	   [ [ 0, $text{'edit_none'} ],
	     $config{'pri_all'} ? ( [ 1, $text{'edit_all'} ] ) : ( ),
	     [ 2, $psel ] ]);

	# Priority menu
	local $selpri;
	foreach $pr (&list_priorities()) {
		$selpri = $pr if ($p =~ /$pr/);
		}
	$pri .= &ui_select("pri_$i", $selpri,
	   [ $p eq '*' || $p eq 'none' ? ( '' ) : ( ),
	     &list_priorities() ], 1, 0, 1);

	$table .= &ui_columns_row([ $facil, $pri ]);
	$i++;
	}
$table .= &ui_columns_end();
print &ui_table_row(undef, $table, 2);
print &ui_table_end();

@buts = ( [ undef, $text{'save'} ] );
if (!$in{'new'}) {
	if ($log->{'file'} && -f $log->{'file'}) {
		push(@buts, [ 'view', $text{'edit_view'} ]);
		}
	push(@buts, [ 'delete', $text{'delete'} ]);
	}
print &ui_form_end(\@buts);

&ui_print_footer("", $text{'index_return'});

