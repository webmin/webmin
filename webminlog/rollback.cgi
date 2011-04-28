#!/usr/local/bin/perl
# rollback.cgi
# Revert all changed config files, after asking for confirmation

use strict;
use warnings;
require './webminlog-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $act = &get_action($in{'id'});

if ($in{'annosave'}) {
	# Just saving an annotation
	$in{'anno'} =~ s/\r//g;
	&save_annotation($act, $in{'anno'});
	&redirect("view.cgi?id=$in{'id'}&search=".&urlize($in{'search'}));
	exit;
	}

$access{'rollback'} ||  &error($text{'rollback_ecannot'});
&can_user($act->{'user'}) || &error($text{'view_ecannot'});
&can_mod($act->{'module'}) || &error($text{'view_ecannot'});
my %r = map { $_, 1 } split(/\0/, $in{'r'});
%r || &error($text{'rollback_enone'});
my @files = grep { $r{$_->{'file'}} } &list_files($act);

&ui_print_header(undef, $text{'rollback_title'}, "");
if ($in{'confirm'}) {
	# Do it!
	my %done;
	foreach my $f (@files) {
		next if ($done{$f->{'file'}});
		if (-d $f->{'file'} || $f->{'type'} == 1) {
			# Skip directory
			print &text('rollback_skipdir',"<tt>$f->{'file'}</tt>");
			}
		elsif (-l $f->{'file'} && $f->{'type'} == 2 ||
		       !-e $f->{'file'} && $f->{'type'} == 2 ||
		       !-l $f->{'file'} && $f->{'type'} == 2) {
			# Modify or create link
			&lock_file($f->{'file'});
			&unlink_file($f->{'file'});
			&symlink_file($f->{'data'}, $f->{'file'});
			&unlock_file($f->{'file'});
			print &text('rollback_madelink',
				    "<tt>$f->{'file'}</tt>",
				    "<tt>$f->{'data'}</tt>");
			}
		elsif (-e $f->{'file'} && -l $f->{'file'} &&
		       $f->{'type'} == 0) {
			# Remove link and create file
			&lock_file($f->{'file'});
			&unlink_file($f->{'file'});
			my $fh;
			&open_tempfile($fh, ">$f->{'file'}");
			&print_tempfile($fh, $f->{'data'});
			&close_tempfile($fh);
			&unlock_file($f->{'file'});
			print &text('rollback_madefile',
				    "<tt>$f->{'file'}</tt>");
			}
		elsif ($f->{'type'} == -1) {
			if (-e $f->{'file'}) {
				# Remove file
				&unlink_logged($f->{'file'});
				print &text('rollback_deleted',
					    "<tt>$f->{'file'}</tt>");
				}
			else {
				print &text('rollback_nodeleted',
					    "<tt>$f->{'file'}</tt>");
				}
			}
		else {
			# Replace file with old contents
			my $fh;
			&open_lock_tempfile($fh, ">$f->{'file'}");
			&print_tempfile($fh, $f->{'data'});
			&close_tempfile($fh);
			print &text('rollback_modfile',
				    "<tt>$f->{'file'}</tt>");
			}
		print "<br>\n";
		$done{$f->{'file'}}++;
		}
	my %minfo = &get_module_info($act->{'module'});
	&webmin_log("rollback", undef, $in{'id'},
		    { 'desc' => &get_action_description($act),
		      'mdesc' => $minfo{'desc'} });
	}
else {
	# Show the user what will be done
	print &ui_form_start("rollback.cgi");
	print &ui_hidden("id", $in{'id'});
	print &ui_hidden("search", $in{'search'});
	foreach my $r (keys %r) {
		print &ui_hidden("r", $r);
		}
	print $text{'rollback_rusure'},"<p>\n";
	my %done;
	my $count = 0;
	foreach my $f (@files) {
		next if ($done{$f->{'file'}});
		print &ui_table_start("<tt>$f->{'file'}</tt>", "width=100%", 2);
		print "<tr> <td colspan=2>";
		if (-d $f->{'file'} || $f->{'type'} == 1) {
			# Is a directory
			print &text('rollback_isdir');
			}
		elsif (-l $f->{'file'} && $f->{'type'} == 2 ||
		       !-e $f->{'file'} && $f->{'type'} == 2) {
			# Was a link, and is one now
			my $lnk = readlink($f->{'file'});
			if (!-e $f->{'file'}) {
				print &text('rollback_clink', "<tt>$f->{'data'}</tt>");
				$count++;
				}
			elsif ($lnk ne $f->{'data'}) {
				print &text('rollback_link', "<tt>$f->{'data'}</tt>", "<tt>$lnk</tt>");
				$count++;
				}
			else {
				print &text('rollback_nolink');
				}
			}
		elsif (-e $f->{'file'} && -l $f->{'file'} &&
		       $f->{'type'} == 0) {
			# Was a file, but is now a link
			my $lnk = readlink($f->{'file'});
			print &text('rollback_makefile', "<tt>$lnk</tt>");
			print "<pre>$f->{'data'}</pre>";
			$count++;
			}
		elsif (!-l $f->{'file'} && $f->{'type'} == 2) {
			# Was a link, but is now a file
			print &text('rollback_makelink', "<tt>$f->{'data'}</tt>");
			$count++;
			}
		elsif ($f->{'type'} == -1) {
			# Was created
			if (-e $f->{'file'}) {
				print &text('rollback_delete',
					    "<tt>$f->{'file'}</tt>");
				$count++;
				}
			else {
				print &text('rollback_nodelete',
					    "<tt>$f->{'file'}</tt>");
				}
			}
		elsif (!-e $f->{'file'}) {
			# No longer exists
			print $text{'rollback_fillfile'};
			print "<pre>$f->{'data'}</pre>";
			$count++;
			}
		else {
			# Was a file, and is one now
			my $qnew = quotemeta($f->{'file'});
			my $temp = &transname();
			open(TEMP, ">$temp");
			print TEMP $f->{'data'};
			close(TEMP);
			my $out = &backquote_command("diff $qnew $temp");
			if ($out) {
				print $text{'rollback_changes'};
				print "<pre>$out</pre>";
				$count++;
				}
			else {
				print $text{'rollback_nochanges'};
				}
			}
		$done{$f->{'file'}}++;
		print "</td> </tr>\n";
		print &ui_table_end();
		print "<br>\n";
		}
	if ($count) {
		print &ui_form_end([ [ "confirm", $text{'rollback_ok'} ] ]);
		}
	else {
		print "<b>$text{'rollback_none'}</b>\n";
		print &ui_form_end();
		}
	}
&ui_print_footer("view.cgi?id=$in{'id'}&search=".&urlize($in{'search'}),
		  $text{'view_return'},
		 "", $text{'index_return'});


