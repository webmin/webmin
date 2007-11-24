#!/usr/local/bin/perl
# edit_pam.cgi
# Display the modules for some PAM service

require './pam-lib.pl';
&ReadParse();

&ui_print_header(undef, $text{'edit_title'}, "");
@pams = &get_pam_config();
$pam = $pams[$in{'idx'}];

print &ui_table_start($text{'edit_header'}, "width=100%", 2);

$t = $text{'desc_'.$pam->{'name'}};
print &ui_table_row($text{'edit_name'},
	"<tt>".&html_escape($pam->{'name'})."</tt> ".
        ($pam->{'desc'} ? "($pam->{'desc'})" : $t ? "($t)" : ""));

foreach $t ('auth', 'account', 'session', 'password') {
	my $ptable;
	$ptable .= &ui_form_start("edit_mod.cgi");
	local @mods = grep { $_->{'type'} eq $t } @{$pam->{'mods'}};
	if (@mods) {
		@tds = ( "width=20%", "width=35%", "width=20%",
			 "width=20%", "width=5%" );
		$ptable .= &ui_columns_start([ $text{'edit_mod'},
					       $text{'edit_desc'},
					       $text{'edit_control'},
					       $text{'edit_args'},
					       $text{'edit_move'} ], \@tds);
		foreach $m (@mods) {
			local $mn = $m->{'module'};
			$mn =~ s/^.*\///;
			local @cols;
			if ($m->{'control'} eq 'include') {
				# Including some other file
				push(@cols, "<a href='edit_inc.cgi?".
				    "idx=$pam->{'index'}&midx=$m->{'index'}'>".
				    &text('edit_inc', "<tt>$mn</tt>")."</a>");
				@rtds = ( "colspan=4", "width=5%" );
				}
			else {
				# Regular PAM module
				push(@cols, "<a href='edit_mod.cgi?".
				    "idx=$pam->{'index'}&midx=$m->{'index'}'>".
				    "$mn</a>");
				push(@cols, $text{$mn});
				push(@cols, $text{'control_'.$m->{'control'}});
				push(@cols, $m->{'args'});
				@rtds = @tds;
				}
			local $mv;
			if ($m eq $mods[$#mods]) {
				$mv .= "<img src=images/gap.gif>";
				}
			else {
				$mv .= "<a href='move.cgi?idx=$pam->{'index'}&".
				       "midx=$m->{'index'}&down=1'><img ".
				       "src=images/down.gif border=0></a>";
				}
			if ($m eq $mods[0]) {
				$mv .= "<img src=images/gap.gif>";
				}
			else {
				$mv .= "<a href='move.cgi?idx=$pam->{'index'}&".
				       "midx=$m->{'index'}&up=1'><img ".
				       "src=images/up.gif border=0></a>";
				}
			push(@cols, $mv);
			$ptable .= &ui_columns_row(\@cols, \@rtds);
			}
		$ptable .= &ui_columns_end();
		}
	else {
		$ptable .= "<b>$text{'edit_none'}</b><p>\n";
		}

	# Form to add module
	$ptable .= &ui_hidden("idx", $in{'idx'});
	$ptable .= &ui_hidden("type", $t);
	$ptable .= &ui_submit($text{'edit_addmod'}),"\n";
	$ptable .= &ui_select("module", undef,
		[ map { [ $_, $text{$_} ? "$_ ($text{$_})" : $_ ] }
		      &list_modules() ]);
	$ptable .= "&nbsp;";
	$ptable .= &ui_submit($text{'edit_addinc'}, "inc");
	$ptable .= &ui_form_end();

	print &ui_table_row($text{"edit_header_$t"}, $ptable);
	}
print &ui_table_end();

# Delete whole service form
print &ui_form_start("delete_pam.cgi");
print &ui_hidden("idx", $in{'idx'});
print &ui_form_end([ [ undef, $text{'edit_delete'} ] ]);

&ui_print_footer("", $text{'index_return'});

