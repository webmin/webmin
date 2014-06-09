#!/usr/local/bin/perl
# list_virtusers.cgi
# Display a list of all domain and address mappings

require './sendmail-lib.pl';
require './virtusers-lib.pl';
&ReadParse();
$access{'vmode'} || &error($text{'virtusers_ecannot'});
&ui_print_header(undef, $text{'virtusers_title'}, "");

$conf = &get_sendmailcf();
$vfile = &virtusers_file($conf);
($vdbm, $vdbmtype) = &virtusers_dbm($conf);
if (!$vdbm) {
	# No Kvirtuser directive in sendmail.cf
	print "<b>",&text('virtusers_efeature', 'list_features.cgi'),"</b><p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
if (!-r $vfile) {
	# Text file not found
	print "<b>",&text('virtusers_efile', "<tt>$vfile</tt>",
	      "<tt>$vdbm</tt>", "$gconfig{'webprefix'}/config.cgi?$module_name"),"</b><p>\n";
	print "<b>",&text('virtusers_createfile',
		    	  'create_file.cgi?mode=virtusers'),"</b><p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
@virts = &list_virtusers($vfile);
if ($access{'vmode'} == 2) {
	@virts = grep { $_->{'from'} =~ /$access{'vaddrs'}/ } @virts;
	}
elsif ($access{'vmode'} == 3) {
	@virts = grep { $_->{'from'} =~ /^$remote_user\@/ } @virts;
	}
@virts = grep { $access{"vedit_".&virt_type($_->{'to'})} } @virts; 
if (!$access{'vcatchall'}) {
	@virts = grep { $_->{'from'} !~ /^\@/ } @virts;
	}

&virtuser_form();

if ($in{'search'}) {
	# Restrict to search results
	@virts = grep { $_->{'from'} =~ /$in{'search'}/i ||
			$_->{'to'} =~ /$in{'search'}/i } @virts;
	}
elsif ($config{'max_records'} && @virts > $config{'max_records'}) {
	# Show search form
	print $text{'virtusers_toomany'},"<br>\n";
	print "<form action=list_virtusers.cgi>\n";
	print "<input type=submit value='$text{'virtusers_go'}'>\n";
	print "<input name=search size=20></form>\n";
	undef(@virts);
	}

if (@virts) {
	# sort if needed
	if ($config{'sort_mode'} == 1) {
		@virts = sort sort_by_domain @virts;
		}

	# render table of virtusers
	print &ui_form_start("delete_virtusers.cgi", "post");
	@links = ( &select_all_link("d", 1),
		   &select_invert_link("d", 1) );
	print &ui_links_row(\@links);
	if ($config{'columns'} == 2) {
		$mid = int((@virts+1)/2);
		print "<table width=100%> <tr><td width=50% valign=top>\n";
		&virts_table(@virts[0..$mid-1]);
		print "</td><td width=50% valign=top>\n";
		if ($mid < @virts) { &virts_table(@virts[$mid..$#virts]); }
		print "</td></tr> </table><br>\n";
		}
	else {
		&virts_table(@virts);
		}
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'virtusers_delete'} ] ]);
	}
if ($access{'vmode'} == 1 && $access{'vedit_0'} && $access{'vedit_1'} &&
    $access{'vedit_2'} && $access{'vmax'} == 0 && $access{'manual'}) {
	print &ui_link("edit_file.cgi?mode=virtusers",&text('file_edit', "<tt>$vfile</tt>"))."<p>\n";
	}

print &text('virtusers_desc1', 'list_aliases.cgi'),"<p>\n"
	if ($access{'amode'});
print &text('virtusers_desc2', 'list_cws.cgi'),"<br>\n"
	if ($access{'cws'});

&ui_print_footer("", $text{'index_return'});

sub virts_table
{
local @tds = ( "width=5" );
print &ui_columns_start([ "",
			  $text{'virtusers_for'},
			  $text{'virtusers_to'},
			  $config{'show_cmts'} ? ( $text{'virtusers_cmt'} )
					       : ( ) ], 100, 0, \@tds);
foreach $m (@_) {
	local @cols;
	push(@cols, "<a href=\"edit_virtuser.cgi?num=$m->{'num'}\">".
		    "<tt>".&html_escape($m->{'from'})."</tt></a>");
	if ($m->{'to'} =~ /^error:(.*)$/) {
		push(@cols, &text('virtusers_error',
			    "<tt>".&html_escape("$1")."</tt>"));
		}
	elsif ($m->{'to'} =~ /^\%1\@(\S+)$/) {
		push(@cols, &text('virtusers_domain',
			    "<tt>".&html_escape("$1")."</tt>"));
		}
	else {
		push(@cols, &text('virtusers_address',
			    "<tt>".&html_escape($m->{'to'})."</tt>"));
		}
	push(@cols, &html_escape($m->{'cmt'})) if ($config{'show_cmts'});
	print &ui_checked_columns_row(\@cols, \@tds, "d", $m->{'from'});
	}
print &ui_columns_end();
}

