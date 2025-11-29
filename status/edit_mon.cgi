#!/usr/local/bin/perl
# edit_mon.cgi
# Display a form for editing or creating a monitor

require './status-lib.pl';
$access{'edit'} || &error($text{'mon_ecannot'});
&foreign_require("servers", "servers-lib.pl");
&ReadParse();
@handlers = &list_handlers();
if ($in{'type'}) {
	# Create a new monitor
	$in{'type'} =~ /^[a-zA-Z0-9\_\-\.\:]+$/ || &error($text{'mon_etype'});
	$type = $in{'type'};
	$title = $text{'mon_create'};
	if ($in{'clone'}) {
		# Clone of existing
		$serv = &get_service($in{'clone'});
		}
	else {
		# Totally new
		$serv = { 'notify' => 'email pager snmp sms webhook',
			  'fails' => 1,
			  'nosched' => 0,
			  'remote' => '*' };
		}
	}
else {
	# Editing an existing monitor
	$serv = &get_service($in{'id'});
	$type = $serv->{'type'};
	$title = $text{'mon_edit'};
	}
($han) = grep { $_->[0] eq $type } @handlers;
if ($in{'type'} && !$in{'clone'}) {
	$serv->{'desc'} = $han->[1];
	}
&ui_print_header($han->[1], $title, "");

if ($serv->{'virtualmin'} && &foreign_check("virtual-server")) {
	# Owned by a Virtualmin domain - don't recommend editing
	&foreign_require("virtual-server");
	$d = &virtual_server::get_domain($serv->{'virtualmin'});
	if ($d) {
		print &ui_alert_box(&text('mon_virtualmin',
			&virtual_server::show_domain_name($d)), 'warn');
		}
	}

print &ui_form_start("save_mon.cgi", "post");
print &ui_hidden("type", $in{'type'}),"\n";
print &ui_hidden("id", $in{'id'}),"\n";
@tds = ( "width=30%" );
print &ui_table_start($text{'mon_header'}, "width=100%", 2, \@tds);

# Check for clone modules of the monitor type
($mod = $type) =~ s/::.*$//;
@minfos = &get_all_module_infos();
($minfo) = grep { $_->{'dir'} eq $mod } @minfos;
if ($minfo) {
	@clones = grep { $_->{'cloneof'} eq $minfo->{'dir'} } @minfos;
	}

# Show input for description
print &ui_table_row($text{'mon_desc'},
		    &ui_textbox("desc", $serv->{'desc'}, 50),
		    undef, \@tds);

# Show current status
if (!$in{'type'}) {
	@stats = &service_status($serv, 1);
	$stable = "<table cellpadding=1 cellspacing=1>\n";
	foreach $stat (@stats) {
		$stable .= "<tr>\n";
		if (@stats > 1 || $stat->{'remote'} ne "*") {
			$stable .=
			    "<td>".
			    ($stat->{'remote'} eq "*" ? $text{'mon_local'}
						      : $stat->{'remote'}).
			    "</td>\n";
			$stable .= "<td>:</td>\n";
			}
		$stable .= "<td>".
		      ($stat->{'desc'} && $stat->{'up'} == 0 ?
			 "<font color=#ff0000>$stat->{'desc'}</font>" :
		       $stat->{'desc'} ? $stat->{'desc'}
				       : &status_to_string($stat->{'up'}, $serv)).
			"</td>\n";
		$stable .= "</tr>\n";
		}
	$stable .= "</table>\n";
	print &ui_table_row($text{'mon_status'}, $stable,
			    undef, \@tds);
	}

# Display inputs for this monitor type
if ($type =~ /^(\S+)::(\S+)$/) {
	# From another module
	($mod, $mtype) = ($1, $2);
	&foreign_require($mod, "status_monitor.pl");
	&foreign_call($mod, "load_theme_library");
	if (&foreign_defined($mod, "status_monitor_dialog")) {
		print &foreign_call($mod, "status_monitor_dialog",
				    $mtype, $serv);
		}
	}
else {
	# From this module
	do "./${type}-monitor.pl";
	$func = "show_${type}_dialog";
	if (defined(&$func)) {
		&$func($serv);
		}
	}

