#!/usr/local/bin/perl
# index_user.cgi

require './proc-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "user", !$no_module_config, 1);

&index_links("user");
@procs = sort { $b->{'cpu'} <=> $a->{'cpu'} } &list_processes();
@procs = grep { &can_view_process($_) } @procs;
@users = &unique(map { $_->{'user'} } @procs);
foreach $u (@users) {
	if (&supports_users()) {
		@uinfo = getpwnam($u);
		$uinfo[6] =~ s/,.*$//;
		}
	print &ui_subheading("$u ".($uinfo[6] ? "($uinfo[6])" : "")),"\n";
	print &ui_columns_start([
			  $text{'pid'},
			  $text{'cpu'},
			  $info_arg_map{'_stime'} ? ( $text{'stime'} ) : ( ),
			  $text{'command'} ], 100);
	foreach $pr (grep { $_->{'user'} eq $u } @procs) {
		$p = $pr->{'pid'};
		local @cols;
		if (&can_edit_process($pr->{'user'})) {
			push(@cols, &ui_link("edit_proc.cgi?".$p, $p) );
			}
		else {
			push(@cols, $p);
			}
		push(@cols, $pr->{'cpu'});
		if ($info_arg_map{'_stime'}) {
			push(@cols, &format_stime($pr));
			}
		push(@cols, &html_escape(&cut_string($pr->{'args'})));
		print &ui_columns_row(\@cols);
		}
	print &ui_columns_end();
	}

&ui_print_footer("/", $text{'index'});

