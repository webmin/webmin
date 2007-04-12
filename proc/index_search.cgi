#!/usr/local/bin/perl
# index_search.cgi
# Allows searching for processes by user or command

require './proc-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "search", !$no_module_config, 1);
&ReadParse();
&index_links("search");

# display search form
print "<form action=index_search.cgi>\n";
print "<table width=100%><tr><td valign=top>\n";

printf "<input type=radio name=mode value=0 %s>\n",
	$in{mode}==0 ? "checked" : "";
print &hlink("<b>$text{'search_user'}</b>","suser"),"\n";
printf "<input name=user size=8 value=\"%s\"> %s<br>\n",
	$in{mode}==0 ? $in{user} : "",
	&user_chooser_button("user", 0);

printf "<input type=radio name=mode value=1 %s>\n",
	$in{mode}==1 ? "checked" : "";
print &hlink("<b>$text{'search_match'}</b>","smatch"),"\n";
printf "<input name=match size=20 value=\"%s\"><br>\n",
	$in{mode}==1 ? $in{match} : "";

printf "<input type=radio name=mode value=2 %s>\n",
	$in{mode}==2 ? "checked" : "";
$cpu = sprintf "<input name=cpu size=4 value=\"%s\">\n",
		$in{mode}==2 ? $in{cpu} : "";
print &hlink("<b>".&text('search_cpupc', $cpu)."</b>", "scpu"),"<br>\n";

print "</td><td valign=top>\n";

if ($has_fuser_command) {
	printf "<input type=radio name=mode value=3 %s>\n",
		$in{mode}==3 ? "checked" : "";
	print &hlink("<b>$text{'search_fs'}</b>","sfs"),"\n";
	if (&foreign_check("mount")) {
		&foreign_require("mount", "mount-lib.pl");
		print "<select name=fs>\n";
		foreach $fs (&foreign_call("mount", "list_mounted")) {
			next if ($fs->[2] eq "swap");
			printf "<option %s>%s\n",
			     $in{'mode'}==3 && $in{'fs'} eq $fs->[0] ?
			     "selected" : "", $fs->[0];
			}
		print "</select><br>\n";
		}
	else {
		printf "<input name=fs size=15 value='%s'><br>\n",
			$in{'mode'}==3 ? $in{'fs'} : "";
		}

	printf "<input type=radio name=mode value=4 %s>\n",
		$in{mode}==4 ? "checked" : "";
	print &hlink("<b>$text{'search_files'}</b>","sfiles"),"\n";
	printf "<input name=files size=30 value=\"%s\">\n",
		$in{mode}==4 ? $in{'files'} : "";
	print &file_chooser_button("files", 0);
	print "<br>\n";
	}
if ($has_lsof_command) {
	# Show input for file in use
	printf "<input type=radio name=mode value=5 %s>\n",
		$in{mode}==5 ? "checked" : "";
	print &hlink("<b>$text{'search_port'}</b>","ssocket"),"\n";
	printf "<input name=port size=6 value='%s'>\n",
		$in{mode}==5 ? $in{port} : "";

	# Show input for protocol and port
	print &hlink("<b>$text{'search_protocol'}</b>","ssocket"),"\n";
	print "<select name=protocol>\n";
	printf "<option value=tcp %s>TCP\n",
		$in{protocol} eq 'tcp' ? 'selected' : '';
	printf "<option value=udp %s>UDP\n",
		$in{protocol} eq 'udp' ? 'selected' : '';
	print "</select>\n";
	print "<br>\n";

	# Show input for IP address
	printf "<input type=radio name=mode value=6 %s>\n",
		$in{mode}==6 ? "checked" : "";
	print &hlink("<b>$text{'search_ip'}</b>","sip"),"\n";
	printf "<input name=ip size=15 value='%s'>\n",
		$in{mode}==6 ? $in{ip} : "";
	}

print "</td></tr></table>\n";
print "<input type=submit value=\"$text{'search_submit'}\">\n";
print "&nbsp;" x 5;
printf "<input type=checkbox name=ignore value=1 %s> %s<br>\n",
	$in{'ignore'} || !defined($in{'mode'}) ? 'checked' : '',
	&hlink("<b>$text{'search_ignore'}</b>","signore");
print "</form>\n";

