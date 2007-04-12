# Common NIS server functions for Linux

# show_server_security()
# Show NIS server security-related options
sub show_server_security
{
local ($opts, $hosts) = &parse_ypserv_conf();

# Show port checking option
local $port = $opts->{'xfr_check_port'} ? $opts->{'xfr_check_port'}->{'value'}
					: 1;
print "<tr> <td><b>$text{'security_port'}</b></td>\n";
printf "<td><input type=radio name=port value=1 %s> %s\n",
	$port ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=port value=0 %s> %s</td> </tr>\n",
	$port ? '' : 'checked', $text{'no'};

# Work out if the new (with domains) or old format is in use
local ($newfmt) = grep { $_->{'domain'} } @$hosts;
print &ui_hidden("format", $newfmt ? 1 : 0),"\n";
local $table;
if ($newfmt) {
	# Generate new format table
	$table .= &ui_columns_start([ $text{'security_hosts'},
				      $text{'security_domain'},
				      $text{'security_map'},
				      $text{'security_sec'},
				      $text{'security_mangle'} ]);
	local $i = 0;
	foreach $h (@$hosts, { 'map' => '*' }) {
		local @cols;
		push(@cols, &ui_radio("host_def_$i", $h->{'host'} eq '*' ? 2 :
						     $h->{'host'} ? 0 : 1,
			[ [ 1, $text{'security_none'} ],
			  [ 2, $text{'security_any'} ],
			  [ 0, &ui_textbox("host_$i",
			$h->{'host'} eq '*' ? undef : $h->{'host'}, 20) ] ]));
		push(@cols, &ui_opt_textbox("domain_$i",
				$h->{'domain'} eq '*' ? undef : $h->{'domain'},
				20, $text{'security_tall'}));
		push(@cols, &ui_radio("map_def_$i", $h->{'map'} eq '*' ? 1 : 0,
		      [ [ 1, $text{'security_tall'} ],
			[ 0, &ui_textbox("map_$i", $h->{'map'} eq '*' ? undef :
							$h->{'map'}, 20) ] ]));
		push(@cols, &ui_select("sec_$i", $h->{'sec'},
			[ [ "none", $text{'security_sec_none'} ],
			  [ "port", $text{'security_sec_port'} ],
			  [ "deny", $text{'security_sec_deny'} ] ]));
		push(@cols, &ui_opt_textbox("mangle_$i",
				!$h->{'mangle'} ? undef :
				  $h->{'field'} ? $h->{'field'} : 2,
				5, $text{'security_none'}));
		$table .= &ui_columns_row(\@cols);
                $i++;
		}
	}
else {
	# Generate old format table
	$table .= &ui_columns_start([ $text{'security_hosts'},
				      $text{'security_map'},
				      $text{'security_sec'},
				      $text{'security_mangle'} ]);
	local $i = 0;
	foreach $h (@$hosts, { 'map' => '*' }) {
		local @cols;
		push(@cols, &ui_radio("host_def_$i", $h->{'host'} eq '*' ? 2 :
						     $h->{'host'} ? 0 : 1,
			[ [ 1, $text{'security_none'} ],
			  [ 2, $text{'security_any'} ],
			  [ 0, &ui_textbox("host_$i",
			$h->{'host'} eq '*' ? undef : $h->{'host'}, 20) ] ]));
		push(@cols, &ui_radio("map_def_$i", $h->{'map'} eq '*' ? 1 : 0,
		      [ [ 1, $text{'security_tall'} ],
			[ 0, &ui_textbox("map_$i", $h->{'map'} eq '*' ? undef :
							$h->{'map'}, 20) ] ]));
		push(@cols, &ui_select("sec_$i", $h->{'sec'},
			[ [ "none", $text{'security_sec_none'} ],
			  [ "port", $text{'security_sec_port'} ],
			  [ "deny", $text{'security_sec_deny'} ],
			  [ "des", $text{'security_sec_des'} ] ]));
		push(@cols, &ui_radio("mangle_$i", $h->{'mangle'} ? 1 : 0,
			[ [ 0, $text{'security_none'} ],
			  [ 1, &ui_textbox("field_$i", $h->{'field'}, 4) ] ]));
		$table .= &ui_columns_row(\@cols);
		$i++;
		}
	$table .= &ui_columns_end();
	}

print "<tr> <td colspan=2><b>$text{'security_maps'}</b><br>\n";
print "$table</td> </tr>\n";

print "</table></td> </tr>\n";
}

# parse_server_security()
# Save and apply server security options
sub parse_server_security
{
# Save security settings
local ($opts, $hosts) = &parse_ypserv_conf();
local $lref = &read_file_lines($ypserv_conf);
local $xfr = $opts->{'xfr_check_port'};
local $line = $in{'port'} ? 'xfr_check_port: yes' : 'xfr_check_port: no';
if ($xfr) {
	$lref->[$xfr->{'line'}] = $line;
	}
else {
	push(@$lref, $line);
	}

# Save host restrictions
local ($i, $j, $offset);
for($i=0; defined($in{"host_$i"}); $i++) {
	local @line;
	next if ($in{"host_def_$i"} == 1);
	$in{"host_def_$i"} == 2 || $in{"host_$i"} =~ /^[^:\s]+$/ ||
		 &error(&text('security_ehost', $in{"host_$i"}));
	$in{"map_def_$i"} || $in{"map_$i"} =~ /^[^:\s]+$/ ||
		&error(&text('security_emap', $in{"map_$i"}));
	if ($in{'format'} == 1) {
		# New format, including domain
		$in{"domain_${i}_def"} || $in{"domain_$i"} =~ /^[^:\s]+$/ ||
			&error(&text('security_edomain', $in{"domain_$i"}));
		$in{"mangle_${i}_def"} || $in{"mangle_$i"} =~ /^\d+$/ ||
			&error(&text('security_efield', $in{"mangle_$i"}));
		@line = ( $in{"host_def_$i"} == 2 ? "*" : $in{"host_$i"},
			  $in{"domain_${i}_def"} ? "*" : $in{"domain_$i"},
			  $in{"map_def_$i"} ? "*" : $in{"map_$i"},
			  $in{"sec_$i"}.
			    ($in{"mangle_${i}_def"} ? "" :
			     "/mangle:".$in{"mangle_$i"}) );
		}
	else {
		# Old format
		$in{"field_$i"} =~ /^\d*$/ ||
			&error(&text('security_efield', $in{"field_$i"}));
		@line = ( $in{"host_def_$i"} == 2 ? "*" : $in{"host_$i"},
			  $in{"map_def_$i"} ? "*" : $in{"map_$i"},
			  $in{"sec_$i"},
			  $in{"mangle_$i"} ? "yes" : "no" );
		push(@line, $in{"field_$i"})
			if ($in{"field_$i"} && $in{"field_$i"} != 2);
		}
	local $old = $hosts->[$j++];
	if ($old) {
		$lref->[$old->{'line'}] = join(":", @line);
		}
	else {
		push(@$lref, join(":", @line));
		}
	}
while($hosts->[$j]) {
	splice(@$lref, $hosts->[$j]->{'line'}-$offset, 1);
	$j++; $offset++;
	}
&flush_file_lines();

# Apply the changes
local $pid = &check_pid_file($pid_file);
&kill_logged('HUP', $pid) if ($pid);
}


