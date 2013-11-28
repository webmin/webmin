#!/usr/local/bin/perl

require './usermin-lib.pl';
$access{'assignment'} || &error($text{'acl_ecannot'});

@modules = &list_modules();
&read_file("$config{'usermin_dir'}/webmin.catnames", \%catnames);
&get_usermin_miniserv_config(\%miniserv);
&read_file("$miniserv{'root'}/lang/en", \%utext);
&read_file("$miniserv{'root'}/ulang/en", \%utext);

&ui_print_header(undef, $text{'assignment_title'}, undef);
print qq(
$text{'assignment_desc'}<p>
<form action="save_assignment.cgi">
<table border><tr $tb>
<td><b>$text{'assignment_header'}</b></td></tr>
<tr $cb><td><table>
);
foreach ( @modules ){
    $a++;
    print "<tr></tr>" if $a%2;
    print qq(<td>$_->{desc}</td><td>), &cats($_->{dir}, $_->{'category'}), "</td>\n";
}

print qq(
</td></tr></table>
</td></tr></table>
<input type=submit value="$text{'assignment_ok'}">
</form>
);
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
    foreach $c (sort { $cats{$a} cmp $cats{$b} } keys %cats) {
	$cats .= sprintf "<option value='%s' %s>%s</option>\n",
			$c, $_[1] eq $c ? 'selected' : '', $cats{$c};
	}
    $cats = qq(<select name="$_[0]">$cats\n</select>\n);
}
