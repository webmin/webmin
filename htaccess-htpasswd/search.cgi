#!/usr/local/bin/perl
# search.cgi
# Find .htaccess files under some directory

require './htaccess-lib.pl';
&foreign_require($apachemod, "apache-lib.pl");

&ReadParse();
&error_setup($text{'search_err'});
if ($in{'search'} !~ /^\// && $accessdirs[0] ne "/") {
	# Make path absolute
	$in{'search'} = "$accessdirs[0]/$in{'dir'}";
	}
$in{'search'} =~ /^\// && $in{'search'} !~ /\.\./ ||
	&error($text{'search_edir'});
&can_access_dir($in{'search'}) || &error($text{'search_ecannot'});

&ui_print_unbuffered_header(undef, $text{'search_title'}, "");

@dirs = &list_directories();
%got = map { ( "$_->[0]/$config{'htaccess'}", 1 ) } @dirs;
print "<b>",&text('search_doing', "<tt>$in{'search'}</tt>"),"</b><p>\n";

# Use the find command
&switch_user();
open(FIND, "find ".quotemeta($in{'search'})." -name ".
	   quotemeta($config{'htaccess'})." -print 2>/dev/null |");
while($f = <FIND>) {
	chop($f);
	if ($got{$f}) {
		print &text('search_already', "<tt>$f</tt>"),"<br>\n";
		}
	elsif (!open(TEST, $f)) {
		print &text('search_open', "<tt>$f</tt>", $!),"<br>\n";
		}
	else {
		$conf = &foreign_call($apachemod, "get_htaccess_config", $f);
		$currfile = &foreign_call($apachemod, "find_directive",
					  "AuthUserFile", $conf, 1);
		$require = &foreign_call($apachemod, "find_directive",
					 "require", $conf, 1);
		if ($currfile && $require) {
			print &text('search_found', "<tt>$f</tt>",
				    "<tt>$currfile</tt>"),"<br>\n";
			local $d = $f;
			$d =~ s/\/$config{'htaccess'}$//;
			push(@dirs, [ $d, $currfile ]);
			}
		else {
			print &text('search_noprot', "<tt>$f</tt>"),"<br>\n";
			}
		}
	}
close(FIND);
print "<p><b>$text{'search_done'}</b><p>\n";
&switch_back();

&lock_file($directories_file);
&save_directories(\@dirs);
&unlock_file($directories_file);
&webmin_log("search", $in{'search'});

&ui_print_footer("", $text{'index_return'});