if (%in) {
	# search for processes
	@procs = &list_processes();
	@procs = grep { &can_view_process($_->{'user'}) } @procs;
	if ($in{mode} == 0) {
		# search by user
		@dis = grep { $_->{'user'} eq $in{'user'} } @procs;
		}
	elsif ($in{mode} == 1) {
		# search by regexp
		@dis = grep { $_->{'args'} =~ /\Q$in{match}\E/i } @procs;
		}
	elsif ($in{mode} == 2) {
		# search by cpu
		@dis = grep { $_->{'cpu'} > $in{'cpu'} } @procs;
		@dis = sort { $b->{'cpu'} <=> $a->{'cpu'} } @dis;
		}
	elsif ($in{mode} == 3 && $has_fuser_command) {
		# search by filesystem
		foreach $p (&find_mount_processes($in{'fs'})) { $using{$p}++; }
		@dis = grep { defined($using{$_->{'pid'}}) } @procs;
		}
	elsif ($in{mode} == 4 && $has_fuser_command) {
		# search by files
		foreach $p (&find_file_processes(split(/\s+/, $in{'files'})))
			{ $using{$p}++; }
		@dis = grep { defined($using{$_->{'pid'}}) } @procs;
		}
	elsif ($in{mode} == 5 && $has_lsof_command) {
		foreach $p (&find_socket_processes($in{'protocol'},$in{'port'}))
			{ $using{$p}++; }
		@dis = grep { defined($using{$_->{'pid'}}) } @procs;
		}
	elsif ($in{mode} == 6 && $has_lsof_command) {
		foreach $p (&find_ip_processes($in{'ip'}))
			{ $using{$p}++; }
		@dis = grep { defined($using{$_->{'pid'}}) } @procs;
		}

	if ($in{'ignore'}) {
		# Ignore this process and any children
		@dis = grep { $_->{'pid'} != $$ && $_->{'ppid'} != $$ } @dis;
		}

	# display matches
	if (@dis) {
		print &ui_columns_start([
			  $text{'pid'},
			  $text{'owner'},
			  $text{'cpu'},
			  $info_arg_map{'_stime'} ? ( $text{'stime'} ) : ( ),
			  $text{'command'} ], 100);
		foreach $d (@dis) {
			$p = $d->{'pid'};
			push(@pidlist, $p);
			local @cols;
			if (&can_edit_process($d->{'user'})) {
				push(@cols, "<a href=\"edit_proc.cgi?$p\">$p</a>");
				}
			else {
				push(@cols, $p);
				}
			push(@cols, $d->{user});
			push(@cols, $d->{cpu});
			if ($info_arg_map{'_stime'}) {
				push(@cols, $d->{'_stime'});
				}
			push(@cols, &html_escape(cut_string($d->{args})));
			print &ui_columns_row(\@cols);
			}
		print &ui_columns_end(),"<p>\n";
		}
	else {
		print "<p><b>$text{'search_none'}</b><p>\n";
		}

	if (@pidlist && $access{'simple'} && $access{'edit'}) {
		# display form for mass killing with selected signals
		print "<form action=kill_proc_list.cgi>\n";
		print "<input type=hidden name=args value=\"$in\">\n";
		printf "<input type=hidden name=pidlist value=\"%s\">\n",
			join(" ", @pidlist);
		print "<input type=hidden name=pid value=$pinfo{pid}>\n";
		foreach $s ('KILL', 'TERM', 'HUP', 'STOP', 'CONT') {
			printf "<input type=submit value=\"%s\" name=%s>\n",
				$text{"kill_".lc($s)}, $s;
			}
		print "</form>\n";
		}
	elsif (@pidlist && $access{'edit'}) {
		# display form for mass killing with any signal
		print "<form action=kill_proc_list.cgi>\n";
		print "<input type=submit value=\"$text{'search_kill'}\">\n";
		print "<input type=hidden name=args value=\"$in\">\n";
		printf "<input type=hidden name=pidlist value=\"%s\">\n",
			join(" ", @pidlist);
		print "<select name=signal>\n";
		foreach $s (&supported_signals()) {
			printf "<option value=\"$s\" %s> $s\n",
				$s eq "HUP" ? "selected" : "";
			}
		print "</select>\n";

		print "&nbsp;" x 2;
		print "<input type=submit name=TERM ",
		      "value='$text{'search_sigterm'}'>\n";
		print "&nbsp;" x 2;
		print "<input type=submit name=KILL ",
		      "value='$text{'search_sigkill'}'>\n";
		print "</form>\n";
		}
	}

&ui_print_footer("/", $text{'index'});

