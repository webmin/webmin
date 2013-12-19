#!/usr/local/bin/perl
# index_cpu.cgi

require './proc-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "cpu", !$no_module_config, 1);

# Show CPU load and type
&index_links("cpu");
if (defined(&get_cpu_info)) {
	print "<table>\n";
	@c = &get_cpu_info();
	if (@c) {
		print "<tr> <td><b>$text{'index_loadname'}</b></td>\n";
		print "<td>",&text('index_loadnums',
			"<tt>$c[0]</tt>", "<tt>$c[1]</tt>", "<tt>$c[2]</tt>"),
			"</td> </tr>\n";
		if (@c >= 5) {
			print "<tr> <td><b>$text{'index_cpuname'}</b></td>\n";
			print "<td>$c[4]\n";
			if ($c[4] !~ /Hz/) {
				print "($c[3] MHz)\n";
				}
			if ($c[7]) {
				print ", $c[7] cores\n";
				}
			print "</td> </tr>\n";
			}
		}
	print "</table><br>\n";
	}

print &ui_columns_start([ $text{'pid'}, $text{'owner'},
			  $text{'cpu'}, $text{'command'} ], 100);
@procs = sort { $b->{'cpu'} <=> $a->{'cpu'} } &list_processes();
@procs = grep { &can_view_process($_->{'user'}) } @procs;
foreach $pr (@procs) {
	$p = $pr->{'pid'};
	local @cols;
	if (&can_edit_process($pr->{'user'})) {
		push(@cols, &ui_link("edit_proc.cgi?".$p, $p) );
		}
	else {
		push(@cols, $p);
		}
	push(@cols, $pr->{'user'});
	push(@cols, $pr->{'cpu'});
	push(@cols, &html_escape(cut_string($pr->{'args'})));
	print &ui_columns_row(\@cols);
	}
print &ui_columns_end();

&ui_print_footer("/", $text{'index'});