# Show servers to run on
@servs = grep { $_->{'user'} } &servers::list_servers_sorted();
@servs = sort { $a->{'host'} cmp $b->{'host'} } @servs;
if (@servs) {
	# Show list of remote servers, and maybe groups
	$s = &ui_select("remotes", [ split(/\s+/, $serv->{'remote'}) ],
			 [ [ "*", "&lt;$text{'mon_local'}&gt;" ],
			   map { [ $_->{'host'}, $_->{'host'} ] } @servs ],
			 5, 1, 1),
	@groups = &servers::list_all_groups(\@servs);
	@groups = sort { $a->{'name'} cmp $b->{'name'} } @groups;
	if (@groups) {
		$s .= &ui_select("groups", [ split(/\s+/, $serv->{'groups'}) ],
			 [ map { [ $_->{'name'}, &group_desc($_) ] } @groups ],
			 5, 1, 1),
		}
	print &ui_table_row($text{'mon_remotes2'}, $s, undef, \@tds);
	}
else {
	# Only local is available
	print &ui_hidden("remotes", "*"),"\n";
	}

print &ui_table_end();

print &ui_table_start($text{'mon_header5'}, "width=100%", 2, \@tds);

# Show emailing schedule
print &ui_table_row($text{'mon_nosched'},
		    &ui_select("nosched", int($serv->{'nosched'}),
			       [ [ 1, $text{'no'} ],
				 [ 0, $text{'mon_warndef'} ],
				 [ 3,  $text{'mon_warn1'} ],
				 [ 2,  $text{'mon_warn0'} ],
				 [ 4,  $text{'mon_warn2'} ],
				 [ 5,  $text{'mon_warn3'} ] ]),
		    undef, \@tds);

# Show number of failures
print &ui_table_row($text{'mon_fails'},
		    &ui_textbox("fails", $serv->{'fails'}, 5),
		    undef, \@tds);

# Show notification mode
$notify = "";
%notify = map { $_, 1 } split(/\s+/, $serv->{'notify'});
foreach $n (&list_notification_modes()) {
	$notify .= &ui_checkbox("notify", $n, $text{'mon_notify'.$n},
				$notify{$n})."\n";
	delete($notify{$n});
	}
foreach $n (keys %notify) {
	# Don't clear set but un-usable modes
	print &ui_hidden("notify", $n);
	}
print &ui_table_row(&hlink($text{'mon_notify'}, "notify"), $notify,
		    undef, \@tds);

# Show extra address to email
print &ui_table_row($text{'mon_email'},
		    &ui_textbox("email", $serv->{'email'}, 60),
		    undef, \@tds);

# Show template to use
@tmpls = &list_templates();
if (@tmpls) {
	if ($in{'type'}) {
		($deftmpl) = grep { $_->{'desc'} eq $config{'def_tmpl'}} @tmpls;
		if ($deftmpl) {
			$tid = $deftmpl->{'id'};
			}
		}
	else {
		$tid = $serv->{'tmpl'};
		}
	print &ui_table_row($text{'mon_tmpl'},
		&ui_select("tmpl", $tid,
			   [ [ "", "&lt;$text{'mon_notmpl'}&gt;" ],
			     map { [ $_->{'id'}, $_->{'desc'} ] } @tmpls ]));
	}

# Which clone module to use
if (@clones) {
	print &ui_table_row($text{'mon_clone'},
		   &ui_select("clone", $serv->{'clone'},
		      [ [ "", $minfo->{'desc'} ],
			map { [ $_->{'dir'}, $_->{'desc'} ] } @clones ]),
		   undef, \@tds);
	}

# Skip if some other monitor is down
@servs = &list_services();
if (@servs) {
	print &ui_table_row($text{'mon_depend'},
	  &ui_select("depend", $serv->{'depend'},
		 [ [ "", "&nbsp;" ],
		   map { [ $_->{'id'}, $_->{'desc'}.
				       " (".&nice_remotes($_).")" ] }
		     sort { $a->{'desc'} cmp $b->{'desc'} } @servs ]),
	  undef, \@tds);
	}

print &ui_table_end();

print &ui_table_start($text{'mon_header2'}, "width=100%", 2, \@tds);

