#!/usr/local/bin/perl
# list_aliases.cgi
# Displays a list of all aliases

require './sendmail-lib.pl';
require './aliases-lib.pl';
&ReadParse();
$access{'amode'} || &error($text{'aliases_ecannot'});
$conf = &get_sendmailcf();
$afile = &aliases_file($conf);
@$afile || &error($text{'aliases_enofile'});
&ui_print_header(undef, $text{'aliases_title'}, "", "aliases");

@aliases = &list_aliases($afile);
if ($access{'amode'} == 2) {
	@aliases = grep { $_->{'name'} =~ /$access{'aliases'}/ } @aliases;
	}
elsif ($access{'amode'} == 3) {
	@aliases = grep { $_->{'name'} eq $remote_user } @aliases;
	}
@aliases = grep { local $rv = 1;
		  foreach $v (@{$_->{'values'}}) {
			$rv = 0 if (!$access{"aedit_".&alias_type($v)});
			}
		  $rv;
		} @aliases;

&alias_form(undef, undef, $afile);

if ($in{'search'}) {
	# Restrict to search results
	@aliases = grep { $_->{'name'} =~ /$in{'search'}/ } @aliases;
	}
elsif ($config{'max_records'} && @aliases > $config{'max_records'}) {
	# Show search form
	print $text{'aliases_toomany'},"<br>\n";
	print "<form action=list_aliases.cgi>\n";
	print "<input type=submit value='$text{'aliases_go'}'>\n";
	print "<input name=search size=20></form>\n";
	undef(@aliases);
	}

if (@aliases) {
	# sort if needed
	if ($config{'sort_mode'} == 1) {
		@aliases = sort { lc($a->{'name'}) cmp lc($b->{'name'}) }
				@aliases;
		}

	# find a good place to split
	$lines = 0;
	for($i=0; $i<@aliases; $i++) {
		$aline[$i] = $lines;
		$al = scalar(@{$aliases[$i]->{'values'}});
		$lines += ($al ? $al : 1);
		}
	$midline = int(($lines+1) / 2);
	for($mid=0; $mid<@aliases && $aline[$mid] < $midline; $mid++) { }

	# render tables
	print &ui_form_start("delete_aliases.cgi", "post");
	@links = ( &select_all_link("d", 1),
		   &select_invert_link("d", 1) );
	print &ui_links_row(\@links);
	if ($config{'columns'} == 2) {
		print "<table width=100%> <tr><td width=50% valign=top>\n";
		&aliases_table(@aliases[0..$mid-1]);
		print "</td><td width=50% valign=top>\n";
		if ($mid < @aliases) { &aliases_table(@aliases[$mid..$#aliases]); }
		print "</td></tr> </table><br>\n";
		}
	else {
		&aliases_table(@aliases);
		}
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'aliases_delete'} ] ]);
	}

if ($access{'amode'} == 1 && $access{'aedit_1'} && $access{'aedit_2'} &&
    $access{'aedit_3'} && $access{'aedit_4'} && $access{'aedit_5'} &&
    $access{'amax'} == 0 && $access{'apath'} eq '/' &&
    $access{'manual'}) {
	$i = 0;
	foreach $f (@{&aliases_file($conf)}) {
		print "<a href='edit_file.cgi?mode=aliases&idx=$i'>",
			&text('file_edit', "<tt>$f</tt>"),
			"</a>&nbsp;&nbsp;\n";
		$i++;
		}
	print "<p>\n";
	}

&ui_print_footer("", $text{'index_return'});

sub aliases_table
{
local @tds = ( "width=5", "valign=top", "valign=top" );
print &ui_columns_start([ "",
			  $text{'aliases_addr'},
			  $text{'aliases_to'},
			  $config{'show_cmts'} ? ( $text{'virtusers_cmt'} )
					       : ( ) ], 100, 0, \@tds);
foreach $a (@_) {
	local @cols;
	push(@cols, "<a href=\"edit_alias.cgi?num=$a->{'num'}\">".
	      ($a->{'enabled'} ? "" : "<i>").&html_escape($a->{'name'}).
	      ($a->{'enabled'} ? "" : "</i>")."</a>");
	local $vstr;
	foreach $v (@{$a->{'values'}}) {
		($anum, $astr) = &alias_type($v);
		$vstr .= &text("aliases_type$anum",
			    "<tt>".&html_escape($astr)."</tt>")."<br>\n";
		}
	$vstr ||= "<i>$text{'aliases_none'}</i>\n";
	push(@cols, $vstr);
	push(@cols, &html_escape($a->{'cmt'})) if ($config{'show_cmts'});
	print &ui_checked_columns_row(\@cols, \@tds, "d", $a->{'name'});
	}
print &ui_columns_end();
}

