#!/usr/local/bin/perl
# view.cgi
# Show details of the action, including changed files

require './webminlog-lib.pl';
&ReadParse();

# find the log record to view
$act = &get_action($in{'id'});
&can_user($act->{'user'}) || &error($text{'view_ecannot'});
&can_mod($act->{'module'}) || &error($text{'view_ecannot'});

# display info about the action
&ui_print_header(undef, $text{'view_title'}, "");

@files = &list_files($act);
if (@files) {
	print &ui_form_start("rollback.cgi");
	print &ui_hidden("id", $in{'id'});
	}

print &ui_table_start(&text('view_header', $act->{'id'}),
		      "width=100%", 4);

# This "" is needed to make the label show properly!
print &ui_table_row($text{'view_action'}."",
		    &get_action_description($act, 1), 3);

%minfo = &get_module_info($act->{'module'});
print &ui_table_row($text{'view_module'},
		    $minfo{'desc'});

print &ui_table_row($text{'view_script'},
		    "<tt>$act->{'module'}/$act->{'script'}</tt>");

print &ui_table_row($text{'view_user'},
		    $act->{'user'});

print &ui_table_row($text{'view_ip'},
		    $act->{'ip'});

if ($act->{'sid'} ne '-') {
	print &ui_table_row($text{'view_sid'},
		"<a href='search.cgi?sid=$act->{'sid'}&uall=1&mall=1&tall=1&fall=1&return=".&urlize($in{'return'})."&returndesc=".&urlize($in{'returndesc'})."'>$act->{'sid'}</a>");
	}

@tm = localtime($act->{'time'});
print &ui_table_row($text{'view_time'},
		    sprintf("%2.2d/%s/%4.4d %2.2d:%2.2d:%2.2d",
			$tm[3], $text{"smonth_".($tm[4]+1)}, $tm[5]+1900,
			$tm[2], $tm[1], $tm[0]));

if ($act->{'webmin'}) {
	print &ui_table_row($text{'view_host'},
			    $act->{'webmin'});
	}

print &ui_table_end(),"<p>\n";

# display modified files
$rbcount = 0;
foreach $d (&list_diffs($act)) {
	local $t = $text{"view_type_".$d->{'type'}};
	local $rb;
	if ($d->{'type'} eq 'create' || $d->{'type'} eq 'modify' ||
	    $d->{'type'} eq 'delete') {
		($rb) = grep { $_->{'file'} eq $d->{'object'} } @files;
		}
	local $cbox = @files ?
		&ui_checkbox("r", $d->{'object'}, "", 1, undef, !$rb) : undef;
	$rbcount++ if ($rb);
	if ($t =~ /\$2/ || !$d->{'diff'}) {
		# Diff is just a single line message
		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>",$cbox,
		      &text("view_type_".$d->{'type'},
			    "<tt>$d->{'object'}</tt>",
			    "<tt>".&html_escape($d->{'diff'})."</tt>"),"</b></td> </tr>\n";
		print "</table><p>\n";
		}
	else {
		# Show multi-line diff
		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>",$cbox,&text("view_type_".$d->{'type'},
		      "<tt>$d->{'object'}</tt>"),"</b></td> </tr>\n";
		print "<tr $cb> <td><pre>";
		print &html_escape($d->{'diff'});
		print "</pre></td> </tr>\n";
		if ($d->{'input'}) {
			# And input too
			print "<tr $tb> <td><b>",&text('view_input'),
			      "</b></td> </tr>\n";
			print "<tr $cb> <td><pre>";
			print &html_escape($d->{'input'});
			print "</pre></td> </tr>\n";
			}
		print "</table><p>\n";
		}
	$anydiffs++;
	}
if ($rbcount) {
	print &ui_links_row([ &select_all_link("r"),
			      &select_invert_link("r") ]);
	}

print "<b>$text{'view_nofiles'}</b><p>\n" if (!$anydiffs);

# Show rollback button
if (@files && $rbcount) {
	print &ui_form_end([ [ "rollback", $text{'view_rollback2'} ] ]);
	}

&ui_print_footer($ENV{'HTTP_REFERER'}, $text{'search_return'},
	"", $text{'index_return'});


