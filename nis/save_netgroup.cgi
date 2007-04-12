#!/usr/local/bin/perl
# save_netgroup.cgi
# Create, update or delete a netgroup

require './nis-lib.pl';
&ReadParse();

($t, $lnums, $netgroup) = &table_edit_setup($in{'table'}, $in{'line'}, '\s+');
if ($in{'delete'}) {
	# Just delete the netgroup
	&table_delete($t, $lnums);
	}
else {
	# Validate inputs and save the netgroup
	&error_setup($text{'netgroup_err'});
	$in{'name'} =~ /^[A-Za-z0-9\.\-]+$/ || &error($text{'netgroup_ename'});
	@netgroup = ( $in{'name'} );
	HOST: for($i=0; defined($in{"host_$i"}); $i++) {
		local @h;
		foreach $v ('host', 'user', 'dom') {
			if ($in{"${v}_def_$i"} == 1) { push(@h, ""); }
			elsif ($in{"${v}_def_$i"} == 2) { next HOST; }
			elsif ($in{"${v}_$i"} !~ /^\S+$/) {
				&error(&text("netgroup_e$v", $i+1));
				}
			else { push(@h, $in{"${v}_$i"}); }
			}
		push(@netgroup, "($h[0],$h[1],$h[2])");
		}
	if ($in{'line'} eq '') {
		&table_add($t, "\t", \@netgroup);
		}
	else {
		&table_update($t, $lnums, "\t", \@netgroup);
		}
	}
&apply_table_changes() if (!$config{'manual_build'});
&redirect("edit_tables.cgi?table=$in{'table'}");

