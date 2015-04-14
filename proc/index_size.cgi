#!/usr/local/bin/perl
# index_cpu.cgi

require './proc-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "size", !$no_module_config, 1);

&index_links("size");
if (defined(&get_memory_info)) {
	@m = &get_memory_info();
	if (@m) {
		$msg = $m[4] ? 'index_mem3' : 'index_mem2';
		print &text($msg, &nice_size($m[0]*1024),
			    &nice_size($m[1]*1024),
			    &nice_size($m[4]*1024)),"\n";
		if ($m[5]) {
			print "&nbsp;&nbsp;",
				&text('index_burst', &nice_size($m[5]*1024));
			}
		print "&nbsp;&nbsp;",
			&text('index_swap2', &nice_size($m[2]*1024),
					     &nice_size($m[3]*1024)),"<p>\n";
		}
	}
print &ui_columns_start([
	$text{'pid'},
	$text{'owner'},
	$text{'size'},
	$text{'command'}
	], 100);

@procs = sort { $b->{'size'} <=> $a->{'size'} } &list_processes();
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
	push(@cols, $pr->{'bytes'} ? &nice_size($pr->{'bytes'}) : $pr->{'size'});
	push(@cols, &html_escape(&cut_string($pr->{'args'})));
	print &ui_columns_row(\@cols);
	}
print &ui_columns_end();

&ui_print_footer("/", $text{'index'});

