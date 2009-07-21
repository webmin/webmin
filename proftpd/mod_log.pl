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
local $rv = "<table border>\n".
	    "<tr $tb> <td><b>$text{'mod_log_file'}</b></td> ".
	    "<td><b>$text{'mod_log_cmd'}</b></td> ".
	    "<td><b>$text{'mod_log_nick'}</b></td> </tr>\n";
local $i = 0;
foreach $l (@{$_[0]}, { }) {
	local @w = @{$l->{'words'}};
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=ExtendedLog_t_$i size=20 value='$w[0]'></td>\n";
	$rv .= sprintf "<td><input name=ExtendedLog_cd_$i type=radio value=1 %s> %s\n", $w[1] && $w[2] ? "" : "checked", $text{'mod_log_all'};
	$rv .= sprintf "<input name=ExtendedLog_cd_$i type=radio value=0 %s>\n", $w[1] && $w[2] ? "checked" : "";
	$rv .= sprintf "<input name=ExtendedLog_c_$i size=15 value='%s'></td>\n", $w[1] && $w[2] ? join(" ", split(/,/, $w[1])) : "";
	$rv .= sprintf "<td><input name=ExtendedLog_fd_$i type=radio value=1 %s> %s\n", $w[2] || $w[1] ? "" : "checked", $text{'default'};
	$rv .= sprintf "<input name=ExtendedLog_fd_$i type=radio value=0 %s>\n", $w[2] || $w[1] ? "checked" : "";
	$rv .= sprintf "<input name=ExtendedLog_f_$i size=15 value='%s'></td>\n", $w[2] ? $w[2] : $w[1];
	$rv .= "</tr>\n";
	$i++;
	}
$rv .= "</table>\n";
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
local $rv = "<table border>\n".
	    "<tr $tb> <td><b>$text{'mod_log_nickname'}</b></td> ".
	    "<td><b>$text{'mod_log_fmt'}</b></td> </tr>\n";
local $i = 0;
foreach $f (@{$_[0]}, { }) {
	local @w = @{$f->{'words'}};
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=LogFormat_n_$i size=15 value='$w[0]'></td>\n";
	$rv .= "<td><input name=LogFormat_f_$i size=35 value='$w[1]'></td>\n";
	$rv .= "</tr>\n";
	$i++;
	}
$rv .= "</table>\n";
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

