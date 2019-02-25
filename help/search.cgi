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
	print &ui_columns_start([ $text{'search_page'},
				  $text{'search_mod'},
				  $text{'search_line'} ]);
	foreach $m (@match) {
		print &ui_columns_row([
			&hlink($m->[3], $m->[2], $m->[0]),
			$m->[1],
			$m->[4],
			]);
		}
	print &ui_columns_end();
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


