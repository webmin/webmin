#!/usr/local/bin/perl
# show_htaccess.cgi
# Show directives from a .htaccess

require './apache-lib.pl';
&ReadParse();
$conf = &get_htaccess_config($in{'file'});
$desc = &text('htindex_header', "<tt>$in{'file'}</tt>");
&ui_print_header($desc, $text{'show_title'}, "");

for($i=0; $i<$directive_type_count; $i++) {
	foreach $e (&editable_directives($i, 'htaccess')) {
		foreach $n (split(/\s+/, $e->{'name'})) {
			$edit{lc($n)} = $e;
			push(@elist, { 'name' => $n, 'edit' => $e });
			}
		}
	}
@elist = sort { $a->{'name'} cmp $b->{'name'} } @elist;

print "<table border><tr><td $cb><pre>\n\n";
&show_directives($conf, 0);
print "</pre></td></tr></table><p>\n";

print "<form action=edit_htaccess.cgi>\n";
print "<input type=hidden name=file value=\"$in{'file'}\">\n";
print "<b>$text{'show_edit'}</b>\n";
print "<select name=type>\n";
foreach $e (@elist) {
	print "<option value=",$e->{'edit'}->{'type'},">",
	      $e->{'name'},
		"</option>\n";
	}
print "</select> <input type=submit value=\"$text{'show_ok'}\">\n";
print "</form>\n";

&ui_print_footer("htaccess_index.cgi?file=$in{'file'}", $text{'htindex_return'});

# show_directives(list, indent)
sub show_directives
{
local ($list, $ind) = @_;
local $idx;
for($idx=0; $idx<@$list; $idx++) {
	local $d = $list->[$idx];
	next if ($d->{'name'} eq "dummy");
	$t = $edit{lc($d->{'name'})};
	if ($d->{'type'}) {
		# Recurse into section
		local ($ed1, $ed2);
		print " " x $ind;
		if ($d->{'name'} =~ /Files/) {
			$ed1 = "<a href=\"files_index.cgi?idx=$idx&".
			       "file=$in{'file'}\">";
			$ed2 = "</a>";
			}
		print $ed1,"&lt;",$d->{'name'}," ",$d->{'value'},
		      "&gt;",$ed2,"\n";
		&show_directives($d->{'members'}, $ind+1);
		print " " x $ind;
		print "&lt;/",$d->{'name'},"&gt;\n";
		}
	elsif ($_[1] || !$access_types{$t->{'type'}}) {
		# Directives in section are not editable
		&print_line($d, [ $d->{'name'}," ",$d->{'value'} ], $ind);
		}
	else {
		next if (!$t);
		&print_line($d, [ $d->{'name'}," ",$d->{'value'} ], $ind,
			    "edit_htaccess.cgi?file=$in{'file'}&type=$t->{'type'}");
		}
	}
}

