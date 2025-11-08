#!/usr/local/bin/perl
# index.cgi
# Display a list of all cron jobs, with the username and command for each one

require './cron-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
$max_jobs = $userconfig{'max_jobs'} || $config{'max_jobs'};

# Make sure cron is installed (very likely!)
$err = &check_cron_config();
if ($err) {
	print $err,"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Work out which users can be viewed
map { $ucan{$_}++ } split(/\s+/, $access{'users'});
@jobs = &list_cron_jobs();
@ulist = &unique(map { $_->{'user'} } @jobs);
if ($access{'mode'} == 1) {
	@ulist = grep { $ucan{$_} } @ulist;
	}
elsif ($access{'mode'} == 2) {
	@ulist = grep { !$ucan{$_} } @ulist;
	}
elsif ($access{'mode'} == 3) {
	@ulist = ( $remote_user );
	}
elsif ($access{'mode'} == 4) {
	@ulist = grep { local @u = getpwnam($_);
			(!$access{'uidmin'} || $u[2] >= $access{'uidmin'}) &&
			(!$access{'uidmax'} || $u[2] <= $access{'uidmax'}) }
		      @ulist;
	}
elsif ($access{'mode'} == 5) {
	@ulist = grep { local @u = getpwnam($_);
			$u[3] == $access{'users'} } @ulist;
	}

if ($config{'show_run'}) {
	&foreign_require("proc", "proc-lib.pl");
	@procs = &proc::list_processes();
	}

# Work out creation links
@crlinks = ( );
if ($access{'create'}) {
	push(@crlinks, &ui_link("edit_cron.cgi?new=1&search=".
				  &urlize($in{'search'}),
			        $text{'index_create'}) );
	push(@crlinks, &ui_link("edit_env.cgi?new=1&search=".
				  &urlize($in{'search'}),
				$text{'index_ecreate'}) ) if ($env_support);
	}
if ($config{cron_allow_file} && $config{cron_deny_file} && $access{'allow'}) {
	push(@crlinks, &ui_link("edit_allow.cgi", $text{'index_allow'}) );
	}
my @files = &list_cron_files();
if ($access{'mode'} == 0 && @files) {
	push(@crlinks, &ui_link("edit_manual.cgi", $text{'index_manual'}));
	}

# Build a list of cron job rows to show
$single_user = !&supports_users() || (@ulist == 1 && $access{'mode'});
@links = ( &select_all_link("d", 1),
	   &select_invert_link("d", 1),
	   @crlinks );
@rows = ( );
foreach $u (@ulist) {
	if (!$config{'single_file'}) {
		# Get the Unix user's real name
		if ((@uinfo = getpwnam($u)) && $uinfo[5] =~ /\S/) {
			$uname = "$u ($uinfo[5])";
			}
		else { $uname = $u; }
		}

	@jlist = grep { $_->{'user'} eq $u } @jobs;
	@plist = ();
	for($i=0; $i<@jlist; $i++) {
		local $rpd = &is_run_parts($jlist[$i]->{'command'});
		local @exp = $rpd ? &expand_run_parts($rpd) : ();
		if (!$rpd || @exp) {
			push(@plist, [ $jlist[$i], \@exp ]);
			}
		}
	for($i=0; $i<@plist; $i++) {
		local $job = $plist[$i]->[0];
		&convert_range($job);
		&convert_comment($job);
		local @exp = @{$plist[$i]->[1]};
		local $idx = $job->{'index'};
		local @cols;
		push(@cols, $idx);
		$useridx = 0;
		$cmdidx = 0;
		if (!$single_user) {
			$useridx = scalar(@cols);
			push(@cols, &html_escape($uname));
			}
		push(@cols, $job->{'active'} ? $text{'yes'} :
				"<font color=#ff0000>$text{'no'}</font>");
		$donelink = 0;
		if ($job->{'name'}) {
			# An environment variable - show the name only
			$cmdidx = scalar(@cols);
			push(@cols, &ui_link("edit_env.cgi?idx=".$idx,
				   "<i>$text{'index_env'}</i> ".
				   "<tt>@{[&html_escape($job->{'name'})]} = @{[&html_escape($job->{'value'})]}</tt>") );
			$donelink = 1;
			}
		elsif (@exp && $access{'command'}) {
			# A multi-part command
			$cmdidx = scalar(@cols);
			@exp = map { &html_escape($_) } @exp;
			push(@cols, &ui_link("edit_cron.cgi?idx=".$idx.
				      "&search=".&urlize($in{'search'}),
				    join("<br>",@exp)) );
			$donelink = 1;
			}
		elsif ($access{'command'}) {
			# A simple command
			$cmdidx = scalar(@cols);
			local $max = $config{'max_len'} || 10000;
			local ($cmd, $input) =
				&extract_input($job->{'command'});
			$cmd =~ s/\\%/%/g;
			$input =~ s/\\%/%/g;
			$cmd = length($cmd) > $max ?
			  &html_escape(substr($cmd, 0, $max))." ..." :
			  $cmd !~ /\S/ ? "BLANK" : &html_escape($cmd);
			push(@cols, &ui_link("edit_cron.cgi?idx=".$idx.
					      "&search=".&urlize($in{'search'}),
					     $cmd) );
			$donelink = 1;
			}

		# Show cron time
		if (!$access{'command'} || $config{'show_time'} || $userconfig{'show_time'}) {
			$when = &when_text($job, 1);
			if ($job->{'name'}) {
				push(@cols, "");
				}
			elsif ($donelink) {
				push(@cols, $when);
				}
			else {
				push(@cols, &ui_link(
					"edit_cron.cgi?idx=".$idx.
					  "&search=".&urlize($in{'search'}),
					$when) );
				}
			}

		# Show comment
		if ($config{'show_comment'} || $userconfig{'show_comment'}) {
			push(@cols, &html_escape($job->{'comment'}));
			}

		# Show next run time
		if ($config{'show_next'} || $userconfig{'show_next'}) {
			my $n = &next_run($job);
			push(@cols, $n ? &make_date($n)
				       : "<i>$text{'index_nunknown'}</i>");
			}

		# Show running indicator
		if ($config{'show_run'}) {
			if ($job->{'name'}) {
				# An environment variable
				push(@cols, "");
				}
			else {
				# Try to find the process
				local $proc = &find_cron_process($job, \@procs);
				$txt = $proc ?
				    "<font color=#00aa00>$text{'yes'}</font>" :
				    $text{'no'};
				if ($config{'show_run'} == 2 &&
				    ($access{'kill'} || !$proc)) {
					$lnk = $proc ? "kill_cron.cgi?idx=$idx" : "exec_cron.cgi?idx=$idx&bg=1";
					push(@cols, &ui_link($lnk, $txt) );
					}
				else {
					push(@cols, $txt);
					}
				}
			}

		# Show mover buttons
		local $prv = $i > 0 ? $plist[$i-1]->[0] : undef;
		local $nxt = $i != $#plist ? $plist[$i+1]->[0] : undef;
		if ($access{'move'}) {
			local $canup = $prv &&
				$prv->{'file'} eq $job->{'file'} &&
				($job->{'type'} == 0 || $job->{'type'} == 3);
			local $candown = $nxt &&
				$nxt->{'file'} eq $job->{'file'} &&
				($job->{'type'} == 0 || $job->{'type'} == 3);
			local $mover = "move.cgi?search=".
				       &urlize($in{'search'})."&idx=$idx";
			push(@cols, &ui_up_down_arrows(
				"$mover&up=1",
				"$mover&down=1",
				$canup, $candown,
			        ));
			push(@cols, &ui_up_down_arrows(
				"$mover&top=1",
				"$mover&bottom=1",
				$canup, $candown,
				"images/top.gif",
				"images/bottom.gif",
			        ));
			}

		# Add search colume
		push(@cols, $job->{'command'}.' '.$job->{'name'}.' '.
			    $job->{'comment'});
		push(@rows, \@cols);
		}
	}

# Limit to search
if ($in{'search'}) {
	@rows = grep { $_->[@$_-1] =~ /\Q$in{'search'}\E/i ||
		       $_->[1] =~ /\Q$in{'search'}\E/i } @rows;
	}

# Show search form
print &ui_form_start("index.cgi");
print "$text{'index_search'} &nbsp;\n";
print &ui_textbox("search", $in{'search'}, 20);
print &ui_submit($text{'ui_searchok'});
print &ui_form_end();

# Check if we are over the display limit
if ($max_jobs && @rows > $max_jobs && !$in{'search'}) {
	print "$text{'index_toomany2'}<p>\n";
	print &ui_links_row(\@crlinks);
	}
elsif (@rows) {
	# Show jobs
	if ($in{'search'}) {
		print &text('index_searchres',
			"<i>".&html_escape($in{'search'})."</i>"),"<p>\n";
		push(@links, &ui_link("index.cgi", $text{'index_reset'}) );
		}
	print &ui_form_start("delete_jobs.cgi", "post");
	print &ui_links_row(\@links);
	@tds = ( "width=5" );
	print &ui_columns_start([
		"",
		$single_user ? ( ) : ( $text{'index_user'} ),
		$text{'index_active'},
		$access{'command'} ? ( $text{'index_command'} ) : ( ),
		!$access{'command'} || $config{'show_time'} ||
		  $userconfig{'show_time'} ? ( $text{'index_when'} ) : ( ),
		$config{'show_comment'} || $userconfig{'show_comment'} ?
		  ( $text{'index_comment'} ) : ( ),
		$config{'show_next'} ? ( $text{'index_next'} ) : ( ),
		$config{'show_run'} ? ( $text{'index_run'} ) : ( ),
		$access{'move'} ? ( $text{'index_move'}, "" ) : ( ),
		], 100, 0, \@tds);
	foreach my $r (@rows) {
		print &ui_checked_columns_row([ @$r[1..(@$r-2)] ],
					      \@tds, "d", $r->[0]);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ],
			     [ "disable", $text{'index_disable'} ],
			     [ "enable", $text{'index_enable'} ] ]);
	}
