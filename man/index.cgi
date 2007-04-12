#!/usr/local/bin/perl
# index.cgi
# Display the manual pages search form

require './man-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", $module_info{'usermin'} ? 0 : 1, 1);

# build list of available search options
@search = ( "man", "help" );
foreach $d (split(/\s+/, $config{'doc_dir'})) {
	if (-d $d) {
		push(@search, "doc");
		last;
		}
	}
foreach $h (split(/\s+/, $config{'howto_dir'})) {
	if (-d $h) {
		push(@search, "howto");
		last;
		}
	}
if (-d $config{'kde_dir'}) {
	push(@search, "kde");
	}
if (-d $config{'kernel_dir'}) {
	push(@search, "kernel");
	}
if ($perl_doc) {
	push(@search, "perl");
	}
if (-d $config{'custom_dir'}) {
        push(@search, "custom");
        }
push(@search, "google");

# display the search form
print "<form action=search.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'index_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'index_for'}</b></td>\n";
print "<td><input name=for size=30></td> </tr>\n";

print "<tr> <td></td>\n";
print "<td><input type=radio name=and value=1 checked> $text{'index_and'}\n";
print "<input type=radio name=and value=0> $text{'index_or'}</td> </tr>\n";

print "<tr> <td><b>$text{'index_type'}</b></td>\n";
print "<td><input type=radio name=exact value=1 checked> $text{'index_name'}\n";
print "<input type=radio name=exact value=0> $text{'index_data'}</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'index_where'}</b></td> <td>\n";
foreach $s (@search) {
	$txt = $text{"index_${s}"};
	$txt = $config{'custom_desc'}
		if ($s eq "custom" && $config{'custom_desc'});
	printf "<input type=checkbox name=section value=%s %s> %s<br>\n",
		$s, $s eq 'man' ? 'checked' : '', $txt;
	}
print "</td> </tr>\n";

print "<tr> <td colspan=2 align=right>",
      "<input type=submit value=\"$text{'index_search'}\">\n",
      "<input type=reset value=\"$text{'index_reset'}\"></td> </tr>\n";
print "</table></td></tr></table></form>\n";

if (!$module_info{'usermin'}) {
	@check = $config{'check'} ? split(/\s+/, $config{'check'}) : @search;
	print "<hr>\n";
	print "<form action=save_check.cgi>\n";
	printf "<input type=hidden name=count value=%d>\n", scalar(@search);
	print "<b>$text{'index_others'}</b><br>\n";
	print "<table width=100%>\n";
	foreach $s (@search) {
		print "<tr>\n" if ($c % 3 == 0);
		printf "<td><input type=checkbox name=check value=%s %s> %s</td>\n",
			$s, &indexof($s, @check) >= 0 ? 'checked' : '', 
			$text{"index_other_${s}"};
		print "<tr>\n" if ($c++ % 3 == 2);
		}
	print "</table>\n";
	print "<input type=submit value='$text{'save'}'></form>\n";
	}

&ui_print_footer("/", $text{'index'});

