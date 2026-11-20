#!/usr/local/bin/perl
# Edit a Webmin module's settings, one section at a time.

BEGIN { push(@INC, "."); };
use WebminCore;
require './config-lib.pl';
&init_config();

if ($ENV{'CONTENT_TYPE'} =~ m!^multipart/form-data\b!i) {
	# Decode multipart form fields.
	&ReadParseMime();
	}
else {
	# Accept query strings and URL-encoded forms.
	&ReadParse();
	}

# Check module access before displaying its settings.
my $m = $in{'module'} || $ARGV[0];
my ($info, $mdir, $file) = &module_config_editor($m);
my $help = -r &help_file($m, "config_intro") ? [ "config_intro", $m ] : undef;

# Favorites use the module name from this span.
&ui_print_header(&text('config_dir', &ui_tag('span', $info->{'desc'})),
		 $text{'config_title'}, "", $help, 0, 1);

# Get the visible fields and section headings.
my $fields = &read_config_fields($file, $m, 1);
my @sections = @{$fields->{'sections'}};
my ($section, $next);
my $title = &text('config_header', $info->{'desc'});
my $custom = -r "$mdir/config_info.pl" && &foreign_defined($m, 'config_form');

if (@sections > 1) {
	# Default to the first section and wrap at either end.
	my $idx = &indexof($in{'section'}, map { $_->[0] } @sections);
	$idx = 0 if ($idx < 0);
	$idx += $in{'nprev'} ? -1 : $in{'nnext'} ? 1 : 0;
	$idx %= scalar(@sections);
	($section, $title) = @{$sections[$idx]};
	$in{'section'} = $section;
	$next = $sections[($idx + 1) % @sections]->[0];

	# Switching sections submits only the navigation form.
	print &ui_form_start("config.cgi");
	print &ui_hidden("module", $m), &hidden_config_cparams(\%in);
	my $select = &ui_select("section", $section, \@sections, 1, 0, 0, 0,
				"onChange='form.submit()'");
	if (defined(&theme_config_sections)) {
		# Let the theme render the section controls.
		print &theme_config_sections($select, $fields);
		}
	else {
		# Use Webmin's standard section controls.
		print $text{'config_section'}, " ", $select, " ",
		      &ui_submit($text{'config_change'}), " ",
		      &ui_submit($text{'config_nprev'}, "nprev"), " ",
		      &ui_submit($text{'config_nnext'}, "nnext");
		}
	print &ui_form_end();
	}

# Pass the current section and return parameters to the save handler.
print &ui_form_start("config_save.cgi", "post");
print &ui_hidden("module", $m), &hidden_config_cparams(\%in);
print &ui_hidden("section", $section);
if (defined($section)) {
	# Save and Next needs the destination section.
	print &ui_hidden("section_next", $next);
	}
print &ui_table_start($title, "width=100%", 2);

# Personal preferences override module settings and defaults.
my %newconfig;
my $defaults = "$mdir/config-$gconfig{'os_type'}";
&read_file(-r $defaults ? $defaults : "$mdir/config", \%newconfig);
&read_file("$config_directory/$m/config", \%newconfig);
&load_module_preferences($m, \%newconfig);

if ($custom) {
	# Let the module render its own fields.
	&foreign_call($m, "config_form", \%newconfig);
	}
else {
	# Build standard fields from config.info.
	&generate_config(\%newconfig, $fields, $m, undef, undef, $section);
	}
print &ui_table_end();

# Offer Save and Next only for paginated forms.
my @buttons = ( [ "save", $text{'save'} ] );
push(@buttons, [ "save_next", $text{'config_next'} ]) if (defined($section));
print &ui_form_end(\@buttons);

# Use the module's return label when available.
my %mtext = &load_language($m);
&ui_print_footer(
	&module_config_return($m, \%in,
			      $mtext{'index_return'} || $text{'index'}));
