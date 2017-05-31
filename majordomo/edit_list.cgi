#!/usr/local/bin/perl
# edit_list.cgi
# Edit an existing mailing list

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) ||
	&error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
$conf = &get_list_config($list->{'config'});
local $moderate= (&find_value('moderate', $conf) =~ /no/) ? "" : " (".$text{'index_moderated'}.")";

&ui_print_header( $text{'misc_header'},  $text{'edit_title'}.": ".&html_escape($in{'name'})."<tt>$moderate</tt>", "");

@links = ( "edit_access.cgi", "edit_misc.cgi" );
foreach $a (&foreign_call($aliases_module, "list_aliases",
			  &get_aliases_file())) {
	if ($a->{'name'} =~ /-digestify$/i &&
	    $a->{'value'} =~ /\s$in{'name'}\s/i) {
		$isdigest++;
		}
	}
if ($isdigest) {
	push(@links, "edit_digest.cgi");
	}
# name to add to links
$name_link="?name=".&urlize($in{'name'});
# other buttons
local $otherbut, $bcss=' style="display: box; float: left; padding: 10px;"';
foreach (@links)
{
	$action = $_ .$name_link, ($submit=$_) =~ s/edit_(\S+).cgi/$1_title/;
        $otherbut .= "<div $bcss><form action=\"".$action."\" method=\"post\">".&ui_submit($text{$submit})."</form></div>\n";
}
print $otherbut;

# css for table
local $tcss='style="width: 98%; margin: 1% !important;"';
local $dcss='style="text-align: right; vertical-align: middle; padding: 0.3em 1em !important; min_heigth: 5em;"';
local $vcss='style="width: 40%; border: 1px solid lightgrey; padding: 0.3em !important;"';
local $xcss='style="width: 25%; border: 1px solid lightgrey; padding: 0.3em !important;"';

# list options
print "<table border width=\"100%\">\n";
print "<tr $tb> <td><b>$text{'mesg_header'}</b></td>";
print "<td width=\"10%\" nowrap><form action=\"edit_mesg.cgi".$name_link."\" method=\"post\">",
        &ui_submit($text{'modify'}),"</form>\n</tr>\n";
print "<tr $cb> <td colspan=\"2\"><table $tcss>\n";

print "<tr><td $dcss><b>".$text{'mesg_reply'}."</b></td><td $vcss>",&find_value("reply_to", $conf)."</td></tr>\n";
print "<tr><td $dcss><b>".$text{'mesg_subject'}."</b></td><td $vcss>".&find_value("subject_prefix", $conf)."</td></tr>\n";
print "</table></td></tr></table>\n";

# title, descritpion, info
print "<table border width=\"100%\">\n";
print "<tr $tb> <td><b>".$text{'info_title'}."</b></td>";
print "<td width=\"10%\" nowrap><form action=\"edit_info.cgi".$name_link."\" method=\"post\">",
	&ui_submit($text{'modify'}),"</form>\n</tr>\n";
