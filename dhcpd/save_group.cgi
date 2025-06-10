#!/usr/local/bin/perl
# save_group.cgi
# Update, create or delete a group

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
&lock_all_files();
($par, $group, $indent, $npar, $nindent) = get_branch('grp', $in{'new'});
$parconf = $par->{'members'};

# check acls
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
if ($in{'delete'}) {
	&error("$text{'eacl_np'} $text{'eacl_pdg'}")
		if !&can('rw', \%access, $group, 1);
	}
elsif ($in{'options'}) {
	&error("$text{'eacl_np'} $text{'eacl_psg'}")
		if !&can('r', \%access, $group);
	}
elsif ($in{'new'}) {
	&error("$text{'eacl_np'} $text{'eacl_pig'}")
		unless &can('c', \%access, $group) && 
				&can('rw', \%access, $par) &&
				(!$npar || &can('rw', \%access, $npar));
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_pug'}")
		unless !$npar || &can('rw', \%access, $npar);
	# for new and updated groups - per-host acls see below    
	}
# save
if ($in{'options'}) {
	# Redirect to client options
	&redirect("edit_options.cgi?sidx=$in{'sidx'}&uidx=$in{'uidx'}&idx=$in{'idx'}");
	exit;
	}
else {
	&error_setup($in{'delete'} ? $text{'sgroup_faildel'} :
				      $text{'sgroup_failsave'});

	# Move hosts into or out of this group
	@wasin = &find("host", $group->{'members'});
	foreach $hn (split(/\0/, $in{'hosts'})) {
		if ($hn =~ /(\d+),(\d+)/) {
			push(@nowin, $parconf->[$2]->{'members'}->[$1]);
			$nowpr{$parconf->[$2]->{'members'}->[$1]} =
				$parconf->[$2];
			}
		elsif ($hn =~ /(\d+),/) {
			push(@nowin, $parconf->[$1]);
			$nowpr{$parconf->[$1]} = $par;
			}
		if ($nowin[$#nowin]->{'name'} ne "host") {
			&error($text{'sgroup_echanged'});
			}
		}

	&error_setup($text{'eacl_aviol'});
	foreach $h (&unique(@wasin, @nowin)) {
		$was = &indexof($h, @wasin) != -1;
		$now = &indexof($h, @nowin) != -1;

		# per-host ACLs for new or updated hosts
		if ($was != $now && !&can('rw', \%access, $h)) {
			&error("$text{'eacl_np'} $text{'eacl_pug'}");
			}
		if ($was && !$now) {
			# Move out of the group
			&save_directive($group, [ $h ], [ ], $indent);
			&save_directive($par, [ ], [ $h ], $indent);
			}
		elsif ($now && !$was) {
			# Move into the group (maybe from another group)
			&save_directive($nowpr{$h}, [ $h ], [ ], $indent);
			&save_directive($group, [ ], [ $h ], $indent + 1);
			}
		}

	if (!$in{'delete'}) {
		# Validate and save inputs
		&save_choice("use-host-decl-names", $group, $indent+1);
		$group->{'comment'} = $in{'desc'};
		&parse_params($group, $indent+1);

		&error_setup($text{'sgroup_failsave'});
		@partypes = ( "", "shared-network", "subnet" );
		if (!$npar || $in{'assign'} > 0 && $npar->{'name'} ne $partypes[$in{'assign'}]) {
			if ($in{'jsquirk'}) {
				&error($text{'sgroup_invassign'});
				}
			else {
				&redirect("edit_group.cgi?assign=".$in{'assign'}.
					"&idx=".$in{'idx'}."&uidx=".$in{'uidx'}.
					"&sidx=".$in{'sidx'});
				exit;
				}
			}
		if ($in{'new'}) {
			# create this new group
			&save_directive($npar, [ ], [ $group ], $nindent);
			}
		elsif ($par eq $npar) {
			# update this group - is it really necessary ?
			&save_directive($par, [ $group ], [ $group ], $nindent);
			}
		else {
			# move this group
			&save_directive($par, [ $group ], [ ], 0);
			&save_directive($npar, [ ], [ $group ], $nindent);
			}
		}
	}
&flush_file_lines();
if ($in{'delete'}) {
	# Delete this group
	if ($in{'hosts'} eq "") {
		&save_directive($par, [ $group ], [ ], 0);
		&flush_file_lines();
		}
	else {
		&unlock_all_files();
		&redirect("confirm_delete.cgi?sidx=$in{'sidx'}&uidx=$in{'uidx'}".
			"&idx=$in{'idx'}=&type=2");
		exit;
		}
	}
&unlock_all_files();
@count = &find("host", $group->{'members'});
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'group', join(",", map { $_->{'values'}->[0] } @count), \%in);
if ($in{'ret'} eq "subnet") {
	$retparms = "sidx=$in{'sidx'}&idx=$in{'uidx'}";
	}
elsif ($in{'ret'} eq "shared") {
	$retparms = "idx=$in{'sidx'}";
	}
&redirect( $in{'ret'} ? "edit_$in{'ret'}.cgi?$retparms" : "");
