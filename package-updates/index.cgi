#!/usr/local/bin/perl
# Show installed packages, and flag those for which an update is needed

require './package-updates-lib.pl';
&ui_print_header(undef, $module_info{'desc'}, "", undef, 1, 1);
&error_setup($text{'index_err'});
&ReadParse();
if ($in{'clear'}) {
	$in{'search'} = '';
	}
$has_repos = defined(&software::list_package_repos);

# Start of mode tabs
print &ui_tabs_start([ [ 'pkgs', $text{'index_tabpkgs'} ],
		       [ 'sched', $text{'index_tabscheds'} ],
		       $has_repos ? ( [ 'repos', $text{'index_tabsrepos'} ] )
				  : ( ) ],
		     'tab', $in{'tab'} || 'pkgs', 1);

# See if any security updates exist
$in{'mode'} ||= 'updates';
@avail = &list_for_mode($in{'mode'}, 0);

# Show mode selector (all, updates only, updates and new)
@grid = ( );
foreach $m ('current', 'updates', 'security', 'new') {
	$mmsg = $text{'index_mode_'.$m};
	if ($in{'mode'} eq $m) {
		push(@mlinks, "<b>$mmsg</b>");
		}
	else {
		push(@mlinks, &ui_link("index.cgi?mode=$m&all=".
			      &urlize($in{'all'})."&search=".
			      &urlize($in{'search'}), $mmsg) );
		}
	}
push(@grid, $text{'index_mode'}, &ui_links_row(\@mlinks));

# Show search box
push(@grid, $text{'index_search'}, &ui_textbox("search", $in{'search'}, 30)." ".
				   &ui_submit($text{'index_searchok'})." ".
				   &ui_submit($text{'index_clear'}, 'clear'));

print &ui_tabs_start_tab("tab", "pkgs");
print &ui_form_start("index.cgi");
print &ui_hidden("mode", $in{'mode'});
print &ui_grid_table(\@grid, 2),"<p>\n";
print &ui_form_end();

# Work out what packages to show
@current = &list_current(1);

# Make lookup hashes
foreach my $c (@current) {
	$current{$c->{'name'}."/".$c->{'system'}} ||= $c;
	}
foreach my $a (@avail) {
	$avail{$a->{'name'}."/".$a->{'system'}} ||= $a;
	}

# Build table
$anysource = 0;
$upmode = $in{'mode'} eq 'updates' || $in{'mode'} eq 'security';
foreach $p (sort { $a->{'name'} cmp $b->{'name'} } (@current, @avail)) {
	next if ($done{$p->{'name'},$p->{'system'}}++);	# May be in both lists

	# Work out the status
	$c = $current{$p->{'name'}."/".$p->{'system'}};
	$a = $avail{$p->{'name'}."/".$p->{'system'}};

	if ($a && $c && (&compare_versions($a, $c) > 0 || $upmode)) {
		# An update is available
		$msg = "<b><font color=#00aa00>".
		       &text('index_new', $a->{'version'})."</font></b>";
		$need = 1;
		next if ($in{'mode'} eq 'security' && !$a->{'security'});
		next if ($in{'mode'} ne 'updates' &&
			 $in{'mode'} ne 'current' &&
			 $in{'mode'} ne 'security');
		}
	elsif ($a && !$c) {
		# Could be installed, but isn't currently
		next if (!&installation_candiate($a));
		$msg = "<font color=#00aa00>$text{'index_caninstall'}</font>";
		$need = 0;
		next if ($in{'mode'} ne 'new');
		}
	elsif (!$a->{'version'} && $c->{'updateonly'}) {
		# No update exists, and we don't care unless there is one
		next;
		}
	elsif (!$a->{'version'}) {
		# No update exists
		$msg = "<font color=#ffaa00><b>".
			&text('index_noupdate', $c->{'version'})."</b></font>";
		$need = 0;
		next if ($in{'mode'} ne 'current');
		}
	else {
		# We have the latest
		$msg = &text('index_ok', $c->{'version'});
		$need = 0;
		next if ($in{'mode'} ne 'current');
		}
	$source = ucfirst($a->{'source'});
	if ($a->{'security'}) {
		$source = "<font color=#ff0000>$source</font>";
		}

	# If searching, limit to search
	if ($in{'search'}) {
		$re = $in{'search'};
		$found = $p->{'desc'} =~ /\Q$re\E/i ||
			 $p->{'name'} =~ /\Q$re\E/i ||
			 $p->{'version'} =~ /\Q$re\E/i;
		next if (!$found);
		}

	# Add to table
	push(@rows, [
		{ 'type' => 'checkbox', 'name' => 'u',
		  'value' => $p->{'update'}."/".$p->{'system'},
		  'checked' => $need },
		&ui_link("view.cgi?mode=$in{'mode'}&name=".
		  &urlize($p->{'name'})."&system=".
		  &urlize($p->{'system'})."&search=".
		  &urlize($in{'search'}), $p->{'name'}),
		$p->{'desc'},
		$msg,
		$source ? ( $source ) : ( ),
		]);
	$anysource++ if ($source);
	}
if ($anysource) {
	foreach my $r (@rows) {
		$r->[4] ||= "";
		}
	}

