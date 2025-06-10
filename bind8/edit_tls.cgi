#!/usr/local/bin/perl
# Show a form to edit or create a TLS key and cert

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'tls_ecannot'});
&supports_tls() || &error($text{'tls_esupport'});
&ReadParse();

# Get the TLS config being edited
my $tls;
if (!$in{'new'}) {
	my $conf = &get_config();
	my @tls = &find("tls", $conf);
	($tls) = grep { $_->{'values'}->[0] eq $in{'name'} } @tls;
	$tls || &error($text{'tls_egone'});
	}
else {
	$tls = { 'values' => [],
		 'members' => [] };
	}
my $mems = $tls->{'members'};

&ui_print_header(undef, $in{'new'} ? $text{'tls_title1'}
				   : $text{'tls_title2'}, "");

print &ui_form_start("save_tls.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("oldname", $in{'name'});
print &ui_table_start($text{'tls_header'}, undef, 2);

# Name of this key
print &ui_table_row($text{'tls_name'},
	&ui_textbox("name", $tls->{'values'}->[0], 30));

# Key file
print &ui_table_row($text{'tls_key'},
	&ui_filebox("key", &find_value("key-file", $mems), 60));

# Cert file
print &ui_table_row($text{'tls_cert'},
	&ui_filebox("cert", &find_value("cert-file", $mems), 60));

# CA cert file
my $ca = &find_value("ca-file", $mems);
print &ui_table_row($text{'tls_ca'},
	&ui_radio("ca_def", $ca ? 0 : 1,
		  [ [ 1, $text{'tls_ca_def'} ],
		    [ 0, &ui_filebox("ca", $ca, 60) ] ]));

print &ui_table_end();
print &ui_form_end(
	$in{'new'} ? [ [ undef, $text{'create'} ] ]
		   : [ [ undef, $text{'save'} ],
		       [ 'delete', $text{'delete'} ] ]
	);

&ui_print_footer("list_tls.cgi", $text{'tls_return'});
