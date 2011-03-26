#!/usr/bin/perl
# save_group.cgi
# Create, update or delete a host group

require './itsecur-lib.pl';

sub check_ip_in_groups{
  my $my_group;
}

&can_edit_error("groups");
&ReadParse();
@groups = &list_groups();
if (!$in{'new'}) {
	$group = $groups[$in{'idx'}];
	}
&lock_itsecur_files();

if ($in{'delete'}) {
	# Check if in use
	&error_setup($text{'group_err2'});
	@rules = &list_rules();
	foreach $r (@rules) {
		&error($text{'group_einuse'})
			if ($r->{'source'} =~ /\@\Q$group->{'name'}\E/ ||
			    $r->{'dest'} =~ /\@\Q$group->{'name'}\E/);
		}
	local @maps;		
   ($iface, @nets) = &get_nat();
 	@maps = grep { ref($_) } @nets;
	@nets = grep { !ref($_) } @nets;		
   
	local ($net,$local_net);
	foreach $net (@nets) {
		$local_net = $net;
		$local_net =~ s/^\!//;
		&error($text{'group_in_use_nat'})
			if ($local_net eq $group->{'name'} );
		}
	local ($m);
	foreach $m (@maps) {
		&error($text{'group_in_use_nat'})
			if (@$m->[1] eq $group->{'name'} );
		}
	
	local $g;
	foreach $g (@groups) {
		next if ($g eq $group);
		foreach $m (@{$g->{'members'}}) {
			
			&error($text{'group_in_use_group'}." $g->{name}")
					if ($m eq "\@$group->{'name'}" );
		}
	}	

	# Just delete this group
	splice(@groups, $in{'idx'}, 1);
	#&automatic_backup();
	#TODO: Delete from other groups !!
	}
else {
	# Validate inputs
	&error_setup($text{'group_err'});
	$in{'name'} =~ /^\S+$/ || &error($text{'group_ename'});
	if ($in{'new'} || $in{'name'} ne $group->{'name'}) {
		# Check for clash
		($clash) = grep { lc($_->{'name'}) eq lc($in{'name'}) } @groups;
		$clash && &error($text{'group_eclash'});
		}
	for($i=0; defined($in{"member_$i"}); $i++) {
		next if (!$in{"member_$i"});
		local $ht = &valid_host($in{"member_$i"});
		$ht || &error(&text('group_emember', $in{"member_$i"}));
		if ($ht == 2 && $in{'resolv'}) {
			local $rs = &to_ipaddress($in{"member_$i"});
			$in{"member_$i"} = $rs if ($rs);
			}
		if ($ht == 4 && $in{"neg_$i"}) {
			&error(&text('group_eneg', $in{"member_$i"}));
			}
		push(@members, $in{"neg_$i"}.$in{"member_$i"});
		}
	for($i=0; defined($in{"group_$i"}); $i++) {
		next if (!$in{"group_$i"});
		$in{"group_$i"} eq $in{'name'} &&
			&error($text{'group_eself'});
		push(@members, "@".$in{"group_$i"});
		}
	@members || &error($text{'group_emembers'});
	$oldname = $group->{'name'};
	$group->{'name'} = $in{'name'};
	$group->{'members'} = \@members;

	if ($in{'new'}) {
		push(@groups, $group);
		}
	#@sorted = sort { $a cmp $b } @groups; 
	#@sorted = sort @groups; 
        #@groups = @sorted; 
	if (!$in{'new'} && $oldname ne $group->{'name'}) {
		# Has been re-named .. update all rules!
		@rules = &list_rules();
		foreach $r (@rules) {
			$r->{'source'} =~ s/\@\Q$oldname\E$/\@$group->{'name'}/;
			$r->{'dest'} =~ s/\@\Q$oldname\E$/\@$group->{'name'}/;
			}
		&save_rules(@rules);

		# And update all other groups
		foreach $g (@groups) {
			next if ($g eq $group);
			foreach $m (@{$g->{'members'}}) {
				$m = "\@$group->{'name'}"
					if ($m eq "\@$oldname");
				}
			}
		local @maps;		
		($iface, @nets) = &get_nat();
		@maps = grep { ref($_) } @nets;
		@nets = grep { !ref($_) } @nets;		
		local ($m,$net);

		foreach $net (@nets) {
			if ($net eq "$oldname") {
				$net = "$group->{'name'}";
				} elsif ($net eq "!$oldname") {
			   $net = "!$group->{'name'}";
				}
			}
		foreach $m (@maps) {
			if (@$m->[1] eq "$oldname") {
				@$m->[1] = "$group->{'name'}";
				} 
			}			
		&save_nat($iface, @nets, @maps);      
		}
	}

&save_groups(@groups);
$from = $in{'from'} || "groups";
&unlock_itsecur_files();
&remote_webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "update",
	    "group", $group->{'name'}, $group);
&redirect("list_${from}.cgi");

