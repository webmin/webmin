#!/usr/local/bin/perl
# show_dir.cgi
# Show directives from a directory (or equivalent) section

require './apache-lib.pl';
&ReadParse();
($vconf, $v) = &get_virtual_config($in{'virt'});
$d = $vconf->[$in{'idx'}];
$conf = $d->{'members'};
$desc = &text('dir_header', &dir_name($d), &virtual_name($v));
&ui_print_header($desc, $text{'show_title'}, "");

for($i=0; $i<$directive_type_count; $i++) {
	foreach $e (&editable_directives($i, 'directory')) {
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

print "<form action=edit_dir.cgi>\n";
print "<input type=hidden name=virt value=\"$in{'virt'}\">\n";
print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
print "<b>$text{'show_edit'}</b>\n";
print "<select name=type>\n";
foreach $e (@elist) {
	print "<option value=",$e->{'edit'}->{'type'},">",
	      $e->{'name'},"</option>\n";
	}
print "</select> <input type=submit value=\"$text{'show_ok'}\">\n";
print "</form>\n";

&ui_print_footer("dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}", $text{'dir_return'});

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
		print " " x $ind;
		print "&lt;",$d->{'name'}," ",$d->{'value'},"&gt;\n";
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
			    "edit_dir.cgi?virt=$in{'virt'}&type=$t->{'type'}&idx=$in{'idx'}");
		}
	}
}

