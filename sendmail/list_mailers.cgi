#!/usr/local/bin/perl
# list_mailers.cgi
# Display a list of mailertable domains

require './sendmail-lib.pl';
require './mailers-lib.pl';

$access{'mailers'} || &error($text{'mailers_cannot'});
&ui_print_header(undef, $text{'mailers_title'}, "");

$conf = &get_sendmailcf();
$mfile = &mailers_file($conf);
($mdbm, $mdbmtype) = &mailers_dbm($conf);
if (!$mdbm) {
	# No Kmailertable directive in sendmail.cf
	print "<b>",&text('mailers_efeature', 'list_features.cgi'),"</b><p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
if (!-r $mfile) {
	# Text file not found
	print "<b>",&text('mailers_efile', "<tt>$mfile</tt>",
	      "<tt>$mdbm</tt>", "@{[&get_webprefix()]}/config.cgi?$module_name"),"</b> <p>\n";
	print "<b>",&text('virtusers_createfile',
		    	  'create_file.cgi?mode=mailers'),"</b><p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
@mailers = &list_mailers($mfile);

&mailer_form();
if (@mailers) {
	# sort if needed
	if ($config{'sort_mode'} == 1) {
		@mailers = sort { $a->{'domain'} cmp $b->{'domain'} } @mailers;
		}

	# render table of mailers
	print &ui_form_start("delete_mailers.cgi", "post");
	@links = ( &select_all_link("d", 1),
		   &select_invert_link("d", 1) );
	print &ui_links_row(\@links);
	if ($config{'columns'} == 2) {
		$mid = int((@mailers+1)/2);
		print "<table width=100%> <tr><td width=50% valign=top>\n";
		&mailers_table(@mailers[0..$mid-1]);
		print "</td><td width=50% valign=top>\n";
		if ($mid < @mailers) { &mailers_table(@mailers[$mid..$#mailers]); }
		print "</td></tr> </table><br>\n";
		}
	else {
		&mailers_table(@mailers);
		}
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'mailers_delete'} ] ]);
	}
print &ui_link("edit_file.cgi?mode=mailers",&text('file_edit', "<tt>$mfile</tt>"))."<p>\n"
	if ($access{'manual'});
print $text{'mailers_desc1'},"<p>\n";
print &text('mailers_desc2', 'list_cws.cgi')," ",
      &text('mailers_desc3', 'list_relay.cgi'),"<br>\n";

&ui_print_footer("", $text{'index_return'});

sub mailers_table
{
local @tds = ( "width=5" );
print &ui_columns_start([ "",
			  $text{'mailers_for'},
			  $text{'mailers_delivery'},
			  $text{'mailers_to'},
			  $config{'show_cmts'} ? ( $text{'virtusers_cmt'} )
                                               : ( ) ], 100, 0, \@tds);
foreach $m (@_) {
	local @cols;
	push(@cols, "<a href=\"edit_mailer.cgi?num=$m->{'num'}\">".
		    &html_escape($m->{'domain'})."</a>");
	$md = $mailer_desc{$m->{'mailer'}};
	push(@cols, $md ? $md : $m->{'mailer'});
	push(@cols, &html_escape($m->{'dest'}));
	push(@cols, &html_escape($m->{'cmt'})) if ($config{'show_cmts'});
	print &ui_checked_columns_row(\@cols, \@tds, "d", $m->{'domain'});
	}
print &ui_columns_end();
}

