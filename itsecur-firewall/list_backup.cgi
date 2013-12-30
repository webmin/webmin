#!/usr/bin/perl
# Show a form for backing up some or all firewall objects

require './itsecur-lib.pl';
&can_edit_error("backup");
&check_zip();
&header($text{'backup_title'}, "",
	undef, undef, undef, undef, &apply_button());
print &ui_hr();

print &ui_form_start("backup.cgi/firewall.zip", "post");
print &ui_table_start($text{'backup_header'}, undef, 2);

# Show destination
my ($mode, @dest) = &parse_backup_dest($config{'backup_dest'});

my $tx = "";
$tx = "<table cellpadding=0 cellspacing=0 style='padding:0;margin:0;'>";
$tx .= "<tr><td>".&ui_oneradio("dest_mode", 0, undef, ($mode == 0 ? 1 : 0) )."</td>";
$tx .= "<td colspan='4'>".$text{'backup_dest0'}."</td></tr>";

$tx .= "<tr><td>".&ui_oneradio("dest_mode", 1, undef, ($mode == 1 ? 1 : 0) )."</td>";
$tx .= "<td>".$text{'backup_dest1'}."&nbsp;</td>";
$tx .= "<td colspan=3>".&ui_filebox("dest",($mode == 1 ? $dest[0] : ""),40)."</td></tr>";

$tx .= "<tr><td>".&ui_oneradio("dest_mode", 3, undef, ($mode == 3 ? 1 : 0) )."</td>";
$tx .= "<td>".$text{'backup_dest3'}."&nbsp;</td>";
$tx .= "<td colspan=3>".&ui_textbox("email",($mode == 3 ? $dest[0] : ""),40)."</td></tr>"; 

$tx .= "<tr><td>".&ui_oneradio("dest_mode", 2, undef, ($mode == 2 ? 1 : 0) )."</td>";
$tx .= "<td>".$text{'backup_dest2'}."&nbsp;</td>";
$tx .= "<td>".&ui_textbox("ftphost",($mode == 2 ? $dest[2] : ""),20)."</td>";
$tx .= "<td>&nbsp;".$text{'backup_ftpfile'}."</td>";
$tx .= "<td>".&ui_textbox("ftpfile",($mode == 2 ? $dest[3] : ""),20)."</td></tr>";

$tx .= "<tr><td>&nbsp;</td>";
$tx .= "<td>".$text{'backup_ftpuser'}."&nbsp;</td>";
$tx .= "<td>".&ui_textbox("ftpuser",($mode == 2 ? $dest[0] : ""),20)."</td>";
$tx .= "<td>&nbsp;".$text{'backup_ftppass'}."&nbsp;</td>";
$tx .= "<td>".&ui_password("ftppass",($mode == 2 ? $dest[1] : ""),20)."</td></tr>";
$tx .= "</table>";

print &ui_table_row($text{'backup_dest'}, $tx);

# Show password
print &ui_table_row($text{'backup_pass'},
                    &ui_radio("pass_def",($config{'backup_pass'} ? 0 : 1),[
                                [1,$text{'backup_nopass'}],[0, &ui_password("pass", $config{'backup_pass'},20) ]
                                ])
                ,undef, ["valign=middle","valign=middle"]);

# Show what to backup
my %what = map { $_, 1 } split(/\s+/, $config{'backup_what'});
$tx = "";
foreach my $w (@backup_opts) {
    $tx .= &ui_checkbox("what", $w, $text{$w."_title"}, ($what{$w} ? 1 : 0) )."<br>";
	}
if (defined(&select_all_link)) {
    $tx .= &ui_links_row([&select_all_link("what", 0), &select_invert_link("what", 0)]);
	}
print &ui_table_row($text{'backup_what'}, $tx, ["valign=top","valign=top"]);

# Show schedule
my $job = &find_backup_job();
my @sel;
foreach my $s ("hourly", "daily", "weekly", "monthly", "yearly") {
    push(@sel, [$s, ucfirst($s), ($job && $job->{'special'} eq $s ? "selected" : "") ] );
	}
print &ui_table_row($text{'backup_sched'},
                &ui_radio("sched_def",($job ? 0 : 1),[
                    [1,$text{'backup_nosched'}],[0,$text{'backup_interval'}]
                    ]).
                &ui_select("sched", undef, \@sel, 1)
        ,undef, ["valign=middle","valign=middle"]);

print &ui_table_end();
print "<p>";
print &ui_submit($text{'backup_ok'});
print &ui_submit($text{'backup_save'}, "save");
print &ui_form_end(undef,undef,1);

print &ui_hr();

&footer("", $text{'index_return'});

