#!/usr/local/bin/perl
# index_cpu.cgi

require './proc-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "cpu", !$no_module_config, 1);

# Show CPU load and type
&index_links("cpu");
if (defined(&get_cpu_info)) {
	@c = &get_cpu_info();
	if (@c) {
		print &ui_table_start(undef, undef, 2);
		print &ui_table_row($text{'index_loadname'},
		    &text('index_loadnums',
			"<tt>$c[0]</tt>", "<tt>$c[1]</tt>", "<tt>$c[2]</tt>"));
		if (@c >= 5) {
			my $cpu = $c[4]."\n";
			if ($c[4] !~ /Hz/) {
				$cpu .= "($c[3] MHz)\n";
				}
			if ($c[7]) {
				$cpu .= ", ".&text($c[7] > 1 ? 'index_cores' :
							'index_core', $c[7]);
				}
			print &ui_table_row($text{'index_cpuname'}, $cpu);
			}
		print &ui_table_end(),"<p>\n";
		}
	}

print &ui_columns_start([ $text{'pid'}, $text{'owner'},
			  $text{'cpu'}, $text{'command'} ], 100);
@procs = sort { $b->{'cpu'} <=> $a->{'cpu'} } &list_processes();
@procs = grep { &can_view_process($_) } @procs;
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

