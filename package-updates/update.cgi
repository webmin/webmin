#!/usr/local/bin/perl
# Update selected packages

require './package-updates-lib.pl';
&ReadParse();
if ($in{'redir'}) {
	$redir = $in{'redir'};
	$redirdesc = $in{'redirdesc'};
	}
elsif ($in{'redirdesc'}) {
	$redir = $ENV{'HTTP_REFERER'};
	$redirdesc = $in{'redirdesc'};
	}
else {
	$redir = "index.cgi?mode=".&urlize($in{'mode'}).
		 "&search=".&urlize($in{'search'});
	$redirdesc = $text{'index_return'};
	$redir = $redir =~ /tab=/ ? $redir :
		$redir =~ /\?/ ? "$redir&tab=pkgs" : "$redir?tab=pkgs";
	}

if ($in{'refresh'} || $in{'refresh_top'}) {
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
	&ui_print_unbuffered_header(undef,
	    $in{'mode'} eq 'new' ? $text{'update_title2'} : $text{'update_title'}, "");

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
		my $getconfform = sub {
			my ($bottom) = @_;
			my $bottom_sel;
			$bottom_sel = 'data-outside-of-viewport'
				if ($bottom);
			my $confform = &ui_form_start("update.cgi", "post", undef, $bottom_sel);
			$confform .= &ui_hidden("mode", $in{'mode'});
			$confform .= &ui_hidden("search", $in{'search'});
			$confform .= &ui_hidden("redir", $in{'redir'});
			$confform .= &ui_hidden("redirdesc", $in{'redirdesc'});
			foreach $ps (@pkgs) {
				$confform .= &ui_hidden("u", $ps);
				}
			$confform .= &text('update_rusure', scalar(@ops)),"<p>\n"
				if (!$bottom);
			$confform .= &ui_form_end([ [ "confirm", $text{'update_confirm'} ] ]);
			};
		print &$getconfform();

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
		print &$getconfform(1), &ui_hide_outside_of_viewport();
		}
	else {
		# Check if a reboot was required before
		$reboot_before = &check_reboot_required();

		# Do it
		$msg = $in{'mode'} eq 'new' ? 'update_pkg2' : 'update_pkg';
		&start_update_progress([ map { (split(/\//, $_))[0] } @pkgs ]);
		if ($config{'update_multiple'} && @pkgs > 1) {
			# Update all packages at once
			@pkgnames = ( );
			foreach my $ps (@pkgs) {
                                ($p, $s) = split(/\//, $ps);
				push(@pkgnames, $p);
				$pkgsystem ||= $s;
				}
			print &text($msg, "<tt>".&html_escape(join(" ", @pkgnames))."</tt>"),
			      "<br>\n";
			print "<ul data-package-updates='1'>\n";
			@got = &package_install_multiple(
				\@pkgnames, $pkgsystem, $in{'mode'} eq 'new', $in{'flags'});
			print "</ul><br>\n";
			}
		else {
			# Do them one by one in a loop
			foreach my $ps (@pkgs) {
				($p, $s) = split(/\//, $ps);
				next if ($donedep{$p});
				print &text($msg, "<tt>@{[&html_escape($p)]}</tt>"),"<br>\n";
				print "<ul data-package-updates='2'>\n";
				@pgot = &package_install(
					$p, $s, $in{'mode'} eq 'new', $in{'flags'});
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
		&end_update_progress(\@pkgs);

		# Refresh collected package info
		print $text{'refresh_available'},"<br>\n";
		if (&foreign_check("system-status")) {
			&foreign_require("system-status");
			&system_status::refresh_possible_packages(\@got);
			}

		# Refresh collected package info
		if (&foreign_check("virtual-server") && @got) {
			&foreign_require("virtual-server");
			&virtual_server::refresh_possible_packages(\@got);
			}
		print $text{'refresh_done'},"<p>\n";
		# Check if a reboot is required now
		if (!$reboot_before && &check_reboot_required() &&
		    &foreign_check("init")) {
			print &ui_form_start(
				"@{[&get_webprefix()]}/init/reboot.cgi");
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
