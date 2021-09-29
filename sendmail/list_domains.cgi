#!/usr/local/bin/perl
# list_domains.cgi
# Display a list of all domain mappings

require './sendmail-lib.pl';
require './domain-lib.pl';
$access{'domains'} || &error($text{'domains_ecannot'});
&ui_print_header(undef, $text{'domains_title'}, "");

$conf = &get_sendmailcf();
$dfile = &domains_file($conf);
($ddbm, $ddbmtype) = &domains_dbm($conf);
if (!$ddbm) {
	# No Kdomain directive in sendmail.cf
	print "<b>",&text('domains_efeature', 'list_features.cgi'),"</b><p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
if (!-r $dfile) {
	# Text file not found
	print "<b>",&text('domains_efile', "<tt>$dfile</tt>",
	      "<tt>$ddbm</tt>", "@{[&get_webprefix()]}/config.cgi?$module_name"),"</b> <p>\n";
	print "<b>",&text('virtusers_createfile',
		    	  'create_file.cgi?mode=domains'),"</b><p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
@doms = &list_domains($dfile);

&domain_form();
if (@doms) {
	# sort if needed
	if ($config{'sort_mode'} == 1) {
		@doms = sort { $a->{'from'} cmp $b->{'from'} } @doms;
		}

	# render table of domains
	print &ui_form_start("delete_domains.cgi", "post");
	@links = ( &select_all_link("d", 1),
		   &select_invert_link("d", 1) );
	print &ui_links_row(\@links);
	if ($config{'columns'} == 2) {
		$mid = int((@doms+1)/2);
		print "<table width=100%> <tr><td width=50% valign=top>\n";
		&doms_table(@doms[0..$mid-1]);
		print "</td><td width=50% valign=top>\n";
		if ($mid < @doms) { &doms_table(@doms[$mid..$#doms]); }
		print "</td></tr> </table><br>\n";
		}
	else {
		&doms_table(@doms);
		}
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'domains_delete'} ] ]);
	}
print &ui_link("edit_file.cgi?mode=domains",
	       &text('file_edit', "<tt>$dfile</tt>")),"<p>\n"
	if ($access{'manual'});
print $text{'domains_desc'},"<p>\n";

&ui_print_footer("", $text{'index_return'});

sub doms_table
{
local @tds = ( "width=5" );
print &ui_columns_start([ "",
			  $text{'domains_from'},
			  $text{'domains_to'},
			  $config{'show_cmts'} ? ( $text{'virtusers_cmt'} )
					       : ( ) ], 100, 0, \@tds);
foreach $m (@_) {
	local @cols;
	push(@cols, "<a href=\"edit_domain.cgi?num=$m->{'num'}\">".
		    &html_escape($m->{'from'})."</a>");
	push(@cols, &html_escape($m->{'to'}));
	push(@cols, &html_escape($m->{'cmt'})) if ($config{'show_cmts'});
	print &ui_checked_columns_row(\@cols, \@tds, "d", $m->{'from'});
	}
print &ui_columns_end();
}

