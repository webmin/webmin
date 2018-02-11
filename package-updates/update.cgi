#!/usr/local/bin/perl
# Update selected packages

require './package-updates-lib.pl';
&ReadParse();
if ($in{'redir'}) {
	$redir = $in{'redir'};
	$redirdesc = $in{'redirdesc'};
	}
elsif ($in{'redirdesc'}) {
	$redir = "javascript:history.back()";
	$redirdesc = $in{'redirdesc'};
	}
else {
	$redir = "index.cgi?mode=".&urlize($in{'mode'}).
		 "&search=".&urlize($in{'search'});
	$redirdesc = $text{'index_return'};
	}

if ($in{'refresh'} || $in{refresh_top}) {
	&ui_print_unbuffered_header(undef, $text{'refresh_title'}, "");

	# Clear all caches
	print $text{'refresh_clearing'},"<br>\n";
	&flush_package_caches();
	&clear_repository_cache();
	print $text{'refresh_done'},"<p>\n";

	# Force re-fetch
	print $text{'refresh_available'},"<br>\n";
	@avail = &list_possible_updates();
	print &text('refresh_done3', scalar(@avail)),"<p>\n";

	&webmin_log("refresh");
	&ui_print_footer($redir, $redirdesc);
	}
else {
	# Upgrade some packages
	my @pkgs = split(/\0/, $in{'u'});
	@pkgs || &error($text{'update_enone'});
	&ui_print_unbuffered_header(undef, $text{'update_title'}, "");

	# Save this CGI from being killed by a webmin or apache upgrade
	$SIG{'TERM'} = 'IGNORE';
	$SIG{'PIPE'} = 'IGNORE';

	# Work out what will be done, if possible
	@ops = ( );
	if (!$in{'confirm'}) {
		print $text{'update_ops'},"<p>\n";
		@pkgnames = ( );
		foreach my $ps (@pkgs) {
			($p, $s) = split(/\//, $ps);
			push(@pkgnames, $p);
			}
		@ops = &list_package_operations(join(" ", @pkgnames), $s);
		}

	if (@ops) {
		# Ask first
		print &ui_form_start("update.cgi", "post");
		print &ui_hidden("mode", $in{'mode'});
		print &ui_hidden("search", $in{'search'});
		foreach $ps (@pkgs) {
			print &ui_hidden("u", $ps);
			}
		print &text('update_rusure', scalar(@ops)),"<p>\n";
		print &ui_form_end([ [ "confirm", $text{'update_confirm'} ] ]);

		# Show table of all depends
		@current = &list_current(1);
		print &ui_columns_start([ $text{'index_name'},
					  $text{'update_oldver'},
					  $text{'update_newver'},
					  $text{'index_desc'},
					], 100);
		foreach $p (@ops) {
			($c) = grep { $_->{'name'} eq $p->{'name'} &&
				    $_->{'system'} eq $p->{'system'} } @current;
			if (!$c && !@avail) {
				# Only get available if needed
				@avail = &list_available(0);
				}
			($a) = grep { $_->{'name'} eq $p->{'name'} &&
				    $_->{'system'} eq $p->{'system'} } @avail;
			print &ui_columns_row([
				$p->{'name'},
				$c ? $c->{'version'}
				   : "<i>$text{'update_none'}</i>",
				$p->{'version'},
				$c ? $c->{'desc'} :
				  $a ? $a->{'desc'} : '',
				]);
			}
		print &ui_columns_end();
		}
	else {
		# Check if a reboot was required before
		$reboot_before = &check_reboot_required(0);

		# Do it
		$msg = $in{'mode'} eq 'new' ? 'update_pkg2' : 'update_pkg';
		if ($config{'update_multiple'} && @pkgs > 1) {
			# Update all packages at once
			@pkgnames = ( );
			foreach my $ps (@pkgs) {
                                ($p, $s) = split(/\//, $ps);
				push(@pkgnames, $p);
				$pkgsystem ||= $s;
				}
			print &text($msg, "<tt>".join(" ", @pkgnames)."</tt>"),
			      "<br>\n";
			print "<ul>\n";
			@got = &package_install_multiple(\@pkgnames,
							 $pkgsystem);
			print "</ul><br>\n";
			}
		else {
			# Do them one by one in a loop
			foreach my $ps (@pkgs) {
				($p, $s) = split(/\//, $ps);
				next if ($donedep{$p});
				print &text($msg, "<tt>$p</tt>"),"<br>\n";
				print "<ul>\n";
				@pgot = &package_install($p, $s);
				foreach $g (@pgot) {
					$donedep{$g}++;
					}
				push(@got, @pgot);
				print "</ul><br>\n";
				}
			}
		if (@got) {
			print &text('update_ok', scalar(@got)),"<p>\n";
			}
		else {
			print $text{'update_failed'},"<p>\n";
			}

		# Refresh collected package info
		if (&foreign_check("system-status")) {
			&foreign_require("system-status");
			&system_status::refresh_possible_packages(\@got);
			}

		# Refresh collected package info
		if (&foreign_check("virtual-server") && @got) {
			&foreign_require("virtual-server");
			&virtual_server::refresh_possible_packages(\@got);
			}

		# Check if a reboot is required now
		if (!$reboot_before && &check_reboot_required(1) &&
		    &foreign_check("init")) {
			print &ui_form_start(
				"$gconfig{'webprefix'}/init/reboot.cgi");
			print &ui_hidden("confirm", 1);
			print "<b>",$text{'update_rebootdesc'},"</b><p>\n";
			print &ui_form_end(
				[ [ undef, $text{'update_reboot'} ] ]);
			}

		&webmin_log("update", "packages", scalar(@got),
			    { 'got' => \@got });
		}

	&ui_print_footer($redir, $redirdesc);
	}
