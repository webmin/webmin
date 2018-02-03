#!/usr/local/bin/perl
# ikpg-tree.cgi
# Display the IPKG package tree

require './software-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'index_tree'}, "");

# read package list
$n = &list_packages("ALL");

# filter array
if ($in{'filter'}) {
    for($i=0; $i<$n; $i++) {
	    if (index($packages{$i, 'name'}, $in{'filter'}) == -1) {
			$filter++;
            $packages{$i, 'name'}='';
            $packages{$i, 'version'}='';
            $packages{$i, 'desc'}='';
            $packages{$i, 'class'}='';
        }
    }
}

# prcoess openall / closeall actions
if ( $in{'mode'} eq "closeall" ) {
  &save_heiropen([ ]);
}

if ( $in{'mode'} eq "openall" || $in{'filter'} ) {
  for($i=0; $i<$n; $i++) {
	@w = split(/\//, $packages{$i,'class'});
	for($j=0; $j<@w; $j++) {
		push(@list, join('/', @w[0..$j]));
		}
	}
  local @list = &unique(@list);
  &save_heiropen(\@list);
}

# work out the package hierarchy..
$spacer = "&nbsp;"x3;
for($i=0; $i<$n; $i++) {
	push(@pack, $packages{$i,'name'});
	push(@vers, $packages{$i,'version'});
	push(@class, $packages{$i,'class'});
	push(@desc, $packages{$i,'desc'});
	push(@inst, $packages{$i,'install'});
	}
@order = sort { lc($pack[$a]) cmp lc($pack[$b]) } (0 .. $n-1);
$heir{""} = "";
foreach $c (sort { $a cmp $b } &unique(@class)) {
	# note: this is optimize for having only one level!
	if (!$c) { next; }
	@w = $c;
	$p = join('/', @w[0..$#w-1]);		# parent class
	$heir{$p} .= "$c\0";
	}

# get the current open list
%heiropen = map { $_, 1 } &get_heiropen();
$heiropen{""} = 1;

# traverse the hierarchy
print &ui_form_start("ipkg-tree.cgi");
print &ui_submit($text{'IPKG_filter'});
print &ui_textbox("filter", $in{'filter'}, 50);
print &ui_form_end(),"<p>\n";

print &ui_link("ipkg-tree.cgi?mode=closeall", $text{'index_close'});
print &ui_link("ipkg-tree.cgi?mode=openall", $text{'index_open'});
if ($in{'filter'}) {
	print &ui_link("ipkg-tree.cgi", $text{'IPKG_filterclear'});
	print "&nbsp;&nbsp;", &text('IPKG_filtered',$n-$filter,$n+1), "\n";
}
print "<table width=\"95%\">\n";
&traverse("", 0);
print "</table>\n";
print &ui_form_start("ipkg-tree.cgi");
print &ui_submit($text{'IPKG_filter'});
print &ui_textbox("filter", $in{'filter'}, 50);
print &ui_form_end(),"<p>\n";

print &ui_link("ipkg-tree.cgi?mode=closeall", $text{'index_close'});
print &ui_link("ipkg-tree.cgi?mode=openall", $text{'index_open'});
if ($in{'filter'}) {
	print &ui_link("ipkg-tree.cgi", $text{'IPKG_filterclear'});
	print "&nbsp;&nbsp;", &text('IPKG_filtered',$n-$filter,$n+1), "\n";
}
print "<p>\n";

&ui_print_footer("", $text{'index_return'});

sub traverse
{
local($s, $act, $i);

# Show the icon and class name
print "<tr style=\"border-top: 1px solid lightgrey\"> <td>", $spacer x $_[1];
if ($_[0]) {
	if ($in{'filter'}) {
		print "<img border=0 src='images/close.gif'>";
	} else {
		print "<a name=\"$_[0]\"></a>\n";
		$act = $heiropen{$_[0]} ? "close" : "open";
		my $link = "ipkg-$act.cgi?what=".&urlize($_[0]);
		print &ui_link($link, "<img border=0 src='images/$act.gif'>");
	}
	$_[0] =~ /([^\/]+)$/;
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
			next if ($vers[$i] == '');
			print "<tr> <td nowrap>", $spacer x ($_[1]+1);
        	print "<font size=\"+1\" color=\"red\">", ($inst[$i] ? "&#9989;" : "&nbsp;&#10008;&nbsp;"), "</font>";
			print &ui_link("ipkg-edit_pack.cgi?package=".  &urlize($pack[$i]).
			      "&version=".  &urlize($vers[$i]). "&filter=". &urlize($in{'filter'}),
				  "<b>".&html_escape($pack[$i]. ($vers[$i] ? " $vers[$i]" : ""))."</b>" );
			print "</td> <td>",&html_escape($desc[$i]),"</td>\n";
			print "</tr>\n";
			}
		}
	foreach $s (&unique(split(/\0+/, $heir{$_[0]}))) {
		&traverse($s, $_[1]+1);
		}
	}
}