if ($in{'mode'} eq 'new' && !$in{'search'}) {
	# Prevent display of a huge list of new packages
	print &text('index_manynew', scalar(@rows)),"<br>\n";
	}
else {
	# Show the packages, if any
	if (@rows) {
		print &text('index_count', scalar(@rows)),"<br>\n";
		print &ui_form_start("update.cgi", "post");
		print &ui_submit($in{'mode'} eq 'new' ? $text{'index_install'}
		                           : $text{'index_update'}, "ok_top" );
		print &ui_submit($text{'index_refresh'}, "refresh_top"), "<br>";
		}
	print &ui_form_columns_table(
		"",
		[ [ "ok", $in{'mode'} eq 'new' ? $text{'index_install'}
					       : $text{'index_update'} ],
		  [ "refresh", $text{'index_refresh'} ] ],
		1,
		undef,
		[ [ "mode", $in{'mode'} ],
		  [ "search", $in{'search'} ] ],
		[ "", $text{'index_name'}, $text{'index_desc'},
		  $text{'index_status'},
		  $anysource ? ( $text{'index_source'} ) : ( ), ],
		100,
		\@rows,
		undef,
		0,
		undef,
		$text{'index_none_'.$in{'mode'}},
		1
		);
	if (!@rows) {
		print &ui_form_start("update.cgi");
		print &ui_hidden("mode", $in{'mode'});
		print &ui_hidden("search", $in{'search'});
		print &ui_form_end([ [ "refresh", $text{'index_refresh'} ] ]);
		}
	}
print &ui_tabs_end_tab("tab", "pkgs");

# Show scheduled report form
print &ui_tabs_start_tab("tab", "sched");
print $text{'index_scheddesc'},"<p>\n";
print &ui_form_start("save_sched.cgi");
print &ui_hidden("mode", $in{'mode'});
print &ui_hidden("search", $in{'search'});
print &ui_table_start($text{'index_header'}, undef, 2);

$job = &find_cron_job();
if ($job) {
	$sched = $job->{'hours'} eq '*' ? 'h' :
		 $job->{'days'} eq '*' && $job->{'weekdays'} eq '*' ? 'd' :
		 $job->{'days'} eq '*' && $job->{'months'} eq '*' ? 'w' :
								    undef;
	}
else {
	$sched = "d";
	}

# When to run
print &ui_table_row($text{'index_sched'},
		    &ui_radio("sched_def", $job ? 0 : 1,
			      [ [ 1, $text{'index_sched1'} ],
			        [ 0, $text{'index_sched0'} ] ])."\n".
		    &ui_select("sched", $sched,
			       [ [ 'h', $text{'index_schedh'} ],
			         [ 'd', $text{'index_schedd'} ],
			         [ 'w', $text{'index_schedw'} ] ]));

# Send email to
if ($gconfig{'webmin_email_to'}) {
	$efield = &ui_opt_textbox("email",
		$config{'sched_email'} eq '*' ? undef : $config{'sched_email'},
		40, &text('index_email_def',
			  "<tt>$gconfig{'webmin_email_to'}</tt>"));
	}
else {
	$efield = &ui_textbox("email", $config{'sched_email'}, 40);
	}
print &ui_table_row($text{'index_email'}, $efield);

# Install or just notify?
print &ui_table_row($text{'index_action'},
		    &ui_radio("action", int($config{'sched_action'}),
			       [ [ -1, $text{'index_action-1'} ],
			         [ 0, $text{'index_action0'} ],
			         [ 1, $text{'index_action1'} ],
			         [ 2, $text{'index_action2'} ] ]));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);
print &ui_tabs_end_tab("tab", "sched");

if ($has_repos) {
	print &ui_tabs_start_tab("tab", "repos");
	print $text{'index_reposdesc'},"<p>\n";

	@repos = &software::list_package_repos();
	if (@repos) {
		print &ui_form_start("save_repos.cgi", "post");
		print &ui_columns_start([
			"",
			$text{'index_reposname'},
			$text{'index_reposenabled'},
			$text{'index_reposurl'},
			]);
		foreach my $r (@repos) {
			print &ui_checked_columns_row([
				&html_escape($r->{'name'}),
				$r->{'enabled'} ?
				    "<font color=green>$text{'yes'}</font>" :
				    "<font color=red>$text{'no'}</font>",
				$r->{'url'},
				], "", "d", $r->{'id'}, undef, $r->{'cannot'});
			}
		print &ui_columns_end();
		print &ui_form_end([
			[ "disable", $text{'index_reposdisable'} ],
			[ "enable", $text{'index_reposenable'} ],
			[ "delete", $text{'index_reposdelete'} ],
			]);
		}
	else {
		print "<b>$text{'index_reposnome'}</b><p>\n";
		}

	# Form to add a repo
	print &ui_form_start("create_repo.cgi", "post");
	print &ui_table_start($text{'index_repoheader'}, undef, 2);
	print &software::create_repo_form();
	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'create'} ] ]);

	print &ui_tabs_end_tab("tab", "repos");
	}

print &ui_tabs_end(1);

&ui_print_footer("/", $text{'index'});

