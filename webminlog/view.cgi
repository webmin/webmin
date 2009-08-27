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
print &ui_form_start("rollback.cgi");
print &ui_hidden("id", $in{'id'});
print &ui_hidden("search", $in{'search'});

print &ui_hidden_table_start(&text('view_header', $act->{'id'}),
		      	     "width=100%", 4, "main", 1);

# This "" is needed to make the label show properly!
print &ui_table_row($text{'view_action'}."",
		    &get_action_description($act, 1), 3);

%minfo = $act->{'module'} eq 'global' ?
		( 'desc' => $text{'search_global'} ) :
		&get_module_info($act->{'module'});
print &ui_table_row($text{'view_module'},
		    $minfo{'desc'});

if ($act->{'module'} ne 'global') {
	print &ui_table_row($text{'view_script'},
			    "<tt>$act->{'module'}/$act->{'script'}</tt>");
	}
else {
	print &ui_table_row($text{'view_script'}, "<tt>$act->{'script'}</tt>");
	}

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
print &ui_hidden_table_end("main");

# Annotations for this log entry
$text = &get_annotation($act);
print &ui_hidden_table_start($text{'view_anno'}, "width=100%", 1, "anno",
			     $text ? 1 : 0);
print &ui_table_row(undef,
	&ui_textarea("anno", $text, 10, 80, "auto", 0,
		     "style='width:100%'")."<br>".
	&ui_submit($text{'save'}, "annosave"));
print &ui_hidden_table_end("anno");

# Raw log data, hidden by default
print &ui_hidden_table_start($text{'view_raw'}, "width=100%", 1, "raw", 0);
@tds = ( "width=20% ");
$rtable = &ui_columns_start([ $text{'view_rawname'}, $text{'view_rawvalue'} ],
			    100, 0, \@tds);
foreach $k (keys %$act) {
	next if ($k eq 'param');
	$rtable .= &ui_columns_row([
		"<b>".&html_escape($k)."</b>",
		&html_escape($act->{$k}) ], \@tds);
	}
foreach $k (keys %{$act->{'param'}}) {
	$rtable .= &ui_columns_row([
		&html_escape($k),
		&html_escape(join("\n", split(/\0/, $act->{'param'}->{$k}))) ],
		\@tds);
	}
$rtable .= &ui_columns_end();
print &ui_table_row(undef, $rtable, 2);
print &ui_hidden_table_end("raw");

# display modified files
$rbcount = 0;
$i = 0;
foreach $d (&list_diffs($act)) {
	local $t = $text{"view_type_".$d->{'type'}};
	local $rb;
	if ($d->{'type'} eq 'create' || $d->{'type'} eq 'modify' ||
	    $d->{'type'} eq 'delete') {
		($rb) = grep { $_->{'file'} eq $d->{'object'} } @files;
		}
	local $cbox = @files ?
		&ui_checkbox("r", $d->{'object'}, "", $rb, undef, !$rb) : undef;
	$rbcount++ if ($rb);
	if ($t =~ /\$2/ || !$d->{'diff'}) {
		# Diff is just a single line message
		print &ui_hidden_table_start($cbox.
		      &text("view_type_".$d->{'type'},
			    "<tt>$d->{'object'}</tt>",
			    "<tt>".&html_escape($d->{'diff'})."</tt>"),
		      "width=100%", 2, "diff$i", 1);
		}
	else {
		# Show multi-line diff
		print &ui_hidden_table_start(
			$cbox.&text("view_type_".$d->{'type'},
			            "<tt>$d->{'object'}</tt>"),
			"width=100%", 2, "diff$i", 1);
		print &ui_table_row(undef,
			"<pre>".&html_escape($d->{'diff'})."</pre>", 2);
		if ($d->{'input'}) {
			# And input too
			print &ui_table_row(undef,
				"<b>".&text('view_input')."</b><br>".
				"<pre>".&html_escape($d->{'input'})."</pre>",2);
			}
		}
	print &ui_hidden_table_end("diff$i");
	$i++;
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
else {
	print &ui_form_end();
	}

&ui_print_footer("search.cgi?$in{'search'}", $text{'search_return'},
		 "", $text{'index_return'});


