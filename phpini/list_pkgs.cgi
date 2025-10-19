#!/usr/local/bin/perl
# Show all installed PHP versions

require './phpini-lib.pl';
$access{'global'} || &error($text{'pkgs_ecannot'});
&foreign_available("software") || &error($text{'pkgs_ecannot2'});

&ui_print_header(undef, $text{'pkgs_title'}, "");

my @pkgs = &list_php_base_packages();
my %got;
if (@pkgs) {
	my $vmap = &get_virtualmin_php_map();
	my @tds = ( "width=5" );
	print &ui_form_start("delete_pkgs.cgi", "post");
	print &ui_columns_start([ "", $text{'pkgs_name'},
				      $text{'pkgs_ver'},
				      $text{'pkgs_phpver'},
				      $text{'pkgs_bin'},
				      $vmap ? (
					$text{'pkgs_users'} ) : ( ),
			        ], \@tds);
	foreach my $pkg (@pkgs) {
		my $users;
		if ($vmap) {
			my $ulist = $vmap->{$pkg->{'shortver'}};
			my $details = 
				&ui_details({
				class => 'inline',
				html => 1,
				title => &text('pkgs_ucount', scalar(@$ulist)),
				content => join("<br>",
				    map { "<tt>$_->{'dom'}</tt>" } @$ulist)});
			$users = !$ulist || !@$ulist ? $text{'pkgs_nousers'} :
				 $details;
			}
		print &ui_checked_columns_row([
			$pkg->{'name'},
			$pkg->{'ver'},
			$pkg->{'phpver'},
			$pkg->{'binary'},
			$vmap ? ( $users ) : ( ),
			], \@tds, "d", $pkg->{'name'});
		$got{$pkg->{'phpver'}}++;
		}
	print &ui_columns_end();
	print &ui_form_end([ [ undef, $text{'pkgs_delete'} ] ]);
	}
else {
	print "<b>$text{'pkgs_none'}</b> <p>\n";
	}
if (&foreign_installed("package-updates")) {
	my @newpkgs = grep { !$got{$_->{'phpver'}} }
		&list_best_available_php_packages();
	# Show form to install a new version
	if (@newpkgs) {
		print &ui_hr();
		print &ui_form_start(
			&get_webprefix()."/package-updates/update.cgi", "post");
		print "$text{'pkgs_newver'}&nbsp;\n";
		my @allpkgs = &extend_installable_php_packages(\@newpkgs);
		@allpkgs = sort { $b->{'ver'} cmp $a->{'ver'} } @allpkgs;
		print &ui_select("u", undef,
			[ map { [ $_->{'name'},
				"PHP $_->{'ver'}" ] } @allpkgs ]);
		print &ui_hidden(
			"redir", &get_webprefix()."/$module_name/list_pkgs.cgi");
		print &ui_hidden("redirdesc", $text{'pkgs_title'});
		print &ui_hidden("mode", "new");
		print &ui_submit($text{'pkgs_setup'});
		print &ui_form_end();
		}
	}

&ui_print_footer("", $text{'index_return'});
