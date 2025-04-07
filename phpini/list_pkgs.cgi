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
				      $vmap ? (
					$text{'pkgs_shortver'},
					$text{'pkgs_users'} ) : ( ),
			        ], \@tds);
	foreach my $pkg (@pkgs) {
		my $users;
		if ($vmap) {
			my $ulist = $vmap->{$pkg->{'shortver'}};
			$users = !$ulist || !@$ulist ? $text{'pkgs_nousers'} :
				 @$ulist > 5 ? &text('pkgs_ucount',
						     scalar(@$ulist)) :
				    join(", ", map { "<tt>$_->{'dom'}</tt>" }
						   @$ulist);
			}
		print &ui_checked_columns_row([
			$pkg->{'name'},
			$pkg->{'ver'},
			$pkg->{'phpver'},
			$vmap ? ( $pkg->{'shortver'}, $users ) : ( ),
			], \@tds, "d", $pkg->{'name'});
		$got{$pkg->{'name'}}++;
		}
	print &ui_columns_end();
	print &ui_form_end([ [ undef, $text{'pkgs_delete'} ] ]);
	}
else {
	print "<b>$text{'pkgs_none'}</b> <p>\n";
	}

if (&foreign_installed("package-updates")) {
	# Show form to install a new version
	@newpkgs = grep { !$got{$_->{'name'}} } &list_available_php_packages();
	print &ui_hr();
	print &ui_form_start(
		&get_webprefix()."/package-updates/update.cgi", "post");
	print "<b>$text{'pkgs_newver'}</b>\n";
	print &ui_select("u", undef,
		[ map { [ $_->{'name'},
			  $_->{'name'}." (".$_->{'version'}.")" ] } @newpkgs ]);
	print &ui_hidden(
		"redir", &get_webprefix()."/$module_name/list_pkgs.cgi");
	print &ui_hidden("redirdesc", $text{'pkgs_title'});
	print &ui_hidden("mode", "new");
	print &ui_form_end([ [ undef, $text{'pkgs_install'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});
