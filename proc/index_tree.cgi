#!/usr/local/bin/perl
# index.cgi
# Display a list of all existing processes

require './proc-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "tree", !$no_module_config, 1);

&index_links("tree");
print &ui_columns_start([ $text{'pid'},
			  $text{'owner'},
			  $info_arg_map{'_stime'} ? ( $text{'stime'} ) : ( ),
			  $text{'command'} ], 100);
@procs = sort { $a->{'pid'} <=> $b->{'pid'} } &list_processes();
foreach $pr (@procs) {
	$p = $pr->{'pid'}; $pp = $pr->{'ppid'};
	$argmap{$p} = $pr->{'args'};
	$usermap{$p} = $pr->{'user'};
	$stimemap{$p} = $pr->{'_stime'};
	push(@{$children{$pp}}, $p);
	$inlist{$pr->{'pid'}}++;
	}
foreach $pr (@procs) {
	push(@roots, $pr->{'pid'}) if (!$inlist{$pr->{'ppid'}} ||
				       $pr->{'pid'} == $pr->{'ppid'} ||
				       $pr->{'pid'} == 0);
	}
foreach $r (&unique(@roots)) {
	&walk_procs("", $r);
	}
print &ui_columns_end();

&ui_print_footer("/", $text{'index'});


# walk_procs(indent, pid)
sub walk_procs
{
next if ($done_proc{$_[1]}++);
local(@ch, $_, $args);
if (&can_view_process($usermap{$_[1]})) {
	local @cols;
	if (&can_edit_process($usermap{$_[1]})) {
		push(@cols, $_[0].&ui_link("edit_proc.cgi?".$_[1], $_[1]) );
		}
	else {
		push(@cols, "$_[0]$_[1]");
		}
	push(@cols, $usermap{$_[1]});
	if ($info_arg_map{'_stime'}) {
		push(@cols, $stimemap{$_[1]});
		}
	$args = &cut_string($argmap{$_[1]});
	push(@cols, &html_escape($args));
	print &ui_columns_row(\@cols);
	}
foreach (@{$children{$_[1]}}) {
	&walk_procs("$_[0]&nbsp;&nbsp;&nbsp;", $_);
	}
}