else {
	# Show message
	if ($in{'search'}) {
		push(@crlinks, &ui_link("index.cgi", $text{'index_reset'}) );
		}
	print $in{'search'} ? &text('index_esearch',
			"<i>".&html_escape($in{'search'})."</i>")."<p>" :
	      $module_info{'usermin'} ? "$text{'index_none3'} <p>\n" :
	      $access{'mode'} ? "$text{'index_none2'} <p>\n"
			      : "$text{'index_none'} <p>\n";
	print &ui_links_row(\@crlinks);
	}

# If there is an init script that runs crond, show status
if (&foreign_available("init")) {
	&foreign_require("init");
	my $init = $config{'init_name'};
	my $atboot;
	if ($access{'stop'} && $init && ($atboot = &init::action_status($init))) {
		print &ui_hr();
		print &ui_buttons_start();

		# Running now?
		my $r = &init::status_action($init);
		if ($r == 1) {
			print &ui_buttons_row("stop.cgi", $text{'index_stop'},
					      $text{'index_stopdesc'});
			}
		elsif ($r == 0) {
			print &ui_buttons_row("start.cgi", $text{'index_start'},
					      $text{'index_startdesc'});
			}

		# Start at boot?
		print &ui_buttons_row("bootup.cgi", $text{'index_boot'},
				      $text{'index_bootdesc'}, undef,
				      &ui_radio("boot", $atboot == 2 ? 1 : 0,
						[ [ 1, $text{'yes'} ],
						  [ 0, $text{'no'} ] ]));

		print &ui_buttons_end();
		}
	}

&ui_print_footer("/", $text{'index'});

