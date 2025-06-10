#!/usr/local/bin/perl
# list_masq.cgi
# List domains for which masquerading is done

require './sendmail-lib.pl';
$access{'masq'} || &error($text{'masq_ecannot'});
&ui_print_header(undef, $text{'masq_title'}, "");
$conf = &get_sendmailcf();

# Get the domain we masquerade as
foreach $d (&find_type("D", $conf)) {
	if ($d->{'value'} =~ /^M\s*(\S*)/) { $masq = $1; }
	}

# Get masquerading domains
@mlist = &get_file_or_config($conf, "M");

# Get non-masqueraded domains
@nlist = &get_file_or_config($conf, "N");

# Introduction text
print &text('masq_desc1', 'list_generics.cgi'),"<p>\n";
print $text{'masq_desc2'},"<p>\n";


print &ui_form_start("save_masq.cgi", "form-data");
print &ui_table_start(undef, undef, 2);

# Masquerade as domain
print &ui_table_row($text{'masq_domain'},
	&ui_textbox("masq", $masq, 60));

# Domains to masquerade
print &ui_table_row($text{'masq_domains'},
	&ui_textarea("mlist", join("\n", @mlist), 8, 60));

# Domains to not masquerade
print &ui_table_row($text{'masq_ndomains'},
	&ui_textarea("nlist", join("\n", @nlist), 8, 60));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

