#!/usr/local/bin/perl
# index_search.cgi
# Allows searching for processes by user or command

require './proc-lib.pl';
&ReadParse();
$in{'mode'} = 1 if ($in{'mode'} eq '');
$deffield = ("user", "match", "cpu", "sfs", "files", "port", "sip")
	    [$in{'mode'}];
&ui_print_header(undef, $text{'index_title'}, "", "search",
		 !$no_module_config, 1, 0, undef, undef,
		 "onLoad='document.forms[0].$deffield.focus()'");
&index_links("search");

# Javascript to select radio (scoped to the triggering element's form)
print <<EOF;
<script>
function select_mode(\$this, m)
{
  var f = \$this.form;
  if (!f || !f.mode) return;

  // handle one or many radios named "mode"
  var modes = (f.mode.length != null) ? f.mode : [f.mode];

  for (var i = 0; i < modes.length; i++) {
    modes[i].checked = (modes[i].value == m);
  }
}
</script>
EOF

# display search form
print &ui_form_start("index_search.cgi");
print &ui_table_start(undef, undef, 4);

# By user
print &ui_table_row(" ",
	&ui_oneradio("mode", 0, &hlink($text{'search_user'}, "suser"),
		     $in{'mode'} == 0)."&nbsp;&nbsp;".
	&ui_user_textbox("user", $in{'user'}, 0, 0, &mode_selector(0)), 2);

# By process name
print &ui_table_row(" ",
	&ui_oneradio("mode", 1, &hlink($text{'search_match'},"smatch"),
		     $in{'mode'} == 1)."&nbsp;&nbsp;".
	&ui_textbox("match", $in{'match'}, 30, 0, undef, &mode_selector(1)), 2);

if ($has_lsof_command) {
	# TCP port
	print &ui_table_row(" ",
		&ui_oneradio("mode", 5, &hlink($text{'search_port'}, "ssocket"),
			     $in{'mode'} == 5)."&nbsp;&nbsp;".
		&ui_textbox("port", $in{'port'}, 6, 0, undef,
			    &mode_selector(5))."&nbsp;".
		$text{'search_protocol'}."&nbsp;".
		&ui_select("protocol", $in{'protocol'},
			   [ [ 'tcp', 'TCP' ], [ 'udp', 'UDP' ] ], 1, 0, 0,
			   0, &mode_selector(5, "onChange")), 2);

	# Using IP address
	print &ui_table_row(" ",
		&ui_oneradio("mode", 6, &hlink($text{'search_ip'}, "sip"),
			     $in{'mode'} == 6)."&nbsp;&nbsp;".
		&ui_textbox("ip", $in{'ip'}, 20, 0, undef,
			    &mode_selector(6)), 2);
	}

# By CPU used
print &ui_table_row(" ",
	&ui_oneradio("mode", 2, &hlink($text{'search_cpupc2'}, "scpu"),
		     $in{'mode'} == 2)."&nbsp;&nbsp;".
	&ui_textbox("cpu", $in{'cpu'}, 4, 0, undef,
		    &mode_selector(2))."&nbsp;%", 2);

if ($has_fuser_command) {
	# Using filesystem
	if (&foreign_check("mount")) {
		&foreign_require("mount", "mount-lib.pl");
		@opts = ( );
		foreach $fs (&foreign_call("mount", "list_mounted")) {
			next if ($fs->[2] eq "swap");
			push(@opts, $fs->[0]);
			}
		$fschooser = &ui_select("fs", $in{'fs'}, \@opts, 1, 0, 0, 0,
					&mode_selector(3, "onChange"));
		}
	else {
		$fschooser = &ui_textbox("fs", $in{'fs'}, 30, 0, undef,
					 &mode_selector(3));
		}
	print &ui_table_row(" ",
		&ui_oneradio("mode", 3, &hlink($text{'search_fs'}, "sfs"),
			     $in{'mode'} == 3)."&nbsp;&nbsp;".$fschooser, 2);

	# Using file
	print &ui_table_row(" ",
		&ui_oneradio("mode", 4, &hlink($text{'search_files'}, "sfiles"),
			     $in{'mode'} == 4)."&nbsp;&nbsp;".
		&ui_textbox("files", $in{'files'}, 50, 0, undef,
			    &mode_selector(4))." ".
		&file_chooser_button("files", 0), 2);
	}

# Exclude own processes
print &ui_table_hr();
print &ui_table_row(" ",
	&ui_checkbox("ignore", 1, &hlink($text{'search_ignore'}, "signore"),
	$in{'ignore'} || !defined($in{'mode'})), 2);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'search_submit'} ] ]);

if (%in) {
	# search for processes
	@procs = &list_processes();
	@procs = grep { &can_view_process($_) } @procs;
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
				push(@cols, &ui_link("edit_proc.cgi?".$p, $p) );
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
		print &ui_columns_end(),"\n";
		}
	else {
		print "<hr>".&ui_alert_box($text{'search_none'}, "info",
				    undef, undef, "") if ($in{'match'} ne '');
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
		print "<input type=submit value=\"$text{'proc_kill'}\">\n";
		print "<input type=hidden name=args value=\"$in\">\n";
		printf "<input type=hidden name=pidlist value=\"%s\">\n",
			join(" ", @pidlist);
		print "<select name=signal>\n";
		foreach $s (&supported_signals()) {
			printf "<option value=\"$s\" %s>$s</option>\n",
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

sub mode_selector
{
local ($m, $action) = @_;
$action ||= "onFocus";
return "$action='select_mode(this, $m)'";
}