print "<tr $cb> <td colspan=\"2\"><table $tcss>\n";
print "<tr> <td $dcss><b>".$text{'info_desc'}."</b></td>\n";
$desc = &find_value("description", $conf);
print "<td $vcss>$desc</td> </tr>\n";
print "<tr> <td $dcss><b>",&text('info_info', $in{'name'}),"</b></td>\n";
print "<td $vcss>";
  open(INFO, $list->{'info'});
  while(<INFO>) {
	print if (!/^\[Last updated on:/);
	}
  close(INFO);
print "</td> </tr>\n";
print "<tr> <td $dcss><b>".$text{'info_intro'}."</b></td> <td $vcss>\n";
  open(INTRO, $list->{'intro'});
  while(<INTRO>) {
	print if (!/^\[Last updated on:/);
	}
  close(INTRO);
print "</td> </tr>\n";
print "</table></td></tr></table>\n";

# header and footer
print "<table border width=\"100%\">\n";
print "<tr $tb> <td><b>".$text{'head_title'}."</b></td>";
print "<td width=\"10%\" nowrap><form action=\"edit_head.cgi".$name_link."\" method=\"post\">",
	&ui_submit($text{'modify'}),"</form>\n</tr>\n";
print "<tr $cb> <td colspan=\"2\"><table $tcss>\n";
print "<tr> <td $dcss><b>".$text{'head_fronter'}."</b></td> <td $vcss>\n";
print  &find_value("message_fronter", $conf);
print "</td></tr>\n";
print "<tr> <td $dcss><b>".$text{'head_footer'}."</b></td> <td $vcss>\n";
print  &find_value("message_footer", $conf);
print "</td></tr>\n";
print "<tr> <td $dcss><b>".$text{'head_headers'}."</b></td> <td $vcss>\n";
print  &find_value("message_headers", $conf);
print "</td></tr>\n";
print "</table></td></tr></table>\n";

# owner and moderation
print "<table border width=\"100%\">\n";
print "<tr $tb> <td><b>$text{'subs_title'}</b></td>";
print "<td width=\"10%\" nowrap><form action=\"edit_subs.cgi".$name_link."\" method=\"post\">",
        &ui_submit($text{'modify'}),"</form>\n</tr>\n";
print "<tr $cb> <td colspan=\"2\"><table $tcss>\n";

$pol = &find_value("subscribe_policy", $conf);
if ($pol =~ /(\S+)\+confirm/) { $pol = $1; $confirm = 1; }
print "<tr> <td $dcss><b>$text{'subs_sub'}:</b></td> <td $xcss nowrap>\n";
print $pol eq "closed" ? $text{'subs_closed'} : $text{'subs_s'.$pol};
print "</td>\n";

$pol = &find_value("unsubscribe_policy", $conf);
print "<td $dcss><b>$text{'subs_unsub'}:</b></td> <td $xcss nowrap>\n";
print $pol eq "closed" ? $text{'subs_closed'} : $text{'subs_u'.$pol};
print "</td> </tr>\n";

$aliases_files = &get_aliases_file();
@aliases = &foreign_call($aliases_module, "list_aliases", $aliases_files);
foreach $a (@aliases) {
	$owner = $a->{'value'}
		if (lc($a->{'name'}) eq lc("$in{'name'}-owner") ||
		    lc($a->{'name'}) eq lc("owner-$in{'name'}"));
	$approval = $a->{'value'}
		if (lc($a->{'name'}) eq lc("$in{'name'}-approval"));
	}
print "<tr> <td $dcss><b>$text{'subs_owner'}</b></td>\n";
print "<td $xcss >".&get_alias_owner($owner)."</td>\n";

print "<td $dcss><b>$text{'subs_approval'}</b></td>\n";
print "<td $xcss >".$approval."</td> </tr>\n";
print "</table></td></tr></table>\n";

# members
print "<table border width=\"100%\">\n";
print "<tr $tb> <td><b>".$text{'members_title'}."</b></td>";
print "<td width=\"10%\" nowrap><form action=\"edit_members.cgi".$name_link."\" method=\"post\">",
	&ui_submit($text{'modify'}),"</form>\n</tr>\n";
print "<tr $cb> <td colspan=\"2\">\n";
local @cols, @tds, $count=0;
print &ui_columns_start(\@cols, $tcss, 0, \@tds);
  open(MEMS, $list->{'members'});
  while(<MEMS>) {
	$count++;
	push(@cols, $_);
	if($count % 3 == 0) {print &ui_columns_row(\@cols, \@tds); @cols=();}
	}
  close(MEMS);
push(@cols,"","") if $count % 3 == 1;
push(@cols, "") if $count % 3 == 2;
print &ui_columns_row(\@cols, \@tds);
print "</table></td></tr></table>\n";

#delete list
print "<div $bcss><form action=\"delete_list.cgi".$name_link."\" method=\"post\">",
	&ui_submit($text{'edit_delete'})."</form></div>\n";
print "<div style=\"padding-top: 20px;\">$text{'edit_deletemsg'}</div>\n";

&ui_print_footer("", $text{'index_return'});
