#!/usr/local/bin/perl
# Show installed packages, and flag those for which an update is needed

require './package-updates-lib.pl';
&ui_print_header(undef, $module_info{'desc'}, "", undef, 1, 1);
&error_setup($text{'index_err'});
&ReadParse();
if ($in{'clear'}) {
	$in{'search'} = '';
	}

# See if any security updates exist
$in{'mode'} ||= 'updates';
if (!defined($in{'all'})) {
	$in{'all'} = &foreign_check("virtual-server") ? 1 : 0;
	}
@avail = &list_available(0, $in{'all'});
($sec) = grep { $_->{'security'} } @avail;

# Show mode selector (all, updates only, updates and new)
@grid = ( );
foreach $m ('all', 'updates', 'new', 'both',
	    $sec ? ( 'security' ) : ( )) {
	$mmsg = $text{'index_mode_'.$m};
	if ($in{'mode'} eq $m) {
		push(@mlinks, "<b>$mmsg</b>");
		}
	else {
		push(@mlinks, "<a href='index.cgi?mode=$m&all=".
			      &urlize($in{'all'})."&search=".
			      &urlize($in{'search'})."'>$mmsg</a>");
		}
	}
push(@grid, $text{'index_mode'}, &ui_links_row(\@mlinks));

# Show all selector
$showall = &show_all_option();
if ($showall == 1) {
	# Can show all, or just virtualmin
	$in{'all'} ||= 0;
	foreach $a (0, 1) {
		$amsg = $text{'index_all_'.$a};
		if ($in{'all'} eq $a) {
			push(@alinks, "<b>$amsg</b>");
			}
		else {
			push(@alinks, "<a href='index.cgi?mode=".
				&urlize($in{'mode'})."&all=$a&search=".
				&urlize($in{'search'})."'>$amsg</a>");
			}
		}
	push(@grid, $text{'index_allsel'}, &ui_links_row(\@alinks));
	}
elsif ($showall == 2) {
	# Always showing all
	$in{'all'} = 2;
	}

# Show search box
push(@grid, $text{'index_search'}, &ui_textbox("search", $in{'search'}, 30)." ".
				   &ui_submit($text{'index_searchok'})." ".
				   &ui_submit($text{'index_clear'}, 'clear'));

print &ui_form_start("index.cgi");
print &ui_hidden("all", $showall ? 1 : 0);
print &ui_hidden("mode", $in{'mode'});
print &ui_grid_table(\@grid, 2),"<p>\n";
print &ui_form_end();

# Work out what packages to show
@current = $in{'all'} ? &list_all_current(1) : &list_current(1);

# Make lookup hashes
%current = map { $_->{'name'}."/".$_->{'system'}, $_ } @current;
%avail = map { $_->{'name'}."/".$_->{'system'}, $_ } @avail;

# Build table
$anysource = 0;
foreach $p (sort { $a->{'name'} cmp $b->{'name'} } (@current, @avail)) {
	next if ($done{$p->{'name'},$p->{'system'}}++);	# May be in both lists

	# Work out the status
	$c = $current{$p->{'name'}."/".$p->{'system'}};
	$a = $avail{$p->{'name'}."/".$p->{'system'}};

	if ($a && $c && &compare_versions($a, $c) > 0) {
		# An update is available
		$msg = "<b><font color=#00aa00>".
		       &text('index_new', $a->{'version'})."</font></b>";
		$need = 1;
		next if ($in{'mode'} eq 'security' && !$a->{'security'});
		next if ($in{'mode'} ne 'both' && $in{'mode'} ne 'updates' &&
			 $in{'mode'} ne 'all' && $in{'mode'} ne 'security');
		}
	elsif ($a && !$c) {
		# Could be installed, but isn't currently
		next if (!&installation_candiate($a));
		$msg = "<font color=#00aa00>$text{'index_caninstall'}</font>";
		$need = 0;
		next if ($in{'mode'} ne 'both' && $in{'mode'} ne 'new' &&
			 $in{'mode'} ne 'all');
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
		next if ($in{'mode'} ne 'all');
		}
	else {
		# We have the latest
		$msg = &text('index_ok', $c->{'version'});
		$need = 0;
		next if ($in{'mode'} ne 'all');
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
		"<a href='view.cgi?all=$in{'all'}&mode=$in{'mode'}&name=".
		  &urlize($p->{'name'})."&system=".
		  &urlize($p->{'system'})."&search=".
		  &urlize($in{'search'})."'>$p->{'name'}</a>",
		$p->{'desc'},
		$msg,
		$source ? ( $source ) : $anysource ? ( "") : ( ),
		]);
	$anysource++ if ($source);
	}

# Show the packages, if any
if (@rows) {
	print &text('index_count', scalar(@rows)),"<br>\n";
	}
print &ui_form_columns_table(
	"update.cgi",
	[ [ "ok", $in{'mode'} eq 'new' ? $text{'index_install'}
				       : $text{'index_update'} ],
	  undef,
          [ "refresh", $text{'index_refresh'} ] ],
	1,
	undef,
	[ [ "mode", $in{'mode'} ],
	  [ "all", $in{'all'} ],
	  [ "search", $in{'search'} ] ],
	[ "", $text{'index_name'}, $text{'index_desc'}, $text{'index_status'},
	  $anysource ? ( $text{'index_source'} ) : ( ), ],
	100,
	\@rows,
	undef,
	0,
	undef,
	$text{'index_none_'.$in{'mode'}},
	1
	);

# Show scheduled report form
print "<hr>\n";
print &ui_form_start("save_sched.cgi");
print &ui_table_start($text{'index_header'}, undef, 2);

$job = &find_cron_job();
if ($job) {
	$sched = $job->{'hours'} eq '*' ? 'h' :
		 $job->{'days'} eq '*' && $job->{'weekdays'} eq '*' ? 'd' :
		 $job->{'days'} eq '*' && $job->{'weekdays'} eq '0' ? 'w' :
								      undef;
	}
else {
	$sched = "d";
	}
print &ui_table_row($text{'index_sched'},
		    &ui_radio("sched_def", $job ? 0 : 1,
			      [ [ 1, $text{'index_sched1'} ],
			        [ 0, $text{'index_sched0'} ] ])."\n".
		    &ui_select("sched", $sched,
			       [ [ 'h', $text{'index_schedh'} ],
			         [ 'd', $text{'index_schedd'} ],
			         [ 'w', $text{'index_schedw'} ] ]));

print &ui_table_row($text{'index_email'},
		    &ui_textbox("email", $config{'sched_email'}, 40));

print &ui_table_row($text{'index_action'},
		    &ui_radio("action", int($config{'sched_action'}),
			       [ [ 0, $text{'index_action0'} ],
			         [ 1, $text{'index_action1'} ],
			         [ 2, $text{'index_action2'} ] ]));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("/", $text{'index'});

