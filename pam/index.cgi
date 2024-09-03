#!/usr/local/bin/perl
# index.cgi
# Display PAM services on the system

require './pam-lib.pl';
&ui_print_header(undef, $text{'index_title'}, undef, undef, 1, 1, 0,
	&help_search_link("pam", "man", "howto", "doc"));

@pams = sort { $a->{'name'} cmp $b->{'name'} } &get_pam_config();
if (!@pams) {
	print "<p>",&text('index_none', "<tt>$config{'pam_dir'}</tt>",
			  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

@links = ( &ui_link("create_form.cgi", $text{'index_add'}) );
print &ui_links_row(\@links);
$mid = int((@pams-1) / 2);
print "<table width=100%><tr> <td width=50% valign=top>\n";
&pam_table(@pams[0 .. $mid]);
print "</td> <td width=50% valign=top>\n";
&pam_table(@pams[$mid+1 .. $#pams]);
print "</td> </tr></table>\n";
print &ui_links_row(\@links);

&ui_print_footer("/", $text{'index'});

sub pam_table
{
print &ui_columns_start([ $text{'index_name'}, $text{'index_desc'} ], 100);
foreach $p (@_) {
	local $t = $text{'desc_'.$p->{'name'}};
	print &ui_columns_row([
		&ui_link("edit_pam.cgi?idx=".$p->{'index'},
			 &html_escape($p->{'name'}) ),
		&html_escape($p->{'desc'} || $t),
		]);
	}
print &ui_columns_end();
}

