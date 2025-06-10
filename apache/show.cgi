#!/usr/local/bin/perl
# show.cgi
# Show directives from a virtualhost, directory or .htaccess

require './apache-lib.pl';
&ReadParse();
if (defined($in{'virt'})) {
	if (defined($in{'idx'})) {
		# directory within virtual server
		($vconf, $v) = &get_virtual_config($in{'virt'});
		$d = $vconf->[$in{'idx'}];
		$conf = $d->{'members'};
		$title = &text('dir_header', &dir_name($d), &virtual_name($v));
		$edit = "edit_dir.cgi"; $return = "dir_index.cgi";
		$editable = 'directory'; $rmsg = $text{'dir_return'};
		}
	else {
		# virtual server
		($conf, $v) = &get_virtual_config($in{'virt'});
		$title = &text('virt_header', &virtual_name($v));
		$edit = "edit_virt.cgi"; $return = "virt_index.cgi";
		$editable = 'virtual'; $rmsg = $text{'virt_return'};
		$dir = "dir_index.cgi";
		}
	}
else {
	if (defined($in{'idx'})) {
		# files within .htaccess file
		$hconf = &get_htaccess_config($in{'file'});
		$d = $hconf->[$in{'idx'}];
		$conf = $d->{'members'};
		$title = &text('htfile_header', &dir_name($d),
			       "<tt>$in{'file'}</tt>");
		$edit = "edit_files.cgi"; $return = "htaccess_index.cgi";
		$editable = "directory"; $rmsg = $text{'htindex_return'};
		}
	else {
		# .htaccess file
		$conf = &get_htaccess_config($in{'file'});
		$title = &text('htindex_header', "<tt>$in{'file'}</tt>");
		$edit = "edit_htaccess.cgi"; $return = "htaccess_index.cgi";
		$editable = 'htaccess'; $rmsg = $text{'htindex_return'};
		$dir = "files_index.cgi";
		}
	}
&ui_print_header($title, $text{'show_title'}, "");

foreach $h ('virt', 'idx', 'file') {
	if (defined($in{$h})) {
		$s .= "<input type=hidden name=$h value='$in{$h}'>\n";
		push(@args, "$h=$in{$h}");
		}
	}
$args = join('&', @args);

for($i=0; $i<$directive_type_count; $i++) {
	foreach $e (&editable_directives($i, $editable)) {
		foreach $n (split(/\s+/, $e->{'name'})) {
			$edit{lc($n)} = $e;
			push(@elist, { 'name' => $n, 'edit' => $e });
			}
		}
	}
@elist = sort { $a->{'name'} cmp $b->{'name'} } @elist;

print "<table><tr><td colspan=2>\n";
print "<table border><tr><td $cb><pre>\n\n";
&show_directives($conf, 0);
print "</pre></td></tr></table>\n";
print "</td></tr>\n";
if ($access{'types'} eq '*' &&
   ($in{'virt'} || $in{'file'} || defined($in{'idx'}))) {
	print "<tr>\n";
	print "<td><form action=manual_form.cgi>";
	print "<input type=submit name=these value='$text{'show_these'}'>";
	print "$s";
	print "</form></td>\n";
	}
else {
	print "<tr> <td></td>\n";
	}

print "<td align=right><form action=$edit>$s",&ui_submit($text{'show_edit'}),"\n";
print "<select name=type>\n";
foreach $e (@elist) {
	print "<option value=",$e->{'edit'}->{'type'},">",
	      $e->{'name'},"</option>\n";
	}
print "</select></form></td>\n";
print "</tr></table>\n";

&ui_print_footer("$return?$args", $rmsg);

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
		my $ed = "";
		print " " x $ind;
		if ($d->{'name'} eq "VirtualHost") { next; }
		elsif ($d->{'name'} =~ /Location|Files|Directory/) {
			$ed = "$dir?$args&idx=$idx";
			}
        my $et = "&lt;".$d->{'name'}." ".$d->{'value'}."&gt;";
        print ( $ed ne "" ? &ui_link($ed, $et) : $et);
		print "\n";
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
			    "$edit?$args&type=$t->{'type'}");
		}
	}
}

