#!/usr/bin/perl
# Show a form for restoring some or all firewall objects

require './itsecur-lib.pl';
&can_edit_error("restore");
&check_zip();
&header($text{'restore_title'}, "",
	undef, undef, undef, undef, &apply_button());
print &ui_hr();

my ($mode, @dest) = &parse_backup_dest($config{'backup_dest'});

print &ui_form_start("restore.cgi", "form-data");
print &ui_table_start($text{'restore_header'}, undef, 2);

# Show source
print &ui_table_row($text{'restore_src'},
                &ui_radio("src_def",($mode == 1 ? 0 : 1),[
                    [1,$text{'restore_src1'}."&nbsp;".&ui_upload("file","",20)."<br>"],
                    [0,$text{'restore_src0'}."&nbsp;".&ui_filebox("src",($mode == 1 ? $dest[0] : ""),40)] 
                    ])
            ,undef, ["valign=top","valign=top"]);

# Show password
print &ui_table_row($text{'restore_pass'},
                    &ui_radio("pass_def",($config{'backup_pass'} ? 0 : 1),[
                                [1,$text{'backup_nopass'}],[0, &ui_password("pass", $config{'backup_pass'},20) ]
                                ])
                ,undef, ["valign=middle","valign=middle"]);

# Show what to restore
my %what = map { $_, 1 } split(/\s+/, $config{'backup_what'});
$tx = "";
foreach my $w (@backup_opts) {
    $tx .= &ui_checkbox("what", $w, $text{$w."_title"}, ($what{$w} ? 1 : 0) )."<br>";
	}
if (defined(&select_all_link)) {
    $tx .= &ui_links_row([&select_all_link("what", 0), &select_invert_link("what", 0)]);
	}
print &ui_table_row($text{'restore_what'}, $tx, ["valign=top","valign=top"]);

print &ui_table_end();
print "<p>";
print &ui_submit($text{'restore_ok'});
print &ui_form_end(undef,undef,1);

print &ui_hr();
&footer("", $text{'index_return'});

