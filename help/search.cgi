#!/usr/local/bin/perl
# search.cgi
# Search help for the selected modules and display the results

require './help-lib.pl';
&ReadParse();
&error_setup($text{'search_err'});

# Parse and validate inputs
$in{'terms'} || &error($text{'search_eterms'});
if ($in{'all'}) {
	@mods = map { $_->[0] } &list_modules();
	}
else {
	$in{'mods'} || &error($text{'search_emods'});
	@mods = split(/\0/, $in{'mods'});
	}

&ui_print_header(undef, $text{'search_title'}, "", "search");

# Do the search
($terms = $in{'terms'}) =~ s/\\/\\\\/g;
foreach $m (@mods) {
	local %minfo = &get_module_info($m);
	local $dir = &module_root_directory($m)."/help";
	local @pfx;
	opendir(DIR, $dir);
	while($f = readdir(DIR)) {
		push(@pfx, $1) if ($f =~ /^([^\.]+)\.html$/);
		}
	closedir(DIR);
	foreach $p (&unique(@pfx)) {
		local $file = &help_file($m, $p);
		local $help = &read_file_contents($file);
		if ($help =~ /<header>([^<]+)<\/header>/) {
			$header = $1;
			}
		else { next; }
		$help =~ s/<include\s+(\S+)>/inchelp($1)/ge;
		$help =~ s/<[^>]+>//g;
		if ($help =~ /(.*)(\Q$terms\E)(.*)/i) {
			push(@match, [ $m, $minfo{'desc'}, $p,
				       $header, "$1<b>$2</b>$3" ] );
			}
		}
	}

# Display the results
if (@match) {
	print "<b>",&text('search_results', "<tt>$terms</tt>"),"</b><p>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'search_page'}</b></td> ",
	      "<td><b>$text{'search_mod'}</b></td> ",
	      "<td><b>$text{'search_line'}</b></td> </tr>\n";
	foreach $m (@match) {
		print "<tr $cb>\n";
		print "<td>",&hlink($m->[3], $m->[2], $m->[0]),"</td>\n";
		print "<td>$m->[1]</td>\n";
		print "<td>$m->[4]</td>\n";
		print "</tr>\n";
		}
	print "</table><p>\n";
	}
else {
	print "<p><b>$text{'search_none'}</b> <p>\n";
	}
&ui_print_footer("", $text{'index_return'});


# help_file(dir, prefix)
sub help_file
{
local $lang = "$_[0]/$_[1].$current_lang.html";
local $def = "$_[0]/$_[1].html";
return -r $lang ? $lang : $def;
}

# inchelp(path)
sub inchelp
{
local $inc;
local $ipath = &help_file($dir, $_[0]);
open(INC, $ipath) || return "<i>".&text('search_einclude', $_[0])."</i><br>\n";
local @st = stat(INC);
read(INC, $inc, $st[7]);
close(INC);
return $inc;
}


