#!/usr/local/bin/perl
# Delete one or more hosts or groups

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
&error_setup($text{'hdelete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'hdelete_enone'});
%access = &get_module_acl();

# Work out what is being done
&lock_all_files();
$parent = &get_parent_config();
foreach $d (@d) {
	local @subs = reverse(split(/\//, $d));
	$idx = pop(@subs);
	local $par = $parent;
	foreach my $s (@subs) {
		if ($s ne "") {
			$par = $par->{'members'}->[$s];
			}
		}
	$del = $par->{'members'}->[$idx];
	&error("$text{'eacl_np'} $text{'eacl_pdh'}")
		if !&can('rw', \%access, $del, 1);
	next if ($already{$par});	# don't delete host if group is being
	push(@deleting, [ $par, $del ]);
	$already{$del}++;
	$host_count++ if ($del->{'name'} eq 'host');
	$group_count++ if ($del->{'name'} eq 'group');
	}

if ($in{'confirm'}) {
	# Do it!
	foreach $pardel (@deleting) {
		&save_directive($pardel->[0], [ $pardel->[1] ], [ ], 0);
		}
	&flush_file_lines();
	&unlock_all_files();
	&webmin_log("delete", "hosts", scalar(@d));
	&redirect("");
	}
else {
	# Ask first
	&ui_print_header(undef, $text{'hdelete_title'}, "");

	print "<center>\n";
	print &ui_form_start("delete_hosts.cgi", "post");
	foreach $d (@d) {
		print &ui_hidden("d", $d),"\n";
		}
	$msg = $host_count && $group_count ? 'hdelete_rusure1' :
	       $host_count ? 'hdelete_rusure2' : 'hdelete_rusure3';
	print &text($msg, $host_count, $group_count),"<p>\n";
	print &ui_form_end([ [ "confirm", $text{'hdelete_ok'} ] ]);
	print "</center>\n";

	&ui_print_footer("", $text{'index_return'});
	}

