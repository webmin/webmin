#!/usr/local/bin/perl

require './webmin-lib.pl';

@modules = grep { check_os_support($_) } get_all_module_infos();
@modules = sort { $a->{'desc'} cmp $b->{'desc'} } @modules;
read_file("$config_directory/webmin.catnames", \%catnames);

ui_print_header(undef, $text{'assignment_title'}, undef);
print "$text{'assignment_desc'}<p>\n";
print ui_form_start("save_assignment.cgi", "post");
print ui_table_start($text{'assignment_header'});
foreach ( @modules ){
    $a++;
    print "<tr></tr>" if $a%2;
    print qq(<td>$_->{desc}</td><td>), cats($_->{dir}, $_->{category}), "</td>\n";
}

print ui_table_end();
print ui_form_end([ [ "save", $text{'assignment_ok'} ] ]);
ui_print_footer("", $text{'index_return'});

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
    foreach $c (sort { $cats{$a} cmp $cats{$b} } keys %cats) {
	$cats .= sprintf "<option value='%s' %s>%s\n",
			$c, $_[1] eq $c ? 'selected' : '', $cats{$c};
	}
    $cats = qq(<select name="$_[0]">$cats\n</select>\n);
}
