#!/usr/local/bin/perl
# import.cgi
# Add email addresses to the allowed list

require './spam-lib.pl';
&ReadParseMime();
$in{'import'} || &error($text{'import_efile'});

# Parse the file
while($in{'import'} =~ s/((([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+([a-zA-Z]{2,})+)))//) {
	push(@addrs, $1);
	}
@addrs || &error($text{'import_enone'});
@addrs = &unique(@addrs);

&lock_spam_files();
$conf = &get_config();
@from = map { @{$_->{'words'}} } &find("whitelist_from", $conf);
%already = map { $_, 1 } @from;
@newaddrs = grep { !$already{$_} } @addrs;

&ui_print_header(undef, $text{'import_title'}, "");

if (@newaddrs) {
	print "<p>",&text('import_ok1', scalar(@newaddrs),
					scalar(@addrs)),"<p>\n";
	push(@from, @newaddrs);
	if ($in{'sort'}) {
		@from = sort { ($ua, $da) = split(/\@/, $a);
			       ($ub, $db) = split(/\@/, $b);
			       lc($da) cmp lc($db) || lc($ua) cmp lc($ub) }
			     @from;
		}
	&save_directives($conf, 'whitelist_from', \@from, 1);
	&flush_file_lines();
	}
else {
	print "<p>",&text('import_ok2', scalar(@addrs)),"<p>\n";
	}
&webmin_log("import", scalar(@newaddrs));
&unlock_spam_files();

&ui_print_footer("edit_white.cgi", $text{'white_return'});

