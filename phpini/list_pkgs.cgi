#!/usr/local/bin/perl
# Show all installed PHP versions

require './phpini-lib.pl';
$access{'global'} || &error($text{'pkgs_ecannot'});
&foreign_available("software") || &error($text{'pkgs_ecannot2'});

&ui_print_header(undef, $text{'pkgs_title'}, "");

my @pkgs = &list_php_base_packages();
if (@pkgs) {
	my %vmap;
	if (&foreign_check("virtual-server")) {
		# Get the domain to PHP version map
		&foreign_require("virtual-server");
		foreach my $d (&virtual_server::list_domains()) {
			my $v = $d->{'php_fpm_version'} ||
				$d->{'php_version'};
			if ($v) {
				$vmap{$v} ||= [ ];
				push(@{$vmap{$v}}, $d);
				}
			}
		}
	my @tds = ( "width=5" );
	print &ui_form_start("delete_pkgs.cgi", "post");
	print &ui_columns_start([ "", $text{'pkgs_name'},
				      $text{'pkgs_ver'},
				      $text{'pkgs_phpver'},
				      $text{'pkgs_users'} ], \@tds);
	foreach my $pkg (@pkgs) {
		my $ulist = $vmap{$pkg->{'shortver'}};
		my $users = !$ulist || !@$ulist ? $text{'pkgs_nousers'} :
			    @$ulist > 5 ? &text('pkgs_ucount',scalar(@$ulist)) :
				join(", ", map { "<tt>$_->{'dom'}</tt>" } @$ulist);
		print &ui_checked_columns_row([
			$pkg->{'name'},
			$pkg->{'ver'},
			$pkg->{'phpver'},
			$users,
			], \@tds, "d", $pkg->{'name'});
		}
	print &ui_columns_end();
	print &ui_form_end([ [ undef, $text{'pkgs_delete'} ] ]);
	}
else {
	print "<b>$text{'pkgs_none'}</b> <p>\n";
	}

&ui_print_footer("", $text{'index_return'});
