#!/usr/local/bin/perl

require './usermin-lib.pl';
$access{'assignment'} || &error($text{'acl_ecannot'});

@modules = &list_modules();
&read_file("$config{'usermin_dir'}/webmin.catnames", \%catnames);
&get_usermin_miniserv_config(\%miniserv);
&read_file("$miniserv{'root'}/lang/en", \%utext);
&read_file("$miniserv{'root'}/ulang/en", \%utext);

&ui_print_header(undef, $text{'assignment_title'}, undef);

print &ui_form_start("save_assignment.cgi", "post");
@grid = ( );
foreach (@modules){
    push(@grid, $_->{'desc'} || $_->{'dir'});
    push(@grid, &cats($_->{'dir'}, $_->{'category'}));
    }
print &ui_grid_table(\@grid, 4, 100, [ "valign=middle","valign=middle","valign=middle","valign=middle" ], undef, $text{'assignment_header'});
print &ui_form_end([ [ undef, $text{'assignment_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

sub cats {
    my $cats;
    my %cats;
    foreach (keys %utext) {
	next unless /^category_/;
	my $desc = $utext{$_};
	s/^category_//;
	$cats{$_} = $desc;
	}
    foreach (keys %catnames) {
	$cats{$_} = $catnames{$_};
	}
    return &ui_select($_[0], $_[1],
                [ map { [ $_, $cats{$_} ] }
                      sort { $cats{$a} cmp $cats{$b} } keys %cats ]);
}
