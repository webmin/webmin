#!/usr/bin/perl
# Render one database CGI with real UI helpers and isolated backend fixtures.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use JSON::PP;
use File::Temp qw(tempdir);

my ($root, $page, $json) = @ARGV;
my $case = decode_json($json);
my $module = $case->{'module'} || 'mysql';
my $name = $case->{'name'};
my $tmp = tempdir('webmin-mysql-escaping.XXXXXX', DIR => '/tmp', CLEANUP => 1);
require "$root/web-lib-funcs.pl";
require "$root/ui-lib.pl";
require "$root/mysql/view-lib.pl";
$INC{'./mysql-lib.pl'} = $INC{'./postgresql-lib.pl'} = 1;
chdir("$root/$module") or die $!;

for my $file ("$root/lang/en", "$root/$module/lang/en") {
	open(my $lang, '<', $file) or die $!;
	while (<$lang>) {
		$main::text{$1} = $2 if /^(\S+)=(.*)$/;
		}
	close($lang);
	}

# Load only pure helpers, bypassing module initialization and database access.
open(my $lib, '<', "$root/mysql/mysql-lib.pl") or die $!;
my $code = do { local $/; <$lib> };
close($lib);
for my $sub (qw(can_edit_db quotestr quote_table split_table show_table_form is_blob)) {
	$code =~ /(^sub \Q$sub\E\n\{.*?^\})/ms or die "Missing $sub";
	eval 'no strict; no warnings; '.$1;
	die $@ if $@;
	}

