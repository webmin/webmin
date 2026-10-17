#!/usr/local/bin/perl
# Lists recently opened databases and offers to open or create another.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %config, %access);
require './sqlite-lib.pl';

# Show the library and driver versions under the page title.
my $driver_error = &sqlite_load_driver();
my ($library, $driver) = &sqlite_versions();
my $limit_error = $driver_error ? undef : &sqlite_result_limit_error();
&ui_print_header($library ? &text('index_version', $library, $driver) : undef,
	$text{'index_title'}, '', 'intro', 1);
# Without a usable driver, show the dependency or upgrade choices.
if ($driver_error || $limit_error) {
	my @needs;
	my $install_link;
	my $upgrade = $limit_error ? 1 : 0;
	# An installed driver without limit control needs an upgrade.
	if ($upgrade) {
		@needs = ( 'DBD::SQLite' );
		print &ui_tag('p', &text('index_olddriver',
			&html_escape($driver)));
		}
	else {
		# A missing driver may require DBI, DBD::SQLite or both.
		eval { require DBI; };
		# Include DBI only when its independent load check failed.
		push(@needs, 'DBI') if ($@);
		eval { require DBD::SQLite; };
		# Include the SQLite driver only when its load check failed.
		push(@needs, 'DBD::SQLite') if ($@);
		# The loader can fail for other reasons; then name the driver itself.
		@needs = ( 'DBD::SQLite' ) if (!@needs);
		print &ui_tag('p', &text(
			@needs > 1 ? 'index_nodrivers' : 'index_nodriver',
			join(', ', map { &ui_tag('tt', &html_escape($_)) } @needs)));
		}

	# Prefer native packages only for a missing driver. Reinstalling an old
	# native package would not add the required method.
	if (!$upgrade && &foreign_available('software')) {
		&foreign_require('software', 'software-lib.pl');
		my $packages = $software::update_system eq 'apt' ?
			'libdbi-perl libdbd-sqlite3-perl' :
			$software::update_system eq 'yum' ?
			'perl-DBI perl-DBD-SQLite' : undef;
		# Omit the link when this package manager has no known mapping.
		$install_link = &software::missing_install_link(
			$packages, $text{'index_driver_package'},
			'../sqlite/', $text{'index_return'}) if ($packages);
		}
	# Offer the native package installer when available.
	if ($install_link) {
		print $install_link;
		}
	elsif (&foreign_available('cpan')) {
		# Use Webmin's CPAN module when no suitable native package is available.
		print &ui_form_start('../cpan/download.cgi', 'get');
		print &ui_tag('p', $text{$upgrade ?
			'index_driver_cpan_upgrade' : 'index_driver_cpan'});
		print &ui_hidden('source', 3);
		print &ui_hidden('cpan', join(' ', @needs));
		print &ui_hidden('mode', 2);
		print &ui_hidden('return', '/sqlite/');
		print &ui_hidden('returndesc', $text{'index_return'});
		print &ui_form_end([ [ undef, $text{$upgrade ?
			'index_driver_update' : 'index_driver_install'} ] ]);
		}
	else {
		# Give manual instructions when Webmin cannot install the dependencies.
		print &ui_tag('p', $text{$upgrade ?
			'index_driver_upgrade_manual' : 'index_driver_manual'});
		}
	&ui_print_footer('/', $text{'index'});
	exit;
	}
print &ui_page_start();

my @recent = &sqlite_list_recent();
# List the databases this user opened last, newest first, when any.
if (@recent) {
	my @rows;
	foreach my $recent (@recent) {
		my ($name) = $recent->{'path'} =~ m!([^/]+)$!;
		# Size, table count and last-opened time make up the row
		# summary.
		my @meta = ( &nice_size($recent->{'size'}) );
		push(@meta, &html_escape($recent->{'tables'} == 1 ?
			$text{'index_table'} :
			&text('index_tables', $recent->{'tables'})))
			if (defined($recent->{'tables'}));
		push(@meta, &html_escape(&sqlite_recent_time($recent->{'time'})));
		# A small button under the summary forgets just this entry.
		push(@rows, {
			'title' => $name,
			'href' => 'database.cgi?db='.&urlize($recent->{'path'}),
			'icon' => 'database',
			'desc_html' => &ui_tag('tt', &html_escape($recent->{'path'})),
			'meta_html' => join(' &middot; ', grep { $_ ne '' } @meta),
			'actions' => &ui_action_button($text{'index_recent_remove'},
				'neutral', {
				'href' => 'forget_recent.cgi?db='.
					&urlize($recent->{'path'}),
				'size' => 'small' }),
			'chevron' => 1,
			});
		}
	print &ui_section_title($text{'index_recent'});
	print &ui_card({
		'flush' => 1,
		'body' => &ui_list(\@rows, {
			'flush' => 1, 'icon_box' => 1, 'stacked' => 1 }),
		});
	}

# Show a path field, file chooser and primary action. The field help explains
# when open.cgi can create a missing file.
my $can_create = &sqlite_can_create();
print &ui_form_start('open.cgi', 'post');
print &ui_card({
	'title' => @recent ? $text{'index_open_another'} : $text{'index_header'},
	'body' => &ui_stack([
		&ui_field($text{'index_path'},
			&ui_textbox('db', undef, 60, 0, undef, "placeholder='".
				&quote_escape($text{'index_path_example'})."'").
			" ".&file_chooser_button('db', 0),
			{ 'for' => 'db',
			  'help' => $can_create ?
				$text{'index_path_help_create'} :
				$text{'index_path_help'} }),
		&ui_cluster([
			&ui_action_button($text{'index_open'}, 'primary', {
				'type' => 'submit',
				'icon' => 'arrow-right',
				'icon_after' => 1 }),
			], { 'align' => 'end' }),
		], { 'gap' => '12px' }),
	});
print &ui_form_end();

print &ui_page_end();
&ui_print_footer('/', $text{'index'});
