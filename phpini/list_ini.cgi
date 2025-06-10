#!/usr/local/bin/perl
# Show a page of icons for various PHP config sections

require './phpini-lib.pl';
&ReadParse();
$in{'file'} =~ /^\// || &error($text{'list_efile'});
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});

# Work out if we can just see one file
@files = &list_php_configs();
if (@files == 1 && !$access{'anyfile'} && $access{'noconfig'}) {
	$onefile = 1;
	}
$inidir = &get_php_ini_dir($in{'file'});

my $bin = &get_php_ini_binary($in{'file'});
my $ver = &get_php_binary_version($in{'file'});
my $vmsg = "";
if ($bin && $ver) {
	$vmsg = "<br>".&text('list_bin', "<tt>$bin</tt>", $ver);
	}
&ui_print_header("<tt>".&html_escape($in{'file'})."</tt>".$vmsg,
		 $text{'list_title'}, "", undef, 0, $onefile);

@pages = ( "vars", "dirs", "db", "session", "limits",
	   "errors", "disable", "misc" );
push(@pages, "manual") if ($access{'manual'} ne '0');
push(@pages, "mods") if ($inidir && $access{'global'});
@links = map { "edit_${_}.cgi?file=".&urlize($in{'file'})."&oneini=1" } @pages;
@titles = map { $text{$_."_title"} } @pages;
@icons = map { "images/$_.gif" } @pages;
&icons_table(\@links, \@titles, \@icons, 4);

if ($onefile) {
	&ui_print_footer("/", $text{'index'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

