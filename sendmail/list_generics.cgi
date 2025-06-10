#!/usr/local/bin/perl
# list_generics.cgi
# Display a list of addresses for outgoing address mapping

require './sendmail-lib.pl';
require './generics-lib.pl';
&ReadParse();
$access{'omode'} || &error($text{'generics_cannot'});
&ui_print_header(undef, $text{'generics_title'}, "");

$conf = &get_sendmailcf();
$gfile = &generics_file($conf);
($gdbm, $gdbmtype) = &generics_dbm($conf);
if (!$gdbm) {
	# No Kgenerics directive in sendmail.cf
	print "<b>",&text('generics_efeature', 'list_features.cgi'),"</b><p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
if (!-r $gfile) {
	# Text file not found
	print "<b>",&text('generics_efile', "<tt>$gfile</tt>",
	      "<tt>$gdbm</tt>", "@{[&get_webprefix()]}/config.cgi?$module_name"),"</b> <p>\n";
	print "<b>",&text('virtusers_createfile',
		    	  'create_file.cgi?mode=generics'),"</b><p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# Get list of outgoing mappings, limited to those the user can edit
@gens = &list_generics($gfile);
if ($access{'omode'} == 2) {
	@gens = grep { $_->{'from'} =~ /$access{'oaddrs'}/i ||
		       $_->{'to'} =~ /$access{'oaddrs'}/i } @gens;
	}

&generic_form();

if ($in{'search'}) {
	# Restrict to search results
	@gens = grep { $_->{'from'} =~ /$in{'search'}/ } @gens;
	}
elsif ($config{'max_records'} && @gens > $config{'max_records'}) {
	# Show search form
	print $text{'generics_toomany'},"<br>\n";
	print "<form action=list_generics.cgi>\n";
	print "<input type=submit value='$text{'generics_go'}'>\n";
	print "<input name=search size=20></form>\n";
	undef(@gens);
	}

if (@gens) {
	# sort if needed
	if ($config{'sort_mode'} == 1) {
		@gens = sort sort_by_domain @gens;
		}

	# render table of generics
	print &ui_form_start("delete_generics.cgi", "post");
	@links = ( &select_all_link("d", 1),
		   &select_invert_link("d", 1) );
	print &ui_links_row(\@links);
	if ($config{'columns'} == 2) {
		$mid = int((@gens+1)/2);
		print "<table width=100%> <tr><td width=50% valign=top>\n";
		&gens_table(@gens[0..$mid-1]);
		print "</td><td width=50% valign=top>\n";
		if ($mid < @gens) { &gens_table(@gens[$mid..$#gens]); }
		print "</td></tr> </table><br>\n";
		}
	else {
		&gens_table(@gens);
		}
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'generics_delete'} ] ]);
	}
if ($access{'omode'} == 1 && $access{'manual'}) {
	print &ui_link("edit_file.cgi?mode=generics",&text('file_edit', "<tt>$gfile</tt>"))."<p>\n";
	}

print $text{'generics_desc1'},"<p>\n";
print &text('generics_desc2', "list_cgs.cgi"),"<br>\n";

&ui_print_footer("", $text{'index_return'});

sub gens_table
{
local @tds = ( "width=5" );
print &ui_columns_start([ "",
			  $text{'generics_from'},
			  $text{'generics_to'},
			  $config{'show_cmts'} ? ( $text{'virtusers_cmt'} )
                                               : ( ) ], 100, 0, \@tds);
foreach $g (@_) {
	local @cols;
	push(@cols, "<a href=\"edit_generic.cgi?num=$g->{'num'}\">".
		    "<tt>".&html_escape($g->{'from'})."</tt></a>");
	push(@cols, &html_escape($g->{'to'}));
	push(@cols, &html_escape($g->{'cmt'})) if ($config{'show_cmts'});
	print &ui_checked_columns_row(\@cols, \@tds, "d", $g->{'from'});
	}
print &ui_columns_end();
}

# Notes - The G class lists domains for which outgoing-address translation
# is done. If a mapping for an address like 'foo' exists, it applied for
# from addresses like 'foo' or 'foo@anything'. However, a mapping for
# 'foo@foo.com' applies only for that exact address
# By default, the G class contains only the full local hostname 
# (like florissa.home). Sendmail automatically adds the full hostname
# to unqualified addresses sent locally or through smtp (so <foo> becomes
# <foo@florissa.home>
# The G class can be defined by CG statements in sendmail.cf, or by a
# FG/path line to use an external file..

# If there is a generics mapping from an unqualified name, then it will
# apply for all domains in the G class.

