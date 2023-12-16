# mod_log.pl

sub mod_log_directives
{
local $rv = [
	[ 'SystemLog', 0, 1, 'root', 1.16 ],
	[ 'ExtendedLog', 1, 1, 'virtual anon global', 1.16 ],
	[ 'LogFormat', 1, 1, 'root', 1.16 ]
	];
return &make_directives($rv, $_[0], "mod_log");
}

sub edit_SystemLog
{
return (2, $text{'mod_log_syslog'},
	&opt_input($_[0]->{'value'}, "SystemLog", $text{'mod_log_sysdef'}, 50,
		   &file_chooser_button("TransferLog")));
}
sub save_SystemLog
{
return &parse_opt("SystemLog", '^\/\S+$', $text{'mod_log_esyslog'});
}

sub edit_ExtendedLog
{
my $rv = &ui_columns_start([ $text{'mod_log_file'},
			     $text{'mod_log_cmd'},
			     $text{'mod_log_nick'} ]);
my $i = 0;
foreach my $l (@{$_[0]}, { }) {
	my @w = @{$l->{'words'}};
	my $elc = $w[1] && $w[2] ? join(" ", split(/,/, $w[1])) : "";
	$rv .= &ui_columns_row([
		&ui_textbox("ExtendedLog_t_$i", $w[0], 20),
		&ui_radio("ExtendedLog_cd_$i", $elc ? 0 : 1,
			  [ [ 1, $text{'mod_log_all'} ],
			    [ 0, &ui_textbox("ExtendedLog_c_$i", $elc, 15) ] ]),
		&ui_radio("ExtendedLog_fd_$i", $w[2] || $w[1] ? 0 : 1,
			  [ [ 1, $text{'default'} ],
			    [ 0, &ui_textbox("ExtendedLog_f_$i", $w[2] || $w[1], 15) ] ]),
		]);
	$i++;
	}
$rv .= &ui_columns_end();
return (2, $text{'mod_log_extended'}, $rv);
}
sub save_ExtendedLog
{
local @rv;
for($i=0; defined($in{"ExtendedLog_t_$i"}); $i++) {
	next if (!$in{"ExtendedLog_t_$i"});
	local @w = ( $in{"ExtendedLog_t_$i"} );
	if (!$in{"ExtendedLog_cd_$i"}) {
		$in{"ExtendedLog_fd_$i"} && &error($text{'mod_log_ecmdnick'});
		$in{"ExtendedLog_c_$i"} =~ /\S/ ||
			&error($text{'mod_log_ecmd'});
		push(@w, join(",", map { uc($_) }
			  split(/\s+/, $in{"ExtendedLog_c_$i"})));
		}
	if (!$in{"ExtendedLog_fd_$i"}) {
		$in{"ExtendedLog_f_$i"} =~ /^\S+$/ ||
			&error($text{'mod_log_enick'});
		push(@w, $in{"ExtendedLog_f_$i"});
		}
	push(@rv, join(" ", @w));
	}
return ( \@rv );
}

sub edit_LogFormat
{
my $rv = &ui_columns_start([ $text{'mod_log_nickname'},
			     $text{'mod_log_fmt'} ]);
my $i = 0;
foreach my $f (@{$_[0]}, { }) {
	my @w = @{$f->{'words'}};
	$rv .= &ui_columns_row([ &ui_textbox("LogFormat_n_$i", $w[0], 15),
				 &ui_textbox("LogFormat_f_$i", $w[1], 35) ]);
	$i++;
	}
$rv .= &ui_columns_end();
return (2, $text{'mod_log_format'}, $rv);
}
sub save_LogFormat
{
local @rv;
for($i=0; defined($in{"LogFormat_n_$i"}); $i++) {
	next if (!$in{"LogFormat_n_$i"});
	$in{"LogFormat_n_$i"} =~ /^\S+$/ || &error($text{'mod_log_enickname'});
	$in{"LogFormat_f_$i"} =~ /\S/ || &error($text{'mod_log_efmt'});
	$in{"LogFormat_f_$i"} =~ s/"/\\"/g;
	push(@rv, sprintf "%s \"%s\"", $in{"LogFormat_n_$i"},
				       $in{"LogFormat_f_$i"});
	}
return ( \@rv );
}