%main::in = ( db => $name, table => $name, fields => 1,
	where_def => 1, charset_def => 1, tables_def => 1, headers => 1,
	file => "$tmp/".($case->{'filename'} // $name), cols => $name,
	cmd => 'SELECT 1', %{$case->{'in'} || {}} );
%main::access = ( dbs => '*', buser => 'root', bpath => $tmp,
	views => 1, indexes => 1, delete => 1, %{$case->{'access'} || {}} );
%main::displayconfig = ( perpage => 2, style => 2,
	%{$case->{'display'} || {}} );
%main::config = ( mysqldump => $^X, mysqlimport => 'fixture-only' );
$main::module_name = $module;
$main::master_db = 'mysql';
$main::mysql_version = '8.0';
$main::mysql_login = $name;
$main::commands_file = "$tmp/history";
$main::max_dbs = 100;
@main::type_list = qw(int varchar text);
$main::driver_info = { avail => 1 };
my (@queries, @structures, @files, @backups);
my $saved_csv = '';

# Keep real HTML rendering, including subtitle, footer and form helpers.
*main::ReadParse = *main::ReadParseMime = sub { };
*main::error = sub { die join(' ', @_)."\n" };
*main::error_setup = sub { };
*main::ui_print_header = sub { print main::ui_post_header($_[0]) };
*main::ui_print_footer = sub {
	while (@_) {
		my ($url, $label) = splice(@_, 0, 2);
		print main::ui_link($url, $label);
		}
	};
*main::get_module_variable = sub { return \%main::text };
*main::get_webprefix = sub { '' };
*main::file_chooser_button = *main::help_search_link = sub { '' };
*main::foreign_check = *main::foreign_installed = *main::foreign_available = sub { 0 };
*main::webmin_log = *main::additional_log = sub { };

# Supply schemas and read-only results; never execute SQL or shell commands.
*main::supports_quoting = *main::supports_views = sub { 1 };
*main::list_databases = *main::list_tables = sub { ($name) };
*main::list_indexes = *main::list_views = sub { ($name) };
*main::table_structure = sub {
	push(@structures, [ @_ ]);
	return { field => $name, type => $case->{'blob'} ? 'blob' : 'varchar(40)',
		 key => 'PRI', null => 'YES', default => 'fixture value' };
	};
*main::index_structure = *main::parse_index_structure = sub {
	return { table => $name, name => $name, cols => [ $name ], type => 'unique' };
	};
*main::view_structure = sub { return { name => $name, query => 'SELECT 1' } };
*main::execute_sql = *main::execute_sql_safe = sub {
	my ($db, $sql) = @_;
	push(@queries, [ $db, $sql ]);
	die "Unexpected SQL: $sql" if $sql !~ /^(select|show)\b/i;
	return { data => [ [ $case->{'total'} // 5 ] ] } if $sql =~ /^select count/;
	return { data => [ [ $name, 'CREATE TABLE fixture () ENGINE=InnoDB' ] ] }
		if $sql =~ /^show create/;
	return { data => [ [ 1, $name, $name, $name, 'Query', 1, '', $name ] ] }
		if $sql =~ /processlist/;
	return { data => [ [ $name, $name, $name, $name, $name, '', 'Select' ] ] }
		if $sql =~ /(?:columns|tables)_priv/;
	return { titles => [ $name ], data => [ [ 'fixture value' ] ] };
	};
*main::execute_sql_logged = \&main::execute_sql;
*main::get_all_tables_size = sub { return { data => [ [ '', $name, '', 1024 ] ] } };
*main::get_table_index_stats = sub { [] };
*main::get_character_set = sub { 'utf8mb4' };
*main::list_character_sets = sub { ('utf8mb4') };
*main::list_compatible_formats = sub { ('ANSI') };
*main::list_compatible_options = sub { (['no_data']) };
*main::can_run_backup_commands = sub { 0 };
*main::has_command = *main::working_env_pass = *main::is_mysql_running = sub { 1 };
*main::is_mysql_local = *main::supports_variables = *main::supports_hosts = sub { 0 };
*main::get_mysql_version = sub { '8.0' };
*main::get_remote_mysql_version = sub { '8.0' };
*main::mysql_login_type = sub { $case->{'socket'} ? 'socket' : 'password' };
*main::get_remote_mysql_variant = sub { ('8.0', 'mysql') };
*main::save_mysql_version = *main::create_module_info_overrides = sub { };

# Redirect all file writes into memory or a private temporary fixture.
*main::open_tempfile = sub {
	no strict 'refs';
	push(@files, $_[1]);
	open($_[0], '>', \$saved_csv) or die $!;
	};
*main::close_tempfile = sub { no strict 'refs'; close($_[0]) or die $! };
*main::transname = sub { "$tmp/input.sql" };
*main::copy_file_under_global_acl = sub {
	push(@files, $_[0]);
	open(my $out, '>', "$tmp/input.sql") or die $!;
	print $out "SELECT 1;\n";
	close($out);
	return 1;
	};
*main::copy_source_dest = *main::set_mysql_command_file_permissions = sub { 1 };
*main::mysql_command_unix_user = sub { 'root' };
*main::compression_format = sub { 0 };
*main::execute_sql_file = sub { push(@queries, [ @_ ]); return (0, 'Fixture SQL output') };
*main::open_execute_command = sub {
	no strict 'refs';
	my $output = 'Fixture import output';
	open($_[0], '<', \$output) or die $!;
	};
*main::open_readfile = sub {
	no strict 'refs';
	my $history = "SELECT 1\n";
	open($_[0], '<', \$history) or die $!;
	};
*main::backup_database = sub { push(@backups, [ @_ ]); return };
*main::date_subs = sub { $_[0] };
*main::unlink_file = sub { };
*main::is_under_directory = sub { $_[1] =~ /^\Q$tmp\E\// };

my ($html, $error) = ('', '');
open(my $out, '>', \$html) or die $!;
{
	local *STDOUT = $out;
	do "$root/$module/$page.cgi";
	$error = $@;
	}
close($out);
print encode_json({ html => $html, error => $error, input => \%main::in,
	queries => \@queries, structures => \@structures, files => \@files,
	backups => \@backups, csv => $saved_csv });