# Show commands to run on up/down
print &ui_table_row($text{'mon_ondown'},
		    &ui_textbox("ondown", $serv->{'ondown'}, 60),
		    undef, \@tds);

print &ui_table_row($text{'mon_onup'},
		    &ui_textbox("onup", $serv->{'onup'}, 60),
		    undef, \@tds);

print &ui_table_row($text{'mon_ontimeout'},
		    &ui_textbox("ontimeout", $serv->{'ontimeout'}, 60),
		    undef, \@tds);

print &ui_table_row(" ", "<font size=-1>$text{'mon_oninfo'}</font>",
		    undef, \@tds);

# Radio button for where to run commands
print &ui_table_row($text{'mon_runon'},
		    &ui_radio("runon", $serv->{'runon'} ? 1 : 0,
			      [ [ 0, $text{'mon_runon0'} ],
				[ 1, $text{'mon_runon1'} ] ]),
		    undef, \@tds);

print &ui_table_end();

# Show history, in a hidden section
if (!$in{'type'}) {
	@history = &list_history($serv,
				 $in{'all'} ? undef : $config{'history_show'});
	}
if (@history) {
	print &ui_hidden_table_start($text{'mon_header4'}, "width=100%", 2,
		"history", defined($in{'all'}) || defined($in{'changes'}));

	# Build links to switch to changes-only mode or show all history
	@links = ( );
	if ($in{'changes'}) {
		push(@links, "<a href='edit_mon.cgi?id=$in{'id'}&changes=0&".
			     "all=$in{'all'}'>$text{'mon_changes0'}</a>");
		}
	else {
		push(@links, "<a href='edit_mon.cgi?id=$in{'id'}&changes=1&".
			     "all=$in{'all'}'>$text{'mon_changes1'}</a>");
		}
	if (!$in{'all'}) {
		push(@links, "<a href='edit_mon.cgi?id=$in{'id'}&changes=".
			     "$in{'changes'}&all=1'>$text{'mon_all'}</a>");
		}
	if ($in{'changes'}) {
		@history = grep { $_->{'old'} ne $_->{'new'} } @history;
		}

	# Check if any history events have a value
	$anyvalue = 0;
	foreach $h (@history) {
		foreach my $hv (split(/\//, $h->{'value'})) {
			my ($vhost, $v) = split(/=/, $hv, 2);
			if ($v ne '') {
				$anyvalue++;
				last;
				}
			}
		}

	# Show history table
	$links = &ui_links_row(\@links);
	$table = &ui_columns_start([
		$text{'mon_hwhen'},
		$text{'mon_hold'},
		$text{'mon_hnew'},
		$anyvalue ? ( $text{'mon_hvalue'} ) : ( ) ]);
	foreach $h (reverse(@history)) {
		my @cols = ( &make_date($h->{'time'}) );
		foreach my $s ($h->{'old'}, $h->{'new'}) {
			my @ups;
			my @statuses = split(/\s+/, $s);
			foreach my $rs (@statuses) {
				my ($host, $up) = split(/=/, $rs, 2);
				$img = "<img src=".&get_status_icon($up).">";
				if ($host ne "*") {
					$img = $host.$img;
					}
				elsif (@statuses > 1) {
					$img = &get_display_hostname().$img;
					}
				push(@ups, $img);
				}
			push(@cols, join(" ", @ups));
			}
		if ($anyvalue) {
			my @vlist;
			my @values = split(/\//, $h->{'value'});
			my @nice_values = split(/\//, $h->{'nice_value'});
			for(my $i=0; $i<@values; $i++) {
				my ($vhost, $v) = split(/=/, $values[$i], 2);
				my (undef, $nv) = split(/=/, $nice_values[$i], 2);
				push(@vlist, $nv || $v);
				}
			push(@cols, join(" ", @vlist));
			}
		$table .= &ui_columns_row(\@cols);
		}
	$table .= &ui_columns_end();
	if (@history) {
		print &ui_table_row(undef, $links.$table, 2);
		}
	else {
		print &ui_table_row(undef, $links.
			&text('mon_nochanges', $config{'history_show'}), 2);
		}
	print &ui_hidden_table_end();
	}

# Show create/delete buttons
if ($in{'type'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "newclone", $text{'mon_clone2'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

