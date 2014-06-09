#!/usr/local/bin/perl
# list_access.cgi
# Display a list of all domain and address mappings

require './sendmail-lib.pl';
require './access-lib.pl';
&ReadParse();
$access{'access'} || &error($text{'access_ecannot'});
&ui_print_header(undef, $text{'access_title'}, "");

$conf = &get_sendmailcf();
$afile = &access_file($conf);
($adbm, $adbmtype) = &access_dbm($conf);
if (!$adbm) {
	# No Kaccess directive in sendmail.cf
	print "<b>",&text('access_efeature', 'list_features.cgi'),"</b><p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
if (!-r $afile) {
	# Text file not found
	print "<b>",&text('access_efile', "<tt>$afile</tt>",
	      "<tt>$adbm</tt>", "$gconfig{'webprefix'}/config.cgi?$module_name"),"</b> <p>\n";
	print "<b>",&text('virtusers_createfile',
		    	  'create_file.cgi?mode=access'),"</b><p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# Get list of spam control rules, limited to those the user can edit
@accs = &list_access($afile);
if ($access{'smode'} == 2) {
	@accs = grep { $_->{'from'} =~ /$access{'saddrs'}/i } @accs;
	}

&access_form();

if ($in{'search'}) {
	# Restrict to search results
	@accs = grep { $_->{'from'} =~ /$in{'search'}/i ||
		       $_->{'to'} =~ /$in{'search'}/i } @accs;
	}
elsif ($config{'max_records'} && @accs > $config{'max_records'}) {
	# Show search form
	print $text{'access_toomany'},"<br>\n";
	print "<form action=list_access.cgi>\n";
	print "<input type=submit value='$text{'access_go'}'>\n";
	print "<input name=search size=20></form>\n";
	undef(@accs);
	}

if (@accs) {
	# sort if needed
	if ($config{'sort_mode'} == 1) {
		@accs = sort { $a->{'from'} cmp $b->{'from'} } @accs;
		}

	# render table of access rules
	print &ui_form_start("delete_access.cgi", "post");
	@links = ( &select_all_link("d", 1),
		   &select_invert_link("d", 1) );
	print &ui_links_row(\@links);
	if ($config{'columns'} == 2) {
		$mid = int((@accs+1)/2);
		print "<table width=100%> <tr><td width=50% valign=top>\n";
		&accs_table(@accs[0..$mid-1]);
		print "</td><td width=50% valign=top>\n";
		if ($mid < @accs) { &accs_table(@accs[$mid..$#accs]); }
		print "</td></tr> </table><br>\n";
		}
	else {
		&accs_table(@accs);
		}
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'access_delete'} ] ]);
	}
print &ui_link("edit_file.cgi?mode=access",&text('file_edit', "<tt>$afile</tt>"))."<p>\n"
	if ($access{'manual'});
print $text{'access_desc1'},"<p>\n";

&ui_print_footer("", $text{'index_return'});

sub accs_table
{
local @tds = ( "width=5" );
print &ui_columns_start([ "",
			  $text{'access_source'},
			  $text{'access_action'},
			  $config{'show_cmts'} ? ( $text{'virtusers_cmt'} )
					       : ( ) ], 100, 0, \@tds);
foreach $m (@_) {
	$from = $m->{'tag'} ? "$m->{'tag'}: $m->{'from'}" : $m->{'from'};
	local @cols;
	push(@cols, "<a href=\"edit_access.cgi?num=$m->{'num'}\">".
		    &html_escape($from)."</a>");
	push(@cols, &html_escape($m->{'action'}));
	push(@cols, &html_escape($m->{'cmt'})) if ($config{'show_cmts'});
	print &ui_checked_columns_row(\@cols, \@tds, "d", $m->{'from'});
	}
print &ui_columns_end();
}

