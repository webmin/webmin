#!/usr/local/bin/perl
# Show the disk usage tree

require './disk-usage-lib.pl';
@dirs = split(/\t+/, $config{'dirs'});
$fors = &text(@dirs > 1 ? 'index_fors' : 'index_for',
	      join(" ", map { "<tt>$_</tt>" } @dirs));
&ui_print_header($fors, $module_info{'desc'}, "", undef, 1, 1);

$tree = &get_usage_tree();
if ($tree) {
	# Show it
	%open = map { $_, 1 } &get_heiropen();
	$open{"/"} = 1;
	print "<table width=100%>\n";
	print "<tr>\n";
	print "<td width=10%><b>$text{'index_total'}</b></td>\n";
	print "<td width=10%><b>$text{'index_files'}</b></td>\n";
	print "<td width=80%><b>$text{'index_dir'}</b></td>\n";
	print "</tr>\n";
	&traverse($tree, 0);
	print "</table>\n";
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}

print "<hr>\n";
print &ui_buttons_start();
print &ui_buttons_row("edit_sched.cgi",
		      $text{'index_sched'}, $text{'index_scheddesc'});
print &ui_buttons_row("run.cgi",
		      $text{'index_run'}, $text{'index_rundesc'});
print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

sub traverse
{
local ($node, $indent) = @_;
return if ($node->{'total'} < $config{'min'});
print "<tr>\n";
print "<td>",&nice_size($node->{'total'}, $config{'units'}),"</td>\n";
print "<td>",&nice_size($node->{'files'}, $config{'units'}),"</td>\n";
print "<td>", "&nbsp;" x ($indent*3);
if ($node->{'dir'} ne "/") {
	print "<a name=\"$node->{'dir'}\">\n";
	$act = $open{$node->{'dir'}} ? "close" : "open";
	print "<a href=\"$act.cgi?what=",&urlize($node->{'dir'}),"\">";
	print "<img border=0 src=images/$act.gif></a>\n";
	}
else {
	print "<img src=images/close.gif>\n";
	}
print "<tt>$node->{'dir'}</tt></td>\n";
print "</tr>\n";
if ($open{$node->{'dir'}}) {
	# Do sub-directories too
	foreach my $subdir (sort { $b->{'total'} <=> $a->{'total'} }
				 @{$node->{'subs'}}) {
		&traverse($subdir, $indent+1);
		}
	}
}

