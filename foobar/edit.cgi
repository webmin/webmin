#!/usr/bin/perl
# Show a form to create or edit a website

require 'foobar-lib.pl';
ReadParse();

# Show page header and get the site being edited
my $site;
if ($in{'new'}) {
	ui_print_header(undef, $text{'create_title'}, "");
	$site = { };
	}
else {
	ui_print_header(undef, $text{'edit_title'}, "");
	my @sites = list_foobar_websites();
	($site) = grep { $_->{'domain'} eq $in{'domain'} } @sites;
	}

# Generate form and inputs table start
print ui_form_start('save.cgi');
print ui_hidden('new', $in{'new'});
print ui_hidden('old', $in{'domain'});
print ui_table_start($text{'edit_header'}, undef, 2);

# Input for domain name
print ui_table_row($text{'edit_domain'},
	ui_textbox('domain', $site->{'domain'}, 40));

# Input for HTML directory
print ui_table_row($text{'edit_directory'},
	ui_filebox('directory', $site->{'directory'}, 40));

# Show buttons at the end of the form
print ui_table_end();
if ($in{'new'}) {
	print ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print ui_form_end([ [ undef, $text{'save'} ],
			    [ 'delete', $text{'delete'} ] ]);
	}


ui_print_footer('', $text{'index_return'});

