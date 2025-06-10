#!/usr/local/bin/perl
# Delete one or more subnets or shared networks

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
&error_setup($text{'sdelete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'sdelete_enone'});
%access = &get_module_acl();

# Work out what is being done
&lock_all_files();
$parent = &get_parent_config();
foreach $d (@d) {
	local ($idx, $pidx) = split(/\//, $d);
	local $par = $parent;
	if ($pidx ne "") {
		# Under a shared network
		$par = $par->{'members'}->[$pidx];
		}
	$del = $par->{'members'}->[$idx];
	&error("$text{'eacl_np'} $text{'eacl_pds'}")
		if !&can('rw', \%access, $del, 1);
	next if ($already{$par});	# don't delete subnet if parent is being
	push(@deleting, [ $par, $del ]);
	$already{$del}++;
	$subnet_count++ if ($del->{'name'} eq 'subnet');
	$shared_count++ if ($del->{'name'} eq 'shared-network');
	}

if ($in{'confirm'}) {
	# Do it!
	foreach $pardel (@deleting) {
		&save_directive($pardel->[0], [ $pardel->[1] ], [ ], 0);
		}
	&flush_file_lines();
	&unlock_all_files();
	&webmin_log("delete", "subnets", scalar(@d));
	&redirect("");
	}
else {
	# Ask first
	&ui_print_header(undef, $text{'sdelete_title'}, "");

	print "<center>\n";
	print &ui_form_start("delete_subnets.cgi", "post");
	foreach $d (@d) {
		print &ui_hidden("d", $d),"\n";
		}
	$msg = $subnet_count && $shared_count ? 'sdelete_rusure1' :
	       $subnet_count ? 'sdelete_rusure2' : 'sdelete_rusure3';
	print &text($msg, $subnet_count, $shared_count),"<p>\n";
	print &ui_form_end([ [ "confirm", $text{'sdelete_ok'} ] ]);
	print "</center>\n";

	&ui_print_footer("", $text{'index_return'});
	}

