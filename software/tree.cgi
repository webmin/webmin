#!/usr/local/bin/perl
# tree.cgi
# Display the package tree

require './software-lib.pl';
&ui_print_header(undef, $text{'index_tree'}, "");

$spacer = "&nbsp;"x3;

# work out the package hierarchy..
$n = &list_packages();
for($i=0; $i<$n; $i++) {
	push(@pack, $packages{$i,'name'});
	push(@vers, $packages{$i,'version'});
	push(@svers, $packages{$i,'shortversion'} ||
		     $packages{$i,'version'});
	push(@class, $packages{$i,'class'});
	push(@desc, $packages{$i,'desc'});
	}
@order = sort { lc($pack[$a]) cmp lc($pack[$b]) } (0 .. $n-1);
$heir{""} = "";
foreach $c (sort { $a cmp $b } &unique(@class)) {
	if (!$c) { next; }
	@w = split(/\//, $c);
	$p = join('/', @w[0..$#w-1]);		# parent class
	if (!defined($heir{$p})) {
		$pp = join('/', @w[0..$#w-2]);	# grandparent class
		$heir{$pp} .= "$p\0";
		$ppp = join('/', @w[0..$#w-3]);	# great-grandparent class
		if ($ppp || 1) {
			$heir{$ppp} .= "$pp\0";
			}
		}
	$heir{$p} .= "$c\0";
	$hasclasses++;
	}

# get the current open list
%heiropen = map { $_, 1 } &get_heiropen();
$heiropen{""} = 1;

# traverse the hierarchy
if ($hasclasses) {
	print &ui_link("closeall.cgi", $text{'index_close'});
    print "\n";
	print &ui_link("openall.cgi", $text{'index_open'});
    print "<p>\n";
	}
print "<table width=100%>\n";
&traverse("", 0);
print "</table>\n";
if ($hasclasses) {
	print &ui_link("closeall.cgi", $text{'index_close'});
    print "\n";
	print &ui_link("openall.cgi", $text{'index_open'});
    print "<p>\n";
	}

&ui_print_footer("", $text{'index_return'});

sub traverse
{
local($s, $act, $i);

# Show the icon and class name
print "<tr> <td>", $spacer x $_[1];
if ($_[0]) {
	print "<a name=\"$_[0]\"></a>\n";
	$act = $heiropen{$_[0]} ? "close" : "open";
    my $link = "$act.cgi?what=".&urlize($_[0]);
	$_[0] =~ /([^\/]+)$/;
	print &ui_link($link, "<img border=0 src='images/$act.gif'>");
    print "&nbsp; $1</td>\n";
	}
else {
	print "<img src=images/close.gif> <i>$text{'index_all'}</i></td>\n";
	}

print "<td><br></td> </tr>\n";
if ($heiropen{$_[0]}) {
	# print packages followed by sub-folders
	foreach $i (@order) {
		if ($class[$i] eq $_[0]) {
			print "<tr> <td nowrap>", $spacer x ($_[1]+1);
			print "<img border=0 src=images/pack.gif>&nbsp;\n";
			print &ui_link("edit_pack.cgi?package=".
			      &urlize($pack[$i])."&version=".
			      &urlize($vers[$i]), &html_escape($pack[$i].
			      ($svers[$i] ? " $svers[$i]" : "")) )."</td>\n";
			print "<td>",&html_escape($desc[$i]),"</td>\n";
			print "</tr>\n";
			}
		}
	foreach $s (&unique(split(/\0+/, $heir{$_[0]}))) {
		&traverse($s, $_[1]+1);
		}
	}
}

