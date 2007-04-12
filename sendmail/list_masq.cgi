#!/usr/local/bin/perl
# list_masq.cgi
# List domains for which masquerading is done

require './sendmail-lib.pl';
$access{'masq'} || &error($text{'masq_ecannot'});
&ui_print_header(undef, $text{'masq_title'}, "");
$conf = &get_sendmailcf();

# Get the domain we masquerade as
foreach $d (&find_type("D", $conf)) {
	if ($d->{'value'} =~ /^M\s*(\S*)/) { $masq = $1; }
	}

# Get masquerading domains
@mlist = &get_file_or_config($conf, "M");

# Get non-masqueraded domains
@nlist = &get_file_or_config($conf, "N");

print "<form method=post action=save_masq.cgi enctype=multipart/form-data>\n";
print "<b>$text{'masq_domain'}</b>\n";
print "<input name=masq size=30 value=\"$masq\"><br>\n";

print "<table cellpadding=5 width=100%><tr><td valign=top nowrap>\n";
print "<b>$text{'masq_domains'}</b><br>\n";
print "<textarea name=mlist rows=8 cols=65>",
	join("\n", @mlist),"</textarea><br>\n";
print "<b>$text{'masq_ndomains'}</b><br>\n";
print "<textarea name=nlist rows=7 cols=65>",
	join("\n", @nlist),"</textarea><br>\n";
print "<input type=submit value=\"$text{'save'}\">\n";

print "</td><td valign=top>\n";
print &text('masq_desc1', 'list_generics.cgi'),"<p>\n";
print $text{'masq_desc2'},"\n";
print "</td></tr></table>\n";
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

