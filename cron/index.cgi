#!/usr/local/bin/perl
# index.cgi
# Display a list of all cron jobs, with the username and command for each one

require './cron-lib.pl';

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

# Make sure cron is installed (very likely!)
if ($config{'single_file'} && !-r $config{'single_file'}) {
	$err = &text('index_esingle', "<tt>$config{'single_file'}</tt>");
	}
if ($config{'cron_get_command'} =~ /^(\S+)/ && !&has_command("$1")) {
	$err = &text('index_ecmd', "<tt>$1</tt>");
	}
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
	push(@crlinks,
	     "<a href=\"edit_cron.cgi?new=1\">$text{'index_create'}</a>");
	push(@crlinks,
	     "<a href=\"edit_env.cgi?new=1\">$text{'index_ecreate'}</a>")
		if ($env_support);
	}
if ($config{cron_allow_file} && $config{cron_deny_file} && $access{'allow'}) {
	push(@crlinks, "<a href=edit_allow.cgi>$text{'index_allow'}</a>");
	}

# Show cron jobs by user
$single_file = !&supports_users() || !(@ulist != 1 || $access{'mode'} != 3);
@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   @crlinks );
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
		if (!$donehead) {
			print &ui_form_start("delete_jobs.cgi", "post");
			print &ui_links_row(\@links);
			print "<table border width=100%> <tr $tb>\n";
			if (!$single_file) {
				print "<td><b>$text{'index_user'}</b></td>\n";
				}
			print "<td width=5><br></td>\n";
			print "<td><b>$text{'index_active'}</b></td>\n";
			if ($access{'command'}) {
				print "<td><b>$text{'index_command'}</b></td>\n";
				}
			if (!$access{'command'} || $config{'show_time'} || $userconfig{'show_time'}) {
				print "<td><b>$text{'index_when'}</b></td>\n";
				}
			if ($config{'show_comment'} || $userconfig{'show_comment'}) {
				print "<td><b>$text{'index_comment'}</b></td>\n";
				}
			if ($config{'show_run'}) {
				print "<td width=5%><b>$text{'index_run'}</b></td>\n";
				}
			if ($access{'move'}) {
				print "<td width=5%><b>$text{'index_move'}</b></td>\n";
				}
			print "</tr>\n";
			$donehead = 1;
			}
		print "<tr $cb>\n";
		if ($i == 0 && !$single_file) {
			printf "<td valign=top rowspan=%d>", scalar(@plist);
			print &html_escape($uname);
			print "</td>\n";
			}
		print "<td>",&ui_checkbox("d", $idx),"</td>\n";
		printf "<td valign=top>%s</td>\n",
			$job->{'active'} ? $text{'yes'}
				: "<font color=#ff0000>$text{'no'}</font>";
		$donelink = 0;
		if ($job->{'name'}) {
			# An environment variable - show the name only
			print "<td><a href=\"edit_env.cgi?idx=$idx\">",
			      "<i>$text{'index_env'}</i> ",
			     "<tt>$job->{'name'} = $job->{'value'}</tt></td>\n";
			$donelink = 1;
			}
		elsif (@exp && $access{'command'}) {
			# A multi-part command
			@exp = map { &html_escape($_) } @exp;
			print "<td><a href=\"edit_cron.cgi?idx=$idx\">",
			      join("<br>",@exp),"</a></td>\n";
			$donelink = 1;
			}
		elsif ($access{'command'}) {
			# A simple command
			local $max = $config{'max_len'} || 10000;
			local ($cmd, $input) =
				&extract_input($job->{'command'});
			$cmd = 
			  length($cmd) > $max ?
				&html_escape(substr($cmd, 0, $max))." ..." :
			  $cmd !~ /\S/ ? "BLANK" : &html_escape($cmd);
			print "<td><a href=\"edit_cron.cgi?idx=$idx\">$cmd</a></td>\n";
			$donelink = 1;
			}

		# Show cron time
		if (!$access{'command'} || $config{'show_time'} || $userconfig{'show_time'}) {
			$when = &when_text($job, 1);
			if ($job->{'name'}) {
				print "<td><br></td>\n";
				}
			elsif ($donelink) {
				print "<td>$when</td>\n";
				}
			else {
				print "<td><a href='edit_cron.cgi?idx=$idx'>$when</a></td>\n";
				}
			}

		# Show comment
		if ($config{'show_comment'} || $userconfig{'show_comment'}) {
			print "<td>",($job->{'comment'} || "<br>"),"</td>\n";
			}

		# Show running indicator
		if ($config{'show_run'}) {
			print "<td>";
			if ($job->{'name'}) {
				# An environment variable
				print "<br>\n";
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
					print "<a href='$lnk'>$txt</a>";
					}
				else {
					print $txt;
					}
				}
			print "</td>\n";
			}

		# Show mover buttons
		local $prv = $i > 0 ? $plist[$i-1]->[0] : undef;
		local $nxt = $i != $#plist ? $plist[$i+1]->[0] : undef;
		if ($access{'move'}) {
			print "<td width=5%>";
			if ($prv && $prv->{'file'} eq $job->{'file'} &&
			    ($job->{'type'} == 0 || $job->{'type'} == 3)) {
				print "<a href='move.cgi?idx=$idx&up=1'>",
				      "<img src=images/up.gif border=0></a>";
				}
			else {
				print "<img src=images/gap.gif>";
				}
			if ($nxt && $nxt->{'file'} eq $job->{'file'} &&
			    ($job->{'type'} == 0 || $job->{'type'} == 3)) {
				print "<a href='move.cgi?idx=$idx&down=1'>",
				      "<img src=images/down.gif border=0></a>";
				}
			else {
				print "<img src=images/gap.gif>";
				}
			print "</td>\n";
			}
		print "</tr>\n";
		}
	}
if ($donehead) {
	print "</table>\n";
	print &ui_links_row(\@links);
	}
else {
	print $module_info{'usermin'} ? "<b>$text{'index_none3'}</b> <p>\n" :
	      $access{'mode'} ? "<b>$text{'index_none2'}</b> <p>\n"
			      : "<b>$text{'index_none'}</b> <p>\n";
	print &ui_links_row(\@crlinks);
	}
if ($donehead) {
	print &ui_form_end([ [ "delete", $text{'index_delete'} ],
			     [ "disable", $text{'index_disable'} ],
			     [ "enable", $text{'index_enable'} ] ]);
	}

&ui_print_footer("/", $text{'index'});

