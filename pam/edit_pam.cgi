#!/usr/local/bin/perl
# edit_pam.cgi
# Display the modules for some PAM service

require './pam-lib.pl';
&ReadParse();

&ui_print_header(undef, $text{'edit_title'}, "");
@pams = &get_pam_config();
$pam = $pams[$in{'idx'}];

print &ui_table_start($text{'edit_header'}, "width=100%", 2, [ "width=30%" ]);

# Service name
print &ui_table_row($text{'edit_name'},
		    "<tt>".&html_escape($pam->{'name'})."</tt>");

# Service description
$t = $text{'desc_'.$pam->{'name'}};
if ($pam->{'desc'} || $t) {
	print &ui_table_row($text{'edit_desc'}, $pam->{'desc'} || $t);
	}

# File
print &ui_table_row($text{'edit_file'},
	"<tt>$pam->{'file'}</tt>");

print &ui_table_end();

foreach $t ('auth', 'account', 'session', 'password') {
	# Start of section
	local @mods = grep { $_->{'type'} eq $t } @{$pam->{'mods'}};
	print &ui_form_start("edit_mod.cgi");
	print &ui_hidden_table_start($text{"edit_header_$t"}, "width=100%", 2,
				     $t, @mods ? 1 : 0);

	my $ptable;
	if (@mods) {
		@tds = ( "width=20%", "width=35%", "width=20%",
			 "width=20%", "width=5%" );
		$ptable .= &ui_columns_start([ $text{'edit_mod'},
					       $text{'edit_desc'},
					       $text{'edit_control'},
					       $text{'edit_args'},
					       $text{'edit_move'} ], 100, \@tds);
		foreach $m (@mods) {
			local $mn = $m->{'module'};
			$mn =~ s/^.*\///;
			local @cols;
			if ($m->{'control'} eq 'include') {
				# Included module
				push(@cols, &ui_link("edit_inc.cgi?".
				    "idx=".$pam->{'index'}."&midx=".$m->{'index'},
				    &text('edit_inc', "<tt>$mn</tt>")) );
				@rtds = ( "colspan=4", "width=5%" );
				}
			else {
				# Regular PAM module
				push(@cols, &ui_link("edit_mod.cgi?".
				    "idx=".$pam->{'index'}."&midx=".$m->{'index'}, $mn) );
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
				$mv .= &ui_link("move.cgi?idx=$pam->{'index'}&".
				       "midx=".$m->{'index'}."&down=1", "<img src='images/down.gif' border=0>");
				}
			if ($m eq $mods[0]) {
				$mv .= "<img src='images/gap.gif'>";
				}
			else {
				$mv .= &ui_link("move.cgi?idx=".$pam->{'index'}."&".
				       "midx=".$m->{'index'}."&up=1", "<img src='images/up.gif' border=0>");
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
	if (&include_style(\@pams) == 2) {
		$ptable .= &ui_submit($text{'edit_addinc'}, "inc");
		}

	print &ui_table_row(undef, $ptable, 2);
	print &ui_hidden_table_end();
	print &ui_form_end();
	}

# Show section for other includes
if (&include_style(\@pams) == 3) {
	@incs = grep { $_->{'include'} } @{$pam->{'mods'}};
	%inced = map { $_->{'include'}, 1 } @incs;
	print &ui_form_start("save_incs.cgi");
	print &ui_hidden("idx", $in{'idx'});
	print &ui_hidden_table_start($text{'edit_iheader'}, "width=100%", 2,
				     "incs", @incs ? 1 : 0);
	@grid = ( );
	foreach $p (sort { $a->{'name'} cmp $b->{'name'} } @pams) {
		$desc = $p->{'name'};
		$dstr = $p->{'desc'} || $text{'desc_'.$p->{'name'}};
		$desc .= " ($dstr)" if ($dstr);
		push(@grid, &ui_checkbox("inc", $p->{'name'}, $desc,
					 $inced{$p->{'name'}}));
		}
	print &ui_table_row(undef, &ui_grid_table(\@grid, 2), 2);
	print &ui_hidden_table_end();
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}

# Delete whole service form
print &ui_hr();
print &ui_form_start("delete_pam.cgi");
print &ui_hidden("idx", $in{'idx'});
print &ui_form_end([ [ undef, $text{'edit_delete'} ] ]);

&ui_print_footer("", $text{'index_return'});

