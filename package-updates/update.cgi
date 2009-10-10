#!/usr/local/bin/perl
# Update selected packages

require './package-updates-lib.pl';
&ReadParse();
$redir = "index.cgi?mode=".&urlize($in{'mode'}).
	 "&search=".&urlize($in{'search'});

if ($in{'refresh'}) {
	&ui_print_unbuffered_header(undef, $text{'refresh_title'}, "");

	# Clear all caches
	print $text{'refresh_clearing'},"<br>\n";
	&flush_package_caches();
	&clear_repository_cache();
	print $text{'refresh_done'},"<p>\n";

	# Force re-fetch
	print $text{'refresh_available'},"<br>\n";
	@avail = &list_available();
	print &text('refresh_done2', scalar(@avail)),"<p>\n";

	&webmin_log("refresh");
	&ui_print_footer($redir, $text{'index_return'});
	}
else {
	# Upgrade some packages
	my @pkgs = split(/\0/, $in{'u'});
	@pkgs || &error($text{'update_enone'});
	&ui_print_unbuffered_header(undef, $text{'update_title'}, "");

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
		# Do it
		foreach my $ps (@pkgs) {
			($p, $s) = split(/\//, $ps);
			next if ($donedep{$p});
			print &text('update_pkg', "<tt>$p</tt>"),"<br>\n";
			print "<ul>\n";
			@pgot = &package_install($p, $s);
			foreach $g (@pgot) {
				$donedep{$g}++;
				}
			push(@got, @pgot);
			print "</ul><br>\n";
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

		&webmin_log("update", "packages", scalar(@got),
			    { 'got' => \@got });
		}

	&ui_print_footer($redir, $text{'index_return'});
	}
