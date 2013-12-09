#!/usr/local/bin/perl

require './webmin-lib.pl';

@modules = grep { &check_os_support($_) &&
		  !$_->{'hidden'} } &get_all_module_infos();
@modules = sort { $a->{'desc'} cmp $b->{'desc'} } @modules;
&read_file("$config_directory/webmin.catnames", \%catnames);

&ui_print_header(undef, $text{'assignment_title'}, undef);

print $text{'assignment_desc'},"<p>\n";

print &ui_form_start("save_assignment.cgi", "post");
@grid = ( );
foreach ( @modules ){
    push(@grid, $_->{'desc'} || $_->{'dir'});
    push(@grid, &cats($_->{'dir'}, $_->{'category'}));
    }
print &ui_grid_table(\@grid, 4, 100, [ "valign=middle","valign=middle","valign=middle","valign=middle" ], undef, $text{'assignment_header'});
print &ui_form_end([ [ undef, $text{'assignment_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});

sub cats {
    my $cats;
    my %cats;
    foreach (keys %text) {
	next unless /^category_/;
	my $desc = $text{$_};
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
