#!/usr/local/bin/perl
# Show a list of TCP ports Sendmail uses

require './sendmail-lib.pl';
$access{'ports'} || &error($text{'ports_ecannot'});
&ui_print_header(undef, $text{'ports_title'}, "");

# Get and parse current setting
$conf = &get_sendmailcf();
foreach $dpo (&find_options("DaemonPortOptions", $conf)) {
	local %opts;
	foreach $o (split(/\s*,\s*/, $dpo->[1])) {
		if ($o =~ /^([^=]+)=(\S+)$/) {
			$opts{$1} = $2;
			}
		}
	push(@ports, \%opts);
	}

# Show table of ports
print &ui_form_start("save_ports.cgi");
print &ui_radio("ports_def", @ports ? 0 : 1,
	[ [ 1, $text{'ports_def1'} ], [ 0, $text{'ports_def0'} ] ])."<p>\n";
print &ui_columns_start([
	$text{'ports_name'},
	$text{'ports_addr'},
	$text{'ports_port'},
	$text{'ports_opts'},
	], 100);
$i = 0;
@tds = ( "valign=top", "valign=top", "valign=top" );
@known_opts = ( 'Name', 'Address', 'Port', 'Modifiers', 'Family' );
foreach $p (@ports, { }) {
	@cols = ( );
	foreach $k (@known_opts) {
		$fk = substr($k, 0, 1);
		if ($p->{$fk} && !$p->{$k}) {
			# Using first letter abbreviation only
			$p->{$k} = $p->{$fk};
			delete($p->{$fk});
			}
		}
	if ($p->{'Addr'}) {
		# Some systems use 'Addr' instead of 'Address'
		$p->{'Address'} = $p->{'Addr'};
		delete($p->{'Addr'});
		}
	push(@cols, &ui_textbox("name_$i", $p->{'Name'}, 10));
	push(@cols, &ui_opt_textbox("addr_$i", $p->{'Address'}, 15,
				    $text{'ports_all'}, $text{'ports_ip'}).
		    "<br>\n".
		    $text{'ports_family'}." ".
		    &ui_select("family_$i", $p->{'Family'},
			       [ [ '', $text{'default'} ],
				 [ 'inet', $text{'ports_inet'} ],
				 [ 'inet6', $text{'ports_inet6'} ] ]));
	push(@cols, &ui_opt_textbox("port_$i", $p->{'Port'}, 6,
				    $text{'default'}." (25)"));
	@mods = ( );
	foreach $m (@port_modifier_flags) {
		push(@mods, &ui_checkbox("mod_$i", $m, $text{'ports_mod_'.$m},
					 $p->{'Modifiers'} =~ /$m/));
		}
	push(@cols, &ui_grid_table(\@mods, 2));
	print &ui_columns_row(\@cols, \@tds);

	# Hidden field for other settings
	foreach $k (@known_opts) {
		delete($p->{$k});
		}
	print &ui_hidden("other_$i",
		join(",", map { $_."=".$p->{$_} } keys %$p));
	$i++;
	}
print &ui_columns_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

